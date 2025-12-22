# ========================================
# Script de Carga de Datos a Cosmos DB (PowerShell)
# ========================================
# Este script carga los datos de ejemplo a Azure Cosmos DB usando PowerShell

param(
    [string]$CosmosAccountName = $env:COSMOS_ACCOUNT_NAME,
    [string]$DatabaseName = "apis-labs-db",
    [string]$ResourceGroup = "apis-labs-dev-rg"
)

# Configuración de colores
$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Carga de Datos a Cosmos DB" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

# Verificar parámetros
if (-not $CosmosAccountName) {
    Write-Host "❌ ERROR: Debes proporcionar el nombre de la cuenta de Cosmos DB" -ForegroundColor Red
    Write-Host "Uso: .\load-data.ps1 -CosmosAccountName <nombre>" -ForegroundColor Yellow
    exit 1
}

# Verificar Azure PowerShell
try {
    $azContext = Get-AzContext
    if (-not $azContext) {
        Write-Host "❌ No estás autenticado en Azure" -ForegroundColor Red
        Write-Host "Por favor ejecuta: Connect-AzAccount" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✓ Autenticado en Azure: $($azContext.Account)" -ForegroundColor Green
} catch {
    Write-Host "❌ Azure PowerShell no está instalado" -ForegroundColor Red
    Write-Host "Instala con: Install-Module -Name Az -AllowClobber -Scope CurrentUser" -ForegroundColor Yellow
    exit 1
}

# Obtener información de Cosmos DB
Write-Host "⏳ Obteniendo información de Cosmos DB..." -ForegroundColor Yellow

try {
    $cosmosAccount = Get-AzCosmosDBAccount `
        -ResourceGroupName $ResourceGroup `
        -Name $CosmosAccountName
    
    $cosmosKeys = Get-AzCosmosDBAccountKey `
        -ResourceGroupName $ResourceGroup `
        -Name $CosmosAccountName
    
    $endpoint = $cosmosAccount.DocumentEndpoint
    $primaryKey = $cosmosKeys.PrimaryMasterKey
    
    Write-Host "✓ Endpoint: $endpoint" -ForegroundColor Green
    Write-Host "✓ Keys obtenidas" -ForegroundColor Green
} catch {
    Write-Host "❌ Error al obtener información de Cosmos DB: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Función para cargar documentos
function Load-Documents {
    param(
        [string]$FilePath,
        [string]$Endpoint,
        [string]$Key,
        [string]$Database,
        [string]$Container
    )
    
    Write-Host "⏳ Cargando documentos desde $FilePath..." -ForegroundColor Yellow
    
    # Leer el archivo JSON
    $documents = Get-Content $FilePath -Raw | ConvertFrom-Json
    
    $count = 0
    foreach ($doc in $documents) {
        try {
            # Crear URL y headers para Cosmos DB REST API
            $date = [DateTime]::UtcNow.ToString("r")
            $verb = "POST"
            $resourceType = "docs"
            $resourceLink = "dbs/$Database/colls/$Container"
            
            # Crear authorization token
            $keyType = "master"
            $tokenVersion = "1.0"
            
            $hmac = New-Object System.Security.Cryptography.HMACSHA256
            $hmac.Key = [Convert]::FromBase64String($Key)
            
            $payLoad = "$($verb.ToLowerInvariant())`n$($resourceType.ToLowerInvariant())`n$resourceLink`n$($date.ToLowerInvariant())`n`n"
            $hashPayLoad = $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($payLoad))
            $signature = [Convert]::ToBase64String($hashPayLoad)
            
            $authHeader = [System.Web.HttpUtility]::UrlEncode("type=$keyType&ver=$tokenVersion&sig=$signature")
            
            # Construir URL
            $uri = "$Endpoint$resourceLink/docs"
            
            # Headers
            $headers = @{
                "authorization"         = $authHeader
                "x-ms-date"            = $date
                "x-ms-version"         = "2018-12-31"
                "x-ms-documentdb-partitionkey" = "[`"$($doc.id)`"]"
                "Content-Type"         = "application/json"
            }
            
            # Convertir documento a JSON
            $body = $doc | ConvertTo-Json -Depth 10 -Compress
            
            # Hacer POST request
            $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body
            
            Write-Host "  ✓ Cargado: $($doc.id)" -ForegroundColor Green
            $count++
        } catch {
            Write-Host "  ✗ Error al cargar $($doc.id): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host "✓ $count documentos cargados exitosamente" -ForegroundColor Green
    Write-Host ""
}

# Método alternativo usando Cosmos DB SDK
function Load-WithSDK {
    param(
        [string]$Endpoint,
        [string]$Key,
        [string]$Database
    )
    
    Write-Host "⏳ Cargando datos usando Cosmos DB SDK..." -ForegroundColor Yellow
    
    # Instalar módulo si no existe
    if (-not (Get-Module -ListAvailable -Name CosmosDB)) {
        Write-Host "⏳ Instalando módulo CosmosDB..." -ForegroundColor Yellow
        Install-Module -Name CosmosDB -AllowClobber -Scope CurrentUser -Force
    }
    
    Import-Module CosmosDB
    
    try {
        # Crear contexto de Cosmos DB
        $cosmosDbContext = New-CosmosDbContext `
            -Account $CosmosAccountName `
            -Key $Key `
            -KeyType 'Master'
        
        # Crear o verificar que existe el contenedor
        try {
            Get-CosmosDbCollection `
                -Context $cosmosDbContext `
                -Database $Database `
                -Id "items"
        } catch {
            Write-Host "⏳ Creando contenedor 'items'..." -ForegroundColor Yellow
            New-CosmosDbCollection `
                -Context $cosmosDbContext `
                -Database $Database `
                -Id "items" `
                -PartitionKey "id"
        }
        
        # Cargar libros
        Write-Host "`nCargando libros..." -ForegroundColor Cyan
        $books = Get-Content "..\sample-data\books-seed.json" -Raw | ConvertFrom-Json
        foreach ($book in $books) {
            try {
                $doc = $book | ConvertTo-Json -Depth 10 -Compress
                New-CosmosDbDocument `
                    -Context $cosmosDbContext `
                    -Database $Database `
                    -CollectionId "items" `
                    -DocumentBody $doc `
                    -PartitionKey $book.id
                
                Write-Host "  ✓ Cargado: $($book.id)" -ForegroundColor Green
            } catch {
                Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        # Cargar reseñas
        Write-Host "`nCargando reseñas..." -ForegroundColor Cyan
        $reviews = Get-Content "..\sample-data\reviews-seed.json" -Raw | ConvertFrom-Json
        foreach ($review in $reviews) {
            try {
                $doc = $review | ConvertTo-Json -Depth 10 -Compress
                New-CosmosDbDocument `
                    -Context $cosmosDbContext `
                    -Database $Database `
                    -CollectionId "items" `
                    -DocumentBody $doc `
                    -PartitionKey $review.id
                
                Write-Host "  ✓ Cargado: $($review.id)" -ForegroundColor Green
            } catch {
                Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        # Cargar autores
        Write-Host "`nCargando autores..." -ForegroundColor Cyan
        $authors = Get-Content "..\sample-data\authors-seed.json" -Raw | ConvertFrom-Json
        foreach ($author in $authors) {
            try {
                $doc = $author | ConvertTo-Json -Depth 10 -Compress
                New-CosmosDbDocument `
                    -Context $cosmosDbContext `
                    -Database $Database `
                    -CollectionId "items" `
                    -DocumentBody $doc `
                    -PartitionKey $author.id
                
                Write-Host "  ✓ Cargado: $($author.id)" -ForegroundColor Green
            } catch {
                Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        # Cargar usuarios
        Write-Host "`nCargando usuarios..." -ForegroundColor Cyan
        $users = Get-Content "..\sample-data\users-seed.json" -Raw | ConvertFrom-Json
        foreach ($user in $users) {
            try {
                $doc = $user | ConvertTo-Json -Depth 10 -Compress
                New-CosmosDbDocument `
                    -Context $cosmosDbContext `
                    -Database $Database `
                    -CollectionId "items" `
                    -DocumentBody $doc `
                    -PartitionKey $user.id
                
                Write-Host "  ✓ Cargado: $($user.id)" -ForegroundColor Green
            } catch {
                Write-Host "  ✗ Error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "  ✓ Carga completada exitosamente" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Información de conexión:" -ForegroundColor Blue
        Write-Host "  Endpoint: $Endpoint"
        Write-Host "  Database: $Database"
        Write-Host "  Container: items"
        Write-Host ""
        Write-Host "Para consultar los datos:" -ForegroundColor Yellow
        Write-Host "  1. Abre Azure Portal"
        Write-Host "  2. Ve a tu cuenta de Cosmos DB: $CosmosAccountName"
        Write-Host "  3. Usa Data Explorer para ejecutar queries SQL"
        Write-Host ""
        
    } catch {
        Write-Host "❌ Error en la carga de datos: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Intenta cargar manualmente usando Azure Portal" -ForegroundColor Yellow
        exit 1
    }
}

# Ejecutar carga de datos
Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Iniciando carga de datos..." -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

Load-WithSDK -Endpoint $endpoint -Key $primaryKey -Database $DatabaseName
