<#
.SYNOPSIS
    Carga datos de ejemplo en Cosmos DB

.DESCRIPTION
    Este script importa los datos de ejemplo (libros y reseñas) en los contenedores de Cosmos DB

.PARAMETER CosmosEndpoint
    Endpoint de Cosmos DB

.PARAMETER CosmosKey
    Primary Key de Cosmos DB

.PARAMETER DatabaseName
    Nombre de la base de datos (por defecto: apis-labs-db)

.EXAMPLE
    .\seed-data.ps1 -CosmosEndpoint "https://xxx.documents.azure.com:443/" -CosmosKey "your-key"

.NOTES
    Autor: ImTronick2025
    Requiere: Azure CLI y módulo Az.CosmosDB de PowerShell
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$CosmosEndpoint = $env:COSMOS_ENDPOINT,
    
    [Parameter(Mandatory=$false)]
    [string]$CosmosKey = $env:COSMOS_KEY,
    
    [Parameter(Mandatory=$false)]
    [string]$DatabaseName = "apis-labs-db",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "apis-labs-dev-rg"
)

# Colores
$SuccessColor = "Green"
$InfoColor = "Cyan"
$WarningColor = "Yellow"
$ErrorColor = "Red"

function Write-Step {
    param([string]$Message)
    Write-Host "`n🔹 $Message" -ForegroundColor $InfoColor
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor $SuccessColor
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor $ErrorColor
}

# Banner
Write-Host @"
╔═══════════════════════════════════════════════════════╗
║          Cargador de Datos de Ejemplo                ║
║              APIs Labs - Biblioteca Online            ║
╚═══════════════════════════════════════════════════════╝
"@ -ForegroundColor $InfoColor

# Validar parámetros
if ([string]::IsNullOrEmpty($CosmosEndpoint) -or [string]::IsNullOrEmpty($CosmosKey)) {
    Write-Error "Se requieren CosmosEndpoint y CosmosKey"
    exit 1
}

# Extraer nombre de cuenta
$CosmosAccountName = ($CosmosEndpoint -replace "https://", "" -replace ".documents.azure.com.*", "")

# Rutas de archivos
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$dataDir = Join-Path (Split-Path -Parent $scriptDir) "sample-data"
$booksFile = Join-Path $dataDir "books-seed.json"
$reviewsFile = Join-Path $dataDir "reviews-seed.json"

try {
    # Verificar archivos
    Write-Step "Verificando archivos de datos..."
    if (-not (Test-Path $booksFile)) {
        throw "Archivo de libros no encontrado: $booksFile"
    }
    if (-not (Test-Path $reviewsFile)) {
        throw "Archivo de reseñas no encontrado: $reviewsFile"
    }
    Write-Success "Archivos de datos encontrados"

    # Cargar datos JSON
    Write-Step "Cargando datos de libros..."
    $books = Get-Content $booksFile -Raw | ConvertFrom-Json
    Write-Success "$($books.Count) libros cargados desde archivo"

    Write-Step "Cargando datos de reseñas..."
    $reviews = Get-Content $reviewsFile -Raw | ConvertFrom-Json
    Write-Success "$($reviews.Count) reseñas cargadas desde archivo"

    # Importar libros
    Write-Step "Importando libros a Cosmos DB..."
    $booksImported = 0
    foreach ($book in $books) {
        $bookJson = $book | ConvertTo-Json -Depth 10 -Compress
        
        # Crear archivo temporal
        $tempFile = [System.IO.Path]::GetTempFileName()
        $bookJson | Out-File -FilePath $tempFile -Encoding UTF8
        
        try {
            az cosmosdb sql container item create `
                --account-name $CosmosAccountName `
                --resource-group $ResourceGroup `
                --database-name $DatabaseName `
                --container-name "books" `
                --partition-key-value $book.id `
                --body "@$tempFile" `
                --output none 2>$null
            
            if ($LASTEXITCODE -eq 0) {
                $booksImported++
                Write-Host "  📚 $($book.title) - $($book.author.name)" -ForegroundColor Gray
            } else {
                Write-Host "  ⚠️  $($book.title) ya existe" -ForegroundColor $WarningColor
            }
        } finally {
            Remove-Item $tempFile -ErrorAction SilentlyContinue
        }
    }
    Write-Success "$booksImported/$($books.Count) libros importados"

    # Importar reseñas
    Write-Step "Importando reseñas a Cosmos DB..."
    $reviewsImported = 0
    foreach ($review in $reviews) {
        $reviewJson = $review | ConvertTo-Json -Depth 10 -Compress
        
        $tempFile = [System.IO.Path]::GetTempFileName()
        $reviewJson | Out-File -FilePath $tempFile -Encoding UTF8
        
        try {
            az cosmosdb sql container item create `
                --account-name $CosmosAccountName `
                --resource-group $ResourceGroup `
                --database-name $DatabaseName `
                --container-name "reviews" `
                --partition-key-value $review.bookId `
                --body "@$tempFile" `
                --output none 2>$null
            
            if ($LASTEXITCODE -eq 0) {
                $reviewsImported++
                Write-Host "  ⭐ $($review.title) por $($review.userName)" -ForegroundColor Gray
            } else {
                Write-Host "  ⚠️  Reseña $($review.id) ya existe" -ForegroundColor $WarningColor
            }
        } finally {
            Remove-Item $tempFile -ErrorAction SilentlyContinue
        }
    }
    Write-Success "$reviewsImported/$($reviews.Count) reseñas importadas"

    # Resumen final
    Write-Host "`n╔═══════════════════════════════════════════════════════╗" -ForegroundColor $SuccessColor
    Write-Host "║           ✅ Carga de Datos Completa                  ║" -ForegroundColor $SuccessColor
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor $SuccessColor
    Write-Host "`nLibros importados:    $booksImported" -ForegroundColor $InfoColor
    Write-Host "Reseñas importadas:   $reviewsImported" -ForegroundColor $InfoColor
    Write-Host "Base de datos:        $DatabaseName" -ForegroundColor $InfoColor
    Write-Host "`n💡 Ahora puedes consultar los datos desde Azure Portal o mediante las APIs" -ForegroundColor $WarningColor

} catch {
    Write-Error "Error durante la carga de datos: $_"
    exit 1
}
