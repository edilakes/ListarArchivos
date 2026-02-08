# Fija la URL base donde queremos buscar los archivos.
$baseUrl = "https://app.itheca.org/biblioteca/"

# HashSet para almacenar las URLs ya visitadas y evitar bucles.
$visitedUrls = New-Object 'System.Collections.Generic.HashSet[string]'

# Lista para almacenar todos los archivos encontrados.
$allFiles = New-Object 'System.Collections.Generic.List[string]'

# 1. Descargar la página principal para encontrar pistas.
Write-Host "Paso 1: Analizando la página principal para encontrar nombres de directorios..."
try {
    $response = Invoke-WebRequest -Uri $baseUrl -ErrorAction Stop
} catch {
    Write-Error "No se pudo acceder a la URL base '$baseUrl'. Saliendo."
    exit
}

# 2. Extraer los nombres de los directorios de los enlaces.
$directoryNames = $response.Links.href | ForEach-Object {
    if ($_ -match '/bdpapp/([^/]+)/') {
        $matches[1]
    }
} | Get-Unique

Write-Host "Directorios encontrados: $($directoryNames -join ', ')"

# 3. Función recursiva para explorar cada directorio.
function Get-DirectoryListing {
    param(
        [string]$path
    )

    # Si ya hemos visitado esta URL, la saltamos para evitar bucles.
    if ($visitedUrls.Contains($path)) {
        return
    }
    # Si no, la añadimos a la lista de visitadas.
    $null = $visitedUrls.Add($path)

    Write-Host "Explorando: $path"
    try {
        $subResponse = Invoke-WebRequest -Uri $path -ErrorAction Stop
    } catch {
        Write-Warning "No se pudo acceder o no es un directorio válido: $path"
        return
    }

    # Extraer todos los enlaces de la página del directorio
    $links = $subResponse.Links.href

    foreach ($link in $links) {
        # Construir la URL completa y normalizarla (eliminar '..')
        $fullUrl = ([System.Uri]::new([System.Uri]::new($path), $link)).AbsoluteUri

        # Se excluye el enlace al directorio padre.
        if ($link.Equals('../')) {
            continue
        }

        # Si el enlace es un directorio (termina en '/'), llamarse a sí mismo.
        if ($fullUrl.EndsWith('/')) {
            Get-DirectoryListing -path $fullUrl
        }
        # Si es un archivo, guardarlo en la lista global.
        else {
            $allFiles.Add($fullUrl)
        }
    }
}

# 4. Iniciar el proceso para cada nombre de directorio descubierto.
Write-Host "`nPaso 2: Iniciando el listado recursivo de archivos..."
foreach ($dirName in $directoryNames) {
    $startUrl = "$baseUrl$dirName/"
    Get-DirectoryListing -path $startUrl
}

# 5. Guardar todos los resultados en el archivo de salida.
$outputFile = "discovered_files.txt"
Write-Host "`nProceso completado. Guardando $($allFiles.Count) archivos únicos en '$outputFile'..."
$allFiles | Get-Unique | Set-Content -Path $outputFile

Write-Host "¡Listo!"