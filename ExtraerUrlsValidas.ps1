<#
.SYNOPSIS
    Fase 3 - Tarea 1: ExtraccÃ³n de URLs VÃ¡lidas.
    Filtra las URLs de 'full_discovered_files.txt' eliminando las que estÃ¡n en 'broken_links.txt'.

.OUTPUTS
    valid_links.txt : Lista limpia de URLs operativas (HTTP 200).
#>

$fullDiscoveredFile = Join-Path $PSScriptRoot "full_discovered_files.txt"
$brokenLinksFile = Join-Path $PSScriptRoot "broken_links.txt"
$outputFile = Join-Path $PSScriptRoot "valid_links.txt"

# 1. Cargar todas las URLs descubiertas (limpiando posibles lÃneas vacÃas)
if (-not (Test-Path $fullDiscoveredFile)) {
    Write-Error "No se encontrÃ³ $fullDiscoveredFile"
    exit 1
}
$allUrls = Get-Content $fullDiscoveredFile -Encoding UTF8 | Where-Object { $_ -match "^https?://" }
Write-Host "Total URLs descubiertas: $($allUrls.Count)" -ForegroundColor Cyan

# 2. Cargar y parsear las URLs rotas
if (-not (Test-Path $brokenLinksFile)) {
    Write-Error "No se encontrÃ³ $brokenLinksFile"
    exit 1
}

# El formato de broken_links.txt es: [ESTADO] URL
# Usamos regex para extraer solo la URL de las lÃneas que no son comentarios (#)
$brokenContent = Get-Content $brokenLinksFile -Encoding UTF8
$brokenUrls = $brokenContent | Where-Object { $_ -match "^\[" } | ForEach-Object {
    if ($_ -match "\]\s+(https?://\S+)") {
        $matches[1].Trim()
    }
}

$brokenSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($url in $brokenUrls) { $null = $brokenSet.Add($url) }

Write-Host "Total URLs rotas detectadas: $($brokenSet.Count)" -ForegroundColor Red

# 3. Filtrar: Quedarse con las que NO estÃ¡n en el set de rotas
$validLinks = $allUrls | Where-Object { -not $brokenSet.Contains($_) }

Write-Host "Total URLs vÃ¡lidas resultantes: $($validLinks.Count)" -ForegroundColor Green

# 4. Guardar resultado
$validLinks | Set-Content $outputFile -Encoding UTF8
Write-Host "Archivo generado con Ã©xito: $outputFile" -ForegroundColor Cyan
