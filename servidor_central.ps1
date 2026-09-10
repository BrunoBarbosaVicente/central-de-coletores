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

while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    # CORS
    $response.AddHeader("Access-Control-Allow-Origin", "*")
    $response.AddHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
    $response.AddHeader("Access-Control-Allow-Headers", "Content-Type")

    if ($request.HttpMethod -eq "OPTIONS") {
        $response.StatusCode = 200
        $response.OutputStream.Close()
        continue
    }

    $caminho = $request.Url.LocalPath.TrimStart('/')

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

            # Se encontrar o arquivo icone.ico na pasta, aplica ao atalho
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

    # Leitura de arquivos estáticos (GET)
    if ([string]::IsNullOrEmpty($caminho)) { $caminho = "index.html" }
    $arquivo = Join-Path $pasta $caminho

    if (Test-Path $arquivo -PathType Leaf) {
        $ext = [System.IO.Path]::GetExtension($arquivo).ToLower()
        switch ($ext) {
            ".html" { $response.ContentType = "text/html; charset=utf-8" }
            ".json" { $response.ContentType = "application/json; charset=utf-8" }
            ".js"   { $response.ContentType = "application/javascript" }
            ".css"  { $response.ContentType = "text/css" }
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