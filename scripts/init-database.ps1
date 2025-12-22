<#
.SYNOPSIS
    Inicializa la base de datos Cosmos DB y crea los contenedores necesarios

.DESCRIPTION
    Este script crea la base de datos y los contenedores (collections) en Azure Cosmos DB
    para el proyecto de biblioteca online.

.PARAMETER CosmosEndpoint
    Endpoint de Cosmos DB (ejemplo: https://apislabsdev-cosmos-xxxxx.documents.azure.com:443/)

.PARAMETER CosmosKey
    Primary Key de Cosmos DB

.PARAMETER DatabaseName
    Nombre de la base de datos (por defecto: apis-labs-db)

.EXAMPLE
    .\init-database.ps1 -CosmosEndpoint "https://xxx.documents.azure.com:443/" -CosmosKey "your-key"

.NOTES
    Autor: ImTronick2025
    Requiere: Azure CLI instalado
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

# Colores para mensajes
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
║     Inicializador de Base de Datos Cosmos DB          ║
║              APIs Labs - Biblioteca Online            ║
╚═══════════════════════════════════════════════════════╝
"@ -ForegroundColor $InfoColor

# Validar parámetros
if ([string]::IsNullOrEmpty($CosmosEndpoint) -or [string]::IsNullOrEmpty($CosmosKey)) {
    Write-Error "Se requieren CosmosEndpoint y CosmosKey"
    Write-Host "`nOpciones:" -ForegroundColor $WarningColor
    Write-Host "1. Definir variables de entorno:" -ForegroundColor $InfoColor
    Write-Host "   `$env:COSMOS_ENDPOINT = 'https://xxx.documents.azure.com:443/'"
    Write-Host "   `$env:COSMOS_KEY = 'your-primary-key'"
    Write-Host "`n2. Pasar como parámetros:"
    Write-Host "   .\init-database.ps1 -CosmosEndpoint 'xxx' -CosmosKey 'xxx'"
    exit 1
}

# Extraer nombre de cuenta de Cosmos DB del endpoint
$CosmosAccountName = ($CosmosEndpoint -replace "https://", "" -replace ".documents.azure.com.*", "")
Write-Step "Cuenta de Cosmos DB: $CosmosAccountName"

try {
    # Verificar si Azure CLI está instalado
    Write-Step "Verificando Azure CLI..."
    $azVersion = az version --output json 2>&1 | ConvertFrom-Json
    Write-Success "Azure CLI versión $($azVersion.'azure-cli') detectado"

    # Login check
    Write-Step "Verificando sesión de Azure..."
    $account = az account show 2>&1 | ConvertFrom-Json
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Sesión activa: $($account.user.name)"
    } else {
        Write-Host "Iniciando sesión en Azure..." -ForegroundColor $WarningColor
        az login
    }

    # Crear base de datos
    Write-Step "Creando base de datos '$DatabaseName'..."
    $dbExists = az cosmosdb sql database exists `
        --account-name $CosmosAccountName `
        --resource-group $ResourceGroup `
        --name $DatabaseName `
        --output tsv 2>$null

    if ($dbExists -eq "true") {
        Write-Host "⚠️  La base de datos ya existe, omitiendo creación" -ForegroundColor $WarningColor
    } else {
        az cosmosdb sql database create `
            --account-name $CosmosAccountName `
            --resource-group $ResourceGroup `
            --name $DatabaseName `
            --output none
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Base de datos '$DatabaseName' creada"
        } else {
            throw "Error al crear la base de datos"
        }
    }

    # Crear contenedor de libros
    Write-Step "Creando contenedor 'books'..."
    $containerExists = az cosmosdb sql container exists `
        --account-name $CosmosAccountName `
        --resource-group $ResourceGroup `
        --database-name $DatabaseName `
        --name "books" `
        --output tsv 2>$null

    if ($containerExists -eq "true") {
        Write-Host "⚠️  El contenedor 'books' ya existe, omitiendo creación" -ForegroundColor $WarningColor
    } else {
        az cosmosdb sql container create `
            --account-name $CosmosAccountName `
            --resource-group $ResourceGroup `
            --database-name $DatabaseName `
            --name "books" `
            --partition-key-path "/id" `
            --output none
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Contenedor 'books' creado (partition key: /id)"
        } else {
            throw "Error al crear el contenedor 'books'"
        }
    }

    # Crear contenedor de reseñas
    Write-Step "Creando contenedor 'reviews'..."
    $reviewsExists = az cosmosdb sql container exists `
        --account-name $CosmosAccountName `
        --resource-group $ResourceGroup `
        --database-name $DatabaseName `
        --name "reviews" `
        --output tsv 2>$null

    if ($reviewsExists -eq "true") {
        Write-Host "⚠️  El contenedor 'reviews' ya existe, omitiendo creación" -ForegroundColor $WarningColor
    } else {
        az cosmosdb sql container create `
            --account-name $CosmosAccountName `
            --resource-group $ResourceGroup `
            --database-name $DatabaseName `
            --name "reviews" `
            --partition-key-path "/bookId" `
            --output none
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Contenedor 'reviews' creado (partition key: /bookId)"
        } else {
            throw "Error al crear el contenedor 'reviews'"
        }
    }

    # Resumen
    Write-Host "`n╔═══════════════════════════════════════════════════════╗" -ForegroundColor $SuccessColor
    Write-Host "║              ✅ Inicialización Completa               ║" -ForegroundColor $SuccessColor
    Write-Host "╚═══════════════════════════════════════════════════════╝" -ForegroundColor $SuccessColor
    Write-Host "`nBase de datos:      $DatabaseName" -ForegroundColor $InfoColor
    Write-Host "Contenedores:       books, reviews" -ForegroundColor $InfoColor
    Write-Host "Cuenta Cosmos DB:   $CosmosAccountName" -ForegroundColor $InfoColor
    Write-Host "`n💡 Siguiente paso: Ejecuta .\seed-data.ps1 para cargar datos de ejemplo" -ForegroundColor $WarningColor

} catch {
    Write-Error "Error durante la inicialización: $_"
    exit 1
}
