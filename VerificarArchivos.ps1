<#
.SYNOPSIS
    Verifica el estado HTTP de todas las URLs en un fichero de entrada y genera
    un árbol visual de archivos accesibles y un informe de enlaces rotos.

.DESCRIPTION
    Lee 'full_discovered_files.txt', hace una petición HEAD a cada URL en paralelo,
    clasifica los resultados y crea:
      - verified_tree.txt : Árbol visual de URLs accesibles (HTTP 2xx).
      - broken_links.txt  : Lista de URLs con error y su código HTTP.
#>

# =============================================================================
# CONFIGURACIÓN
# =============================================================================
$inputFile       = Join-Path $PSScriptRoot "full_discovered_files.txt"
$treeOutputFile  = Join-Path $PSScriptRoot "verified_tree.txt"
$brokenOutputFile= Join-Path $PSScriptRoot "broken_links.txt"
$maxThreads      = 20    # Peticiones HTTP simultáneas
$timeoutSec      = 10    # Timeout por petición en segundos

# Asegurar TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# =============================================================================
# LECTURA Y FILTRADO DEL FICHERO DE ENTRADA
# =============================================================================
if (-not (Test-Path $inputFile)) {
    Write-Error "No se encontró el fichero de entrada: $inputFile"
    exit 1
}

$allUrls = Get-Content $inputFile -Encoding UTF8 |
           Where-Object { $_ -match '^https?://' } |
           Select-Object -Unique |
           Sort-Object

$total = $allUrls.Count
Write-Host "URLs a verificar: $total" -ForegroundColor Cyan
Write-Host "Hilos paralelos : $maxThreads" -ForegroundColor Cyan
Write-Host "Timeout por URL : ${timeoutSec}s" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# VERIFICACIÓN PARALELA (compatible PS 5.1 y PS 7+)
# =============================================================================

# Resultado compartido entre hilos
$results = [System.Collections.Concurrent.ConcurrentBag[PSCustomObject]]::new()
$counter = [System.Threading.Volatile]::new()
$processed = [ref]0

$scriptBlock = {
    param($url, $timeoutSec)
    try {
        $req = [System.Net.HttpWebRequest]::Create($url)
        $req.Method  = "HEAD"
        $req.Timeout = $timeoutSec * 1000
        $req.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
        $req.AllowAutoRedirect = $true
        $response = $req.GetResponse()
        $statusCode = [int]$response.StatusCode
        $response.Close()
        return [PSCustomObject]@{ Url = $url; Status = $statusCode; Ok = ($statusCode -ge 200 -and $statusCode -lt 300) }
    } catch [System.Net.WebException] {
        $statusCode = 0
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        return [PSCustomObject]@{ Url = $url; Status = $statusCode; Ok = $false }
    } catch {
        return [PSCustomObject]@{ Url = $url; Status = -1; Ok = $false }
    }
}

# --- Runspace Pool ---
$pool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $maxThreads)
$pool.Open()

$jobs = [System.Collections.Generic.List[hashtable]]::new()

Write-Host "Iniciando verificación..." -ForegroundColor Yellow

foreach ($url in $allUrls) {
    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.RunspacePool = $pool
    $ps.AddScript($scriptBlock).AddArgument($url).AddArgument($timeoutSec) | Out-Null
    $jobs.Add(@{ PS = $ps; Handle = $ps.BeginInvoke() })
}

# Recoger resultados con progreso
$done = 0
foreach ($job in $jobs) {
    $result = $job.PS.EndInvoke($job.Handle)
    $job.PS.Dispose()
    if ($result) {
        $results.Add($result[0])
    }
    $done++
    if ($done % 50 -eq 0 -or $done -eq $total) {
        $pct = [math]::Round(($done / $total) * 100)
        Write-Progress -Activity "Verificando URLs" -Status "$done / $total ($pct%)" -PercentComplete $pct
    }
}

$pool.Close()
$pool.Dispose()
Write-Progress -Activity "Verificando URLs" -Completed

