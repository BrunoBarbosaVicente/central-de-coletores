# Servidor_Central.ps1
$porta = 5454
$pasta = Split-Path -Parent $MyInvocation.MyCommand.Path
$url = "http://localhost:$porta"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Central de Coletores - Servidor Local" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Pasta: $pasta"
Write-Host "URL: $url"
Write-Host ""

# Abre o navegador automaticamente
Start-Process $url

# Cria o servidor HTTP
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$porta/")
$listener.Start()
Write-Host "Servidor rodando em $url" -ForegroundColor Green
Write-Host "Pressione Ctrl+C para parar." -ForegroundColor Red

# Função para localizar o MC3300x e copiar sem travar a requisição
function Copiar-ParaZebraMTP($origemPasta) {
    $shell = New-Object -ComObject Shell.Application
    # 17 = ssfDRIVES (Este Computador)
    $esteComputador = $shell.Namespace(17)

    $pastaDownloadMTP = $null
    $nomeColetor = ""

    foreach ($item in $esteComputador.Items()) {
        if ($item.Name -match "MC3300|Zebra" -or ($null -ne $item.GetFolder -and $item.Type -match "Portátil|Portable|Dispositivo")) {
            $dispFolder = $item.GetFolder
            if ($null -ne $dispFolder) {
                foreach ($particao in $dispFolder.Items()) {
                    if ($particao.Name -match "Divis[aã]o interna|Armazenamento|Internal") {
                        $particaoFolder = $particao.GetFolder
                        if ($null -ne $particaoFolder) {
                            foreach ($pastaInterna in $particaoFolder.Items()) {
                                if ($pastaInterna.Name -eq "Download") {
                                    $pastaDownloadMTP = $pastaInterna.GetFolder
                                    $nomeColetor = $item.Name
                                    break
                                }
                            }
                        }
                    }
                    if ($null -ne $pastaDownloadMTP) { break }
                }
            }
        }
        if ($null -ne $pastaDownloadMTP) { break }
    }

    if ($null -eq $pastaDownloadMTP) {
        throw "Nao foi possivel encontrar a pasta Download no MC3300x. Verifique se a tela esta desbloqueada e em modo Transferencia de Arquivo."
    }

    $origemShell = $shell.Namespace($origemPasta)
    $itensOrigem = $origemShell.Items()

    if ($itensOrigem.Count -eq 0) {
        throw "A pasta arquivos_carga esta vazia."
    }

    # Copia todos os itens de uma vez (16 = Sim para todos, sem caixas de diálogo)
    $pastaDownloadMTP.CopyHere($itensOrigem, 16)

    # Pausa curta para iniciar a cópia via Shell
    Start-Sleep -Seconds 2

    return "$($itensOrigem.Count) arquivo(s) enviados para o MC3300x com sucesso!"
}

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    # Configuração de CORS e Cabeçalhos
    $response.AddHeader("Access-Control-Allow-Origin", "*")
    $response.AddHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    $response.AddHeader("Access-Control-Allow-Headers", "Content-Type")

    if ($request.HttpMethod -eq "OPTIONS") {
        $response.StatusCode = 200
        $response.OutputStream.Close()
        continue
    }

    $caminho = $request.Url.LocalPath.TrimStart('/')

    # Rota para ENVIAR ARQUIVOS VIA MTP (Zebra MC3300x)
    if ($request.HttpMethod -eq "POST" -and $caminho -eq "api/enviar-usb") {
        try {
            $origemArquivos = Join-Path $pasta "arquivos_carga"

            if (-not (Test-Path $origemArquivos)) {
                New-Item -ItemType Directory -Path $origemArquivos | Out-Null
            }

            $mensagemSucesso = Copiar-ParaZebraMTP -origemPasta $origemArquivos

            $response.StatusCode = 200
            $response.ContentType = "application/json; charset=utf-8"
            $msgBytes = [System.Text.Encoding]::UTF8.GetBytes('{"status":"ok","mensagem":"' + $mensagemSucesso + '"}')
            $response.ContentLength64 = $msgBytes.Length
            $response.OutputStream.Write($msgBytes, 0, $msgBytes.Length)
        } catch {
            $response.StatusCode = 500
            $erroLimpo = $_.Exception.Message.Replace('"', "'").Replace("`r`n", " ").Replace("`n", " ")
            $erroBytes = [System.Text.Encoding]::UTF8.GetBytes('{"status":"erro","erro":"' + $erroLimpo + '"}')
            $response.ContentLength64 = $erroBytes.Length
            $response.OutputStream.Write($erroBytes, 0, $erroBytes.Length)
        }
        $response.OutputStream.Close()
        continue
    }

    # Rota para CRIAR ATALHO NA ÁREA DE TRABALHO
    if ($request.HttpMethod -eq "POST" -and $caminho -eq "api/criar-atalho") {
        try {
            $desktopPath = [Environment]::GetFolderPath("Desktop")
            $atalhoPath = Join-Path $desktopPath "Central de Coletores.lnk"
            $alvoBat = Join-Path $pasta "iniciar_central.bat"
            $iconePath = Join-Path $pasta "icone.ico"

            $wshShell = New-Object -ComObject WScript.Shell
            $shortcut = $wshShell.CreateShortcut($atalhoPath)
            $shortcut.TargetPath = $alvoBat
            $shortcut.WorkingDirectory = $pasta
            $shortcut.Description = "Iniciar Central de Coletores"

            if (Test-Path $iconePath -PathType Leaf) {
                $shortcut.IconLocation = "$iconePath,0"
            }

            $shortcut.Save()

            $response.StatusCode = 200
            $response.ContentType = "application/json; charset=utf-8"
            $msgBytes = [System.Text.Encoding]::UTF8.GetBytes('{"status":"ok"}')
            $response.ContentLength64 = $msgBytes.Length
            $response.OutputStream.Write($msgBytes, 0, $msgBytes.Length)
        } catch {
            $response.StatusCode = 500
            $erroBytes = [System.Text.Encoding]::UTF8.GetBytes('{"erro":"' + $_.Exception.Message + '"}')
            $response.ContentLength64 = $erroBytes.Length
            $response.OutputStream.Write($erroBytes, 0, $erroBytes.Length)
        }
        $response.OutputStream.Close()
        continue
    }

    # Rota para SALVAR COLETORES VIA POST
    if ($request.HttpMethod -eq "POST" -and ($caminho -eq "coletores.json" -or $caminho -eq "api/salvar")) {
        try {
            $reader = New-Object System.IO.StreamReader($request.InputStream, [System.Text.Encoding]::UTF8)
            $corpo = $reader.ReadToEnd()
            $reader.Close()

            $arquivoDestino = Join-Path $pasta "coletores.json"
            [System.IO.File]::WriteAllText($arquivoDestino, $corpo, [System.Text.Encoding]::UTF8)

            $response.StatusCode = 200
            $response.ContentType = "application/json; charset=utf-8"
            $msgBytes = [System.Text.Encoding]::UTF8.GetBytes('{"status":"ok"}')
            $response.ContentLength64 = $msgBytes.Length
            $response.OutputStream.Write($msgBytes, 0, $msgBytes.Length)
        } catch {
            $response.StatusCode = 500
            $erroBytes = [System.Text.Encoding]::UTF8.GetBytes('{"erro":"' + $_.Exception.Message + '"}')
            $response.ContentLength64 = $erroBytes.Length
            $response.OutputStream.Write($erroBytes, 0, $erroBytes.Length)
        }
        $response.OutputStream.Close()
        continue
    }

    # Entrega de arquivos estáticos (GET)
    if ([string]::IsNullOrEmpty($caminho)) { $caminho = "index.html" }
    $arquivo = Join-Path $pasta $caminho

    if (Test-Path $arquivo -PathType Leaf) {
        $ext = [System.IO.Path]::GetExtension($arquivo).ToLower()
        switch ($ext) {
            ".html" { $response.ContentType = "text/html; charset=utf-8" }
            ".json" { $response.ContentType = "application/json; charset=utf-8" }
            ".js"   { $response.ContentType = "application/javascript" }
            ".css"  { $response.ContentType = "text/css" }
            ".ico"  { $response.ContentType = "image/x-icon" }
            ".png"  { $response.ContentType = "image/png" }
            default { $response.ContentType = "application/octet-stream" }
        }

        $response.AddHeader("Cache-Control", "no-cache, no-store, must-revalidate")
        $conteudo = [System.IO.File]::ReadAllBytes($arquivo)
        $response.ContentLength64 = $conteudo.Length
        $response.OutputStream.Write($conteudo, 0, $conteudo.Length)
    } else {
        $response.StatusCode = 404
        $mensagem = [System.Text.Encoding]::UTF8.GetBytes("Arquivo nao encontrado")
        $response.ContentLength64 = $mensagem.Length
        $response.OutputStream.Write($mensagem, 0, $mensagem.Length)
    }
    $response.OutputStream.Close()
}