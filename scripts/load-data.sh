#!/bin/bash

# ========================================
# Script de Carga de Datos a Cosmos DB
# ========================================
# Este script carga los datos de ejemplo a Azure Cosmos DB

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración (reemplazar con tus valores)
COSMOS_ACCOUNT_NAME="${COSMOS_ACCOUNT_NAME:-apislabsdev-cosmos-sytft4}"
DATABASE_NAME="${COSMOS_DB_NAME:-apis-labs-db}"
RESOURCE_GROUP="${RESOURCE_GROUP:-apis-labs-dev-rg}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Carga de Datos a Cosmos DB${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Verificar que Azure CLI está instalado
if ! command -v az &> /dev/null; then
    echo -e "${RED}❌ Azure CLI no está instalado${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Azure CLI encontrado${NC}"

# Verificar login en Azure
echo -e "${YELLOW}⏳ Verificando autenticación con Azure...${NC}"
if ! az account show &> /dev/null; then
    echo -e "${RED}❌ No estás autenticado en Azure${NC}"
    echo "Por favor ejecuta: az login"
    exit 1
fi

echo -e "${GREEN}✓ Autenticado en Azure${NC}"

# Obtener la connection string de Cosmos DB
echo -e "${YELLOW}⏳ Obteniendo connection string de Cosmos DB...${NC}"
CONNECTION_STRING=$(az cosmosdb keys list \
    --name $COSMOS_ACCOUNT_NAME \
    --resource-group $RESOURCE_GROUP \
    --type connection-strings \
    --query "connectionStrings[0].connectionString" \
    --output tsv)

if [ -z "$CONNECTION_STRING" ]; then
    echo -e "${RED}❌ No se pudo obtener la connection string${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Connection string obtenida${NC}"

# Obtener el endpoint y key
COSMOS_ENDPOINT=$(az cosmosdb show \
    --name $COSMOS_ACCOUNT_NAME \
    --resource-group $RESOURCE_GROUP \
    --query documentEndpoint \
    --output tsv)

COSMOS_KEY=$(az cosmosdb keys list \
    --name $COSMOS_ACCOUNT_NAME \
    --resource-group $RESOURCE_GROUP \
    --query primaryMasterKey \
    --output tsv)

echo -e "${GREEN}✓ Endpoint: ${COSMOS_ENDPOINT}${NC}"

# Verificar que jq está instalado para procesar JSON
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️  jq no está instalado. Instalando...${NC}"
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt-get install -y jq
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install jq
    else
        echo -e "${RED}❌ Por favor instala jq manualmente${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ jq encontrado${NC}"
echo ""

# Función para cargar documentos
load_documents() {
    local file=$1
    local container=$2
    local count=0
    
    echo -e "${YELLOW}⏳ Cargando documentos de ${file} al contenedor ${container}...${NC}"
    
    # Leer el archivo JSON y cargar cada documento
    jq -c '.[]' "../sample-data/${file}" | while read -r doc; do
        # Extraer el ID del documento
        doc_id=$(echo "$doc" | jq -r '.id')
        
        # Crear un archivo temporal con el documento
        echo "$doc" > temp_doc.json
        
        # Subir el documento usando Azure CLI
        az cosmosdb sql container create \
            --account-name $COSMOS_ACCOUNT_NAME \
            --database-name $DATABASE_NAME \
            --name $container \
            --partition-key-path "/id" \
            --throughput 400 \
            --resource-group $RESOURCE_GROUP \
            2>/dev/null || true
        
        # Insertar el documento (usando REST API a través de curl)
        response=$(curl -s -X POST \
            "${COSMOS_ENDPOINT}dbs/${DATABASE_NAME}/colls/${container}/docs" \
            -H "authorization: $(az cosmosdb keys list --name $COSMOS_ACCOUNT_NAME --resource-group $RESOURCE_GROUP --query primaryMasterKey -o tsv | openssl enc -base64)" \
            -H "x-ms-date: $(date -u '+%a, %d %b %Y %H:%M:%S GMT')" \
            -H "x-ms-version: 2018-12-31" \
            -H "Content-Type: application/json" \
            -d "@temp_doc.json")
        
        count=$((count + 1))
        echo -e "${GREEN}  ✓ Cargado: ${doc_id}${NC}"
        
        rm -f temp_doc.json
    done
    
    echo -e "${GREEN}✓ ${count} documentos cargados exitosamente${NC}"
    echo ""
}

# Método alternativo usando Python y SDK de Cosmos DB
load_with_python() {
    echo -e "${YELLOW}⏳ Cargando datos usando Python SDK...${NC}"
    
    # Crear script Python temporal
    cat > load_data.py << 'PYTHON_SCRIPT'
import json
import sys
from azure.cosmos import CosmosClient, exceptions

def load_documents(endpoint, key, database_name, container_name, file_path):
    client = CosmosClient(endpoint, key)
    database = client.get_database_client(database_name)
    
    try:
        container = database.get_container_client(container_name)
    except:
        container = database.create_container(
            id=container_name,
            partition_key={'paths': ['/id'], 'kind': 'Hash'}
        )
    
    with open(file_path, 'r', encoding='utf-8') as f:
        documents = json.load(f)
    
    count = 0
    for doc in documents:
        try:
            container.upsert_item(doc)
            print(f"✓ Cargado: {doc['id']}")
            count += 1
        except exceptions.CosmosHttpResponseError as e:
            print(f"✗ Error al cargar {doc['id']}: {e.message}")
    
    print(f"\n✓ {count} documentos cargados exitosamente")

if __name__ == "__main__":
    endpoint = sys.argv[1]
    key = sys.argv[2]
    database = sys.argv[3]
    
    print("Cargando libros...")
    load_documents(endpoint, key, database, "items", "../sample-data/books-seed.json")
    
    print("\nCargando reseñas...")
    load_documents(endpoint, key, database, "items", "../sample-data/reviews-seed.json")
    
    print("\nCargando autores...")
    load_documents(endpoint, key, database, "items", "../sample-data/authors-seed.json")
    
    print("\nCargando usuarios...")
    load_documents(endpoint, key, database, "items", "../sample-data/users-seed.json")

PYTHON_SCRIPT

    # Verificar si Python y el SDK están instalados
    if command -v python3 &> /dev/null; then
        python3 -m pip install --quiet azure-cosmos 2>/dev/null || true
        python3 load_data.py "$COSMOS_ENDPOINT" "$COSMOS_KEY" "$DATABASE_NAME"
        rm -f load_data.py
    else
        echo -e "${RED}❌ Python 3 no está instalado${NC}"
        return 1
    fi
}

# Intentar cargar con Python
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Iniciando carga de datos...${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if load_with_python; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  ✓ Carga completada exitosamente${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${BLUE}Información de conexión:${NC}"
    echo -e "  Endpoint: ${COSMOS_ENDPOINT}"
    echo -e "  Database: ${DATABASE_NAME}"
    echo -e "  Container: items"
    echo ""
    echo -e "${YELLOW}Para consultar los datos:${NC}"
    echo -e "  1. Abre Azure Portal"
    echo -e "  2. Ve a tu cuenta de Cosmos DB"
    echo -e "  3. Usa Data Explorer para ejecutar queries SQL"
    echo ""
else
    echo -e "${RED}❌ Error en la carga de datos${NC}"
    echo -e "${YELLOW}Intenta cargar manualmente usando Azure Portal${NC}"
    exit 1
fi