# =============================================================================
# CLASIFICACIÓN DE RESULTADOS
# =============================================================================
$validUrls  = $results | Where-Object { $_.Ok }  | Sort-Object Url
$brokenUrls = $results | Where-Object { -not $_.Ok } | Sort-Object Url

Write-Host ""
Write-Host "Resultados:" -ForegroundColor Cyan
Write-Host "  [OK]  Accesibles : $($validUrls.Count)" -ForegroundColor Green
Write-Host "  [KO]  Rotas/Error: $($brokenUrls.Count)" -ForegroundColor Red

# =============================================================================
# GENERACIÓN DEL ÁRBOL VISUAL
# =============================================================================
function Build-Tree {
    param([string[]]$urls)

    $output = [System.Text.StringBuilder]::new()

    # Agrupar por prefijo de directorio raíz (dominio + 1er segmento)
    $parsed = $urls | ForEach-Object {
        $uri = [System.Uri]$_
        [PSCustomObject]@{
            FullUrl  = $_
            Segments = ($uri.AbsolutePath.TrimStart('/') -split '/')
        }
    }

    # Construir árbol recursivo por cada nivel de ruta
    function Add-Level {
        param($items, $depth, $prefix)

        # Agrupar por primer segmento del nivel actual
        $groups = $items | Group-Object { $_.Segments[$depth] }

        for ($i = 0; $i -lt $groups.Count; $i++) {
            $g = $groups[$i]
            $isLast = ($i -eq $groups.Count - 1)
            $connector = if ($isLast) { "`-- " } else { "|-- " }
            $childPrefix = if ($isLast) { "$prefix    " } else { "$prefix|   " }

            # ¿Hay más niveles o es archivo final?
            $children = $g.Group | Where-Object { $_.Segments.Count -gt $depth + 1 }
            $leaves   = $g.Group | Where-Object { $_.Segments.Count -eq $depth + 1 }

            $label = $g.Name

            $null = $output.AppendLine("$prefix$connector$label")

            if ($children) {
                Add-Level -items $children -depth ($depth + 1) -prefix $childPrefix
            }
        }
    }

    # Agrupar por dominio primero
    $byDomain = $parsed | Group-Object { ([System.Uri]$_.FullUrl).Host }

    foreach ($domainGroup in $byDomain) {
        $null = $output.AppendLine("$($domainGroup.Name)")
        Add-Level -items $domainGroup.Group -depth 0 -prefix ""
        $null = $output.AppendLine("")
    }

    return $output.ToString()
}

Write-Host ""
Write-Host "Generando árbol de archivos verificados..." -ForegroundColor Yellow
$treeContent = Build-Tree -urls ($validUrls.Url)

# =============================================================================
# EXPORTACIÓN
# =============================================================================

# Árbol verificado
$header = @"
# Árbol de Archivos Verificados
# Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Total accesibles: $($validUrls.Count) / $total
# ============================================================================

"@
($header + $treeContent) | Set-Content -Path $treeOutputFile -Encoding UTF8
Write-Host "  >> $treeOutputFile" -ForegroundColor Green

# Informe de enlaces rotos
$brokenHeader = @"
# Informe de Enlaces Rotos
# Generado: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
# Total rotos: $($brokenUrls.Count) / $total
# Código -1 = timeout o error de red  |  Código 0 = sin respuesta HTTP
# ============================================================================

"@
$brokenContent = $brokenUrls | ForEach-Object {
    $statusLabel = switch ($_.Status) {
        -1  { "ERROR_RED" }
         0  { "SIN_RESPUESTA" }
        400 { "BAD_REQUEST" }
        401 { "NO_AUTORIZADO" }
        403 { "PROHIBIDO" }
        404 { "NO_ENCONTRADO" }
        500 { "ERROR_SERVIDOR" }
        default { "HTTP_$($_.Status)" }
    }
    "[{0,-15}] {1}" -f $statusLabel, $_.Url
}
($brokenHeader + ($brokenContent -join "`n")) | Set-Content -Path $brokenOutputFile -Encoding UTF8
Write-Host "  >> $brokenOutputFile" -ForegroundColor Green

Write-Host ""
Write-Host "¡Proceso completado!" -ForegroundColor Cyan
