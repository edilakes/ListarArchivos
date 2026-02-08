<#
.SYNOPSIS
    Crea un crawler avanzado que, dada una URL base, navega de forma recursiva 
    a través de los archivos HTML para descubrir y mapear todos los recursos 
    enlazados dentro de un dominio.
#>

# --- CONFIGURACIÓN ---
$startUrl = "https://app.itheca.org/biblioteca/"
$targetDomain = "app.itheca.org"
$outputFile = "full_discovered_files.txt"


# --- INICIALIZACIÓN ---
$visitedUrls = New-Object 'System.Collections.Generic.HashSet[string]'
$urlQueue = New-Object 'System.Collections.Queue'
$allFoundResources = New-Object 'System.Collections.Generic.List[string]'


# --- FUNCIONES AUXILIARES ---
function Add-UrlToQueue {
    param(
        [string]$url,
        [string]$base
    )
    try {
        $absoluteUrl = ([System.Uri]::new([System.Uri]::new($base), $url)).AbsoluteUri
    } catch {
        # Silenciosamente ignorar URLs malformadas.
        return
    }

    if ($absoluteUrl.StartsWith("http") -and $absoluteUrl.Host -eq $targetDomain -and !$visitedUrls.Contains($absoluteUrl)) {
        $null = $visitedUrls.Add($absoluteUrl)
        $urlQueue.Enqueue($absoluteUrl)
    }
}


# --- SCRIPT PRINCIPAL ---

# 1. Descubrir los directorios iniciales.
Write-Host "Paso 1: Analizando la página principal para encontrar directorios iniciales..."
try {
    $initialResponse = Invoke-WebRequest -Uri $startUrl -ErrorAction Stop
    $directoryNames = $initialResponse.Links.Href | ForEach-Object {
        if ($_ -match '/bdpapp/([^/]+)/') { $matches[1] }
    } | Get-Unique
    
    foreach ($dirName in $directoryNames) {
        $fullDirUrl = "$startUrl$dirName/"
        Add-UrlToQueue -url $fullDirUrl -base $startUrl
    }
} catch {
    Write-Error "No se pudo acceder a la URL base '$startUrl'. Saliendo."
    exit
}

Write-Host "Paso 2: Empezando el crawling profundo. URLs iniciales en cola: $($urlQueue.Count)"
if ($urlQueue.Count -eq 0) {
    Write-Warning "No se encontraron directorios iniciales. No se puede continuar."
    exit
}

# 2. Bucle principal del crawler.
while ($urlQueue.Count -gt 0) {
    $currentUrl = $urlQueue.Dequeue()
    Write-Host "Procesando ($($urlQueue.Count) restantes): $currentUrl"
    
    $allFoundResources.Add($currentUrl)

    try {
        $response = Invoke-WebRequest -Uri $currentUrl -ErrorAction Stop
    } catch {
        Write-Warning "No se pudo procesar la URL: $currentUrl"
        continue
    }
    
    # Condición corregida: Asumir que es analizable si parece HTML.
    if ($response.RawContent -like "*<html*") {
        # Extraer todos los enlaces (href, src) usando la propiedad .Links y un regex de fallback.
        $response.Links.Href | ForEach-Object { Add-UrlToQueue -url $_ -base $currentUrl }
        $response.RawContent | Select-String -Pattern '(?:href|src)="([^"]+)"' -AllMatches | ForEach-Object {
            $_.Matches.Groups[1].Value | ForEach-Object { Add-UrlToQueue -url $_ -base $currentUrl }
        }
    }
}

# 3. Guardar todos los resultados en el archivo de salida.
Write-Host "`nProceso completado. Guardando $($allFoundResources.Count) recursos únicos en '$outputFile'..."
$allFoundResources | Get-Unique | Set-Content -Path $outputFile

Write-Host "¡Listo!"