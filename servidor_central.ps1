# ==============================================================================
# Servidor Central de Coletores - Toyota / Field Services
# ==============================================================================

$porta = 5454

# Identifica o caminho do diretorio
$pastaRaiz = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($pastaRaiz)) {
    $pastaRaiz = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
if ([string]::IsNullOrWhiteSpace($pastaRaiz)) {
    $pastaRaiz = (Get-Location).Path
}

Set-Location $pastaRaiz

$pastaCarga = Join-Path $pastaRaiz "arquivos_carga"
if (-not (Test-Path $pastaCarga)) {
    New-Item -ItemType Directory -Path $pastaCarga -Force | Out-Null
}

# Inicializa o Listener HTTP
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$porta/")
$listener.Prefixes.Add("http://127.0.0.1:$porta/")

try {
    $listener.Start()
} catch {
    Clear-Host
    Write-Host ""
    Write-Host "  [ERRO] A porta $porta esta ocupada ou bloqueada por outra instancia." -ForegroundColor Red
    Write-Host "  Feche outras janelas de terminal abertas e tente novamente." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "  Pressione Enter para fechar..."
    exit
}

# ------------------------------------------------------------------------------
# APRESENTACAO VISUAL
# ------------------------------------------------------------------------------
Clear-Host

Write-Host ""
Write-Host "  +-----------------------------------------------------------------------------+" -ForegroundColor DarkCyan
Write-Host "  |                        CENTRAL DE COLETORES ZEBRA                           |" -ForegroundColor Cyan
Write-Host "  |       Configuracao de Rede  -  Perfis StageNow  -  Carga USB (MTP)          |" -ForegroundColor DarkGray
Write-Host "  +-----------------------------------------------------------------------------+" -ForegroundColor DarkCyan

Write-Host ""
Write-Host "  [*] [STATUS] Servidor local ativo e operando com sucesso." -ForegroundColor Green

Write-Host ""
Write-Host "  [!] [AVISO]  Mantenha esta janela aberta ou minimizada durante o uso." -ForegroundColor Yellow

Write-Host ""
Write-Host "  -------------------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""

# Abre o navegador
Start-Process "http://localhost:$porta/"

# Leitura protegida contra bloqueio de nuvem do OneDrive
function Ler-BytesArquivo($caminho) {
    try {
        return [System.IO.File]::ReadAllBytes($caminho)
    } catch {
        $fs = New-Object System.IO.FileStream($caminho, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $buffer = New-Object byte[] $fs.Length
        $fs.Read($buffer, 0, $fs.Length) | Out-Null
        $fs.Close()
        $fs.Dispose()
        return $buffer
    }
}

function Enviar-Resposta($context, [byte[]]$bytes, $contentType, $statusCode = 200) {
    try {
        $context.Response.StatusCode = $statusCode
        $context.Response.ContentType = $contentType
        $context.Response.ContentLength64 = $bytes.Length
        $context.Response.AddHeader("Access-Control-Allow-Origin", "*")
        $context.Response.AddHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        $context.Response.AddHeader("Access-Control-Allow-Headers", "Content-Type")
        $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
        $context.Response.OutputStream.Flush()
    } catch {
    } finally {
        $context.Response.Close()
    }
}

function Obter-MimeType($extensao) {
    switch ($extensao.ToLower()) {
        ".html" { return "text/html; charset=utf-8" }
        ".htm"  { return "text/html; charset=utf-8" }
        ".css"  { return "text/css; charset=utf-8" }
        ".js"   { return "application/javascript; charset=utf-8" }
        ".json" { return "application/json; charset=utf-8" }
        ".png"  { return "image/png" }
        ".jpg"  { return "image/jpeg" }
        ".jpeg" { return "image/jpeg" }
        ".ico"  { return "image/x-icon" }
        ".svg"  { return "image/svg+xml" }
        default { return "application/octet-stream" }
    }
}

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
    } catch {
        break
    }

    $request = $context.Request
    $urlPath = $request.Url.AbsolutePath

    if ($request.HttpMethod -eq "OPTIONS") {
        $context.Response.StatusCode = 200
        $context.Response.AddHeader("Access-Control-Allow-Origin", "*")
        $context.Response.AddHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        $context.Response.AddHeader("Access-Control-Allow-Headers", "Content-Type")
        $context.Response.Close()
        continue
    }

    # 1. PÁGINA PRINCIPAL
    if ($urlPath -eq "/" -or $urlPath -eq "/index.html") {
        $caminhoIndex = Join-Path $pastaRaiz "index.html"
        if (Test-Path $caminhoIndex) {
            $bytes = Ler-BytesArquivo $caminhoIndex
            Enviar-Resposta $context $bytes "text/html; charset=utf-8"
        } else {
            $msg = [System.Text.Encoding]::UTF8.GetBytes("<h2 style='font-family:sans-serif;color:#b71c1c;padding:30px;'>Erro: index.html nao encontrado.</h2>")
            Enviar-Resposta $context $msg "text/html; charset=utf-8" 404
        }
        continue
    }

    # 2. LISTAR ARQUIVOS USB
    if ($urlPath -eq "/api/listar-arquivos-usb") {
        try {
            $arquivos = Get-ChildItem -Path $pastaCarga -File | Select-Object -ExpandProperty Name
            $arr = @($arquivos)
            $json = @{ status = "ok"; arquivos = $arr } | ConvertTo-Json -Compress
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
            Enviar-Resposta $context $bytes "application/json; charset=utf-8"
        } catch {
            $json = @{ status = "erro"; mensagem = $_.Exception.Message } | ConvertTo-Json -Compress
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
            Enviar-Resposta $context $bytes "application/json; charset=utf-8" 500
        }
        continue
    }

    # 3. ENVIAR USB (CAMINHO EXATO: MC3300x\Divisão interna de armazenamento\Download)
    if ($urlPath -eq "/api/enviar-usb" -and $request.HttpMethod -eq "POST") {
        try {
            Write-Host "  -> [USB] Iniciando verificacao MTP para MC3300x..." -ForegroundColor Cyan

            # Obtém a lista de arquivos da pasta 'arquivos_carga'
            $arquivosParaEnviar = @()
            try {
                if ($request.HasEntityBody) {
                    $reader = New-Object System.IO.StreamReader($request.InputStream, [System.Text.Encoding]::UTF8)
                    $body = $reader.ReadToEnd()
                    if (-not [string]::IsNullOrWhiteSpace($body)) {
                        $payload = $body | ConvertFrom-Json
                        if ($payload.arquivos) {
                            $arquivosParaEnviar = @($payload.arquivos)
                        }
                    }
                }
            } catch {}

            if ($arquivosParaEnviar.Count -eq 0) {
                $todos = Get-ChildItem -Path $pastaCarga -File | Select-Object -ExpandProperty Name
                $arquivosParaEnviar = @($todos)
            }

            if ($arquivosParaEnviar.Count -eq 0) {
                throw "A pasta 'arquivos_carga' esta vazia. Adicione os arquivos que deseja copiar."
            }

            $shell = New-Object -ComObject Shell.Application
            $meuComputador = $shell.Namespace(17) # 17 = Este Computador

            # 1. Localiza o dispositivo MC3300x
            $coletor = $null
            foreach ($item in $meuComputador.Items()) {
                if ($item.Name -match "MC3300x|MC33|Zebra") {
                    $coletor = $item
                    break
                }
            }

            if (-not $coletor) {
                throw "Dispositivo 'MC3300x' nao encontrado em 'Este Computador'. Verifique se o cabo esta conectado, a tela DESBLOQUEADA e o modo USB configurado como 'Transferencia de arquivos'."
            }

            Write-Host "  -> [USB] Dispositivo encontrado: $($coletor.Name)" -ForegroundColor Green

            # 2. Localiza a pasta 'Divisão interna de armazenamento'
            $coletorFolder = $coletor.GetFolder
            $armazenamento = $null
            foreach ($sub in $coletorFolder.Items()) {
                # Busca exata por 'Divisão interna de armazenamento' ou variações com/sem acento
                if ($sub.Name -match "Divis|Armazenamento|Internal|compartilhado") {
                    $armazenamento = $sub
                    break
                }
            }

            if (-not $armazenamento) {
                # Se não achou por regex, lista na tela o nome real para diagnóstico
                $nomesEncontrados = ($coletorFolder.Items() | ForEach-Object { $_.Name }) -join ", "
                throw "Pasta 'Divisao interna de armazenamento' nao acessivel. Pastas visiveis no aparelho: [$nomesEncontrados]. Verifique se a tela esta desbloqueada."
            }

            Write-Host "  -> [USB] Armazenamento acessado: $($armazenamento.Name)" -ForegroundColor Green

            # 3. Localiza a pasta 'Download'
            $armazenamentoFolder = $armazenamento.GetFolder
            $downloadFolder = $null
            foreach ($sub in $armazenamentoFolder.Items()) {
                if ($sub.Name -match "^Download$") {
                    $downloadFolder = $sub.GetFolder
                    break
                }
            }

            if (-not $downloadFolder) {
                throw "Pasta 'Download' nao encontrada dentro de '$($armazenamento.Name)'."
            }

            Write-Host "  -> [USB] Destino confirmado: $($coletor.Name)\$($armazenamento.Name)\$($downloadFolder.Title)" -ForegroundColor Green

            # 4. Transfere os arquivos com confirmação
            $qtdCopiada = 0
            foreach ($nomeArq in $arquivosParaEnviar) {
                $caminhoCompleto = Join-Path $pastaCarga $nomeArq
                if (Test-Path $caminhoCompleto) {
                    Write-Host "  -> [USB] Transferindo: $nomeArq ..." -ForegroundColor Yellow
                    
                    # 16 = FOF_SILENT (sem popup de confirmacao do explorer)
                    $downloadFolder.CopyHere($caminhoCompleto, 16)
                    
                    # Pausa curta para permitir que o buffer MTP grave o arquivo no Android
                    Start-Sleep -Milliseconds 600
                    $qtdCopiada++
                }
            }

            Write-Host "  -> [USB] Carga concluida com sucesso! Total: $qtdCopiada arquivo(s)" -ForegroundColor Green

            $respostaJson = @{ status = "ok"; mensagem = "$qtdCopiada arquivo(s) copiado(s) para 'Download' com sucesso!" } | ConvertTo-Json -Compress
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($respostaJson)
            Enviar-Resposta $context $bytes "application/json; charset=utf-8"
        } catch {
            Write-Host "  -> [USB ERRO] $($_.Exception.Message)" -ForegroundColor Red
            $erroMsg = $_.Exception.Message.Replace('"', '\"')
            $respostaJson = '{"status":"erro","mensagem":"' + $erroMsg + '"}'
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($respostaJson)
            Enviar-Resposta $context $bytes "application/json; charset=utf-8" 500
        }
        continue
    }

    # 4. CRIAR ATALHO
    if ($urlPath -eq "/api/criar-atalho" -and $request.HttpMethod -eq "POST") {
        try {
            $desktop = [System.Environment]::GetFolderPath("Desktop")
            $atalhoPath = Join-Path $desktop "Central de Coletores.url"
            $conteudo = "[InternetShortcut]`r`nURL=http://localhost:$porta/`r`nIconIndex=0`r`nIconFile=" + (Join-Path $pastaRaiz "icone.ico")
            [System.IO.File]::WriteAllText($atalhoPath, $conteudo, [System.Text.Encoding]::UTF8)

            $json = '{"status":"ok","mensagem":"Atalho criado na Area de Trabalho!"}'
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
            Enviar-Resposta $context $bytes "application/json; charset=utf-8"
        } catch {
            $json = '{"status":"erro","mensagem":"' + $_.Exception.Message + '"}'
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
            Enviar-Resposta $context $bytes "application/json; charset=utf-8" 500
        }
        continue
    }

    # 5. SALVAR COLETORES.JSON
    if ($urlPath -eq "/coletores.json" -and $request.HttpMethod -eq "POST") {
        try {
            $caminhoArquivo = Join-Path $pastaRaiz "coletores.json"
            $reader = New-Object System.IO.StreamReader($request.InputStream, [System.Text.Encoding]::UTF8)
            $conteudoJson = $reader.ReadToEnd()
            [System.IO.File]::WriteAllText($caminhoArquivo, $conteudoJson, [System.Text.Encoding]::UTF8)

            $json = '{"status":"ok"}'
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
            Enviar-Resposta $context $bytes "application/json; charset=utf-8"
        } catch {
            $json = '{"status":"erro","mensagem":"' + $_.Exception.Message + '"}'
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
            Enviar-Resposta $context $bytes "application/json; charset=utf-8" 500
        }
        continue
    }

    # 6. ARQUIVOS ESTÁTICOS
    $nomeArquivo = $urlPath.TrimStart('/')
    $caminhoArquivoFisico = Join-Path $pastaRaiz $nomeArquivo

    if (Test-Path $caminhoArquivoFisico -PathType Leaf) {
        try {
            $ext = [System.IO.Path]::GetExtension($caminhoArquivoFisico)
            $bytes = Ler-BytesArquivo $caminhoArquivoFisico
            Enviar-Resposta $context $bytes (Obter-MimeType $ext)
        } catch {
            $context.Response.StatusCode = 500
            $context.Response.Close()
        }
    } else {
        $msg = [System.Text.Encoding]::UTF8.GetBytes("Arquivo nao encontrado: $nomeArquivo")
        Enviar-Resposta $context $msg "text/plain; charset=utf-8" 404
    }
}