<#
.SYNOPSIS
    Fase 3 - Tarea 1: Descargador Dual Recursivo (Pipeline de Ingesta).
    Intenta descargar contenido de app.itheca.org y usa fallback local si falla.

.DESCRIPTION
    1. Lee URLs de 'valid_links.txt'.
    2. Realiza Invoke-WebRequest (Paso Primario).
    3. Si falla, busca el archivo localmente (Paso Fallback).
    4. Guarda en la carpeta .\Descargas\ manteniendo la estructura.
    5. Incluye un retardo (Sleep) de 500ms entre peticiones.
#>

# Configuración
$validLinksFile = Join-Path $PSScriptRoot "valid_links.txt"
$baseDownloadDir = Join-Path $PSScriptRoot "Descargas"
$logFile = Join-Path $PSScriptRoot "ingesta_dual.log"
$sleepMs = 500 # Retardo para evitar bloqueos
$domain = "https://app.itheca.org"

# Asegurar TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not (Test-Path $validLinksFile)) {
    Write-Error "No se encontró $validLinksFile"
    exit 1
}

if (-not (Test-Path $baseDownloadDir)) {
    New-Item -ItemType Directory -Path $baseDownloadDir | Out-Null
}

$urls = Get-Content $validLinksFile -Encoding UTF8
$total = $urls.Count
$count = 0

Write-Host "Iniciando ingesta dual de $total URLs..." -ForegroundColor Cyan
"--- Inicio de Ingesta: $(Get-Date) ---" | Out-File $logFile -Append

foreach ($url in $urls) {
    $count++
    $uri = [System.Uri]$url
    $relativePath = $uri.AbsolutePath.TrimStart('/')
    
    # Si la ruta termina en / o está vacía, asumimos index.html
    if ($relativePath -eq "" -or $relativePath.EndsWith("/")) {
        $relativePath += "index.html"
    }
    elseif (-not ($relativePath -match "\.[a-zA-Z0-9]+$")) {
        $relativePath += ".html"
    }

    $targetFile = Join-Path $baseDownloadDir $relativePath
    $targetDir = Split-Path $targetFile -Parent

    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    $status = "UNKNOWN"
    $success = $false

    try {
        # Intento 1: Web
        Write-Host "[$count/$total] Descargando: $url" -ForegroundColor Gray
        
        # Usamos -OutFile para descargar los BYTES crudos sin que PowerShell asuma ISO-8859-1.
        # Esto evitará problemas con caracteres UTF-8.
        $response = Invoke-WebRequest -Uri $url -TimeoutSec 10 -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Antigravity-Itheca-Bot" -OutFile $targetFile -PassThru
        
        $status = "WEB_SUCCESS"
        $success = $true
    }

    catch {
        $webError = $_.Exception.Message
        # Intento 2: Fallback Local (Aquí asumimos que el usuario podría tener archivos en una carpeta previa o si simplemente queremos loguear el fallo)
        # En una arquitectura real, si tuviéramos un backup, lo copiaríamos aquí. 
        # Por ahora, registramos el fallo y si existe un archivo previo en el workspace, lo marcamos.
        
        $status = "WEB_FAIL ($webError)"
        Write-Host "  >> ERROR Web. Fallback..." -ForegroundColor Yellow
        
        # Lógica de fallback específica: Si ya existía el archivo por un crawling previo manual
        if (Test-Path $targetFile) {
            $status += " - LOCAL_EXISTS (Usando copia previa)"
            $success = $true
        }
        else {
            $status += " - NOT_FOUND"
        }
    }

    # Log y Consola
    $logMsg = "[$(Get-Date -Format 'HH:mm:ss')] [$status] $url"
    $logMsg | Out-File $logFile -Append
    
    if ($success) {
        Write-Host "  [OK] Guardado en: $relativePath" -ForegroundColor Green
    }
    else {
        Write-Host "  [KO] Falló descarga y no hay copia local." -ForegroundColor Red
    }

    # Retardo solicitado
    Start-Sleep -Milliseconds $sleepMs
}

Write-Host "Proceso terminado. Log en: $logFile" -ForegroundColor Cyan
