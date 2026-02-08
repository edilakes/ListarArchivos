# Crawler de Archivos para app.itheca.org
# Estrategia: Híbrida (Directory Crawling + Content Discovery)
# NOTA: El listado de archivos actual contiene enlaces rotos que hay que verificar.

# Configuración
$baseUrl = "https://app.itheca.org/biblioteca/Biblia/00SE.html"
$domain = "app.itheca.org"
$outputFile = Join-Path $PSScriptRoot "full_discovered_files.txt"

# Asegurar protocolo TLS 1.2 para compatibilidad con servidores modernos
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Inicialización de colecciones
$dirQueue = New-Object System.Collections.Generic.Queue[String]
$fileQueue = New-Object System.Collections.Generic.Queue[String]

$visitedDirs = New-Object System.Collections.Generic.HashSet[String]
$visitedFiles = New-Object System.Collections.Generic.HashSet[String]

$discoveredFiles = New-Object System.Collections.Generic.HashSet[String]

# Sesión web para mantener cookies y estado entre peticiones
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

# Función auxiliar para normalizar URLs
function Get-AbsoluteUrl {
    param ($Base, $Relative)
    try {
        if ([string]::IsNullOrWhiteSpace($Relative)) { return $null }
        $baseUri = New-Object System.Uri($Base)
        $absUri = New-Object System.Uri($baseUri, $Relative)
        # Solo permitir HTTP/HTTPS
        if ($absUri.Scheme -notin @('http', 'https')) { return $null }
        return $absUri.AbsoluteUri.Split('#')[0] # Eliminar fragmentos
    } catch {
        return $null
    }
}

# Función para obtener el directorio padre (Scope de escaneo)
function Get-ParentDirectory {
    param ($Url)
    try {
        if ([string]::IsNullOrWhiteSpace($Url)) { return $null }
        # Si termina en /, asumimos que es un directorio
        if ($Url.EndsWith("/")) { return $Url }
        # Si no, cortamos hasta la última barra para obtener el contenedor
        $lastSlash = $Url.LastIndexOf('/')
        if ($lastSlash -gt 8) { # Evitar cortar el protocolo http://
            return $Url.Substring(0, $lastSlash + 1)
        }
        return $Url + "/"
    } catch { return $null }
}

# Configuración Inicial
$startDir = Get-ParentDirectory -Url $baseUrl
$dirQueue.Enqueue($startDir)
$visitedDirs.Add($startDir) | Out-Null

Write-Host "Iniciando Crawler por Directorios en: $startDir" -ForegroundColor Cyan

# Bucle Principal
while ($dirQueue.Count -gt 0 -or $fileQueue.Count -gt 0) {
    # Prioridad a Directorios para descubrimiento masivo
    if ($dirQueue.Count -gt 0) {
        $currentUrl = $dirQueue.Dequeue()
        $isDirScan = $true
        Write-Host "Escaneando Directorio [Dirs:$($dirQueue.Count) | Files:$($fileQueue.Count)]: $currentUrl" -ForegroundColor Cyan
    } else {
        $currentUrl = $fileQueue.Dequeue()
        $isDirScan = $false
        Write-Host "Analizando Archivo   [Dirs:$($dirQueue.Count) | Files:$($fileQueue.Count)]: $currentUrl" -ForegroundColor Gray
    }

    try {
        # Descargar contenido
        # Usamos -UseBasicParsing para compatibilidad con PowerShell Core y sistemas sin IE configurado
        # Añadimos WebSession y Headers para simular mejor un navegador real
        $response = Invoke-WebRequest -Uri $currentUrl -UseBasicParsing -Method Get -ErrorAction Stop `
            -WebSession $session `
            -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" `
            -Headers @{ "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" }
        
        # Usar la URL efectiva (post-redirección) para resolver enlaces relativos correctamente
        $effectiveUrl = $response.BaseResponse.ResponseUri.AbsoluteUri

        # Verificar si es contenido HTML (para parsear)
        $contentType = $response.Headers["Content-Type"]
        # Relajamos la verificación de Content-Type para intentar parsear si parece HTML
        if ($null -eq $contentType -or $contentType -match "text/html" -or $contentType -match "application/xhtml") {
            
            # 1. Procesar Enlaces (<a href>)
            # Combinar .Links y Regex para mayor robustez
            $linksFound = @()
            
            # Regex unificado para href y src
            $regex = [regex]::Matches($response.Content, '(?:href|src)\s*=\s*(["'']?)([^"''\s>]+)\1', 'IgnoreCase')
            foreach ($m in $regex) { $linksFound += $m.Groups[2].Value }

            # Write-Host "   -> Referencias encontradas: $($linksFound.Count)" -ForegroundColor DarkGray

            foreach ($link in $linksFound | Select-Object -Unique) {
                $absUrl = Get-AbsoluteUrl -Base $effectiveUrl -Relative $link
                
                if ($absUrl -and $absUrl.Contains($domain)) {
                    
                    # 1. Registrar TODO lo encontrado como archivo/recurso
                    if (-not $discoveredFiles.Contains($absUrl)) {
                        $discoveredFiles.Add($absUrl) | Out-Null
                    }

                    # 2. Inferencia de Directorios
                    
                    # Caso A: Es explícitamente un directorio
                    if ($absUrl.EndsWith("/")) {
                        if (-not $visitedDirs.Contains($absUrl)) {
                            $visitedDirs.Add($absUrl) | Out-Null
                            $dirQueue.Enqueue($absUrl)
                        }
                    }
                    # Caso B: No tiene extensión (posible directorio sin slash o archivo sin extensión)
                    elseif ($absUrl -notmatch "\.[a-zA-Z0-9]{2,5}$") {
                        if (-not $visitedDirs.Contains($absUrl)) {
                            $visitedDirs.Add($absUrl) | Out-Null
                            $dirQueue.Enqueue($absUrl)
                        }
                    }
                    # Caso C: Tiene extensión (Archivo)
                    else {
                        # C.1: Si es HTML, lo encolamos para análisis profundo (buscar ramas)
                        if ($absUrl -match "\.html?$") {
                            if (-not $visitedFiles.Contains($absUrl)) {
                                $visitedFiles.Add($absUrl) | Out-Null
                                $fileQueue.Enqueue($absUrl)
                            }
                        }

                        # C.2: Inferencia de rama padre (Bridge)
                        $parentDir = Get-ParentDirectory -Url $absUrl
                        if ($parentDir -and $parentDir.Contains($domain) -and -not $visitedDirs.Contains($parentDir)) {
                            $visitedDirs.Add($parentDir) | Out-Null
                            $dirQueue.Enqueue($parentDir)
                            Write-Host "   + Nueva rama descubierta: $parentDir" -ForegroundColor Green
                        }
                    }
                }
            }
        }
    } catch {
        Write-Warning "Error accediendo a $currentUrl : $_"
    }
}

# Generar Reporte
Write-Host "Guardando resultados en $outputFile..." -ForegroundColor Cyan
$discoveredFiles | Sort-Object | Out-File -FilePath $outputFile -Encoding UTF8
Write-Host "Completado. Total archivos descubiertos: $($discoveredFiles.Count)" -ForegroundColor Green
