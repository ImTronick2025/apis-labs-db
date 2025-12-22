# APIs Labs - Database (Cosmos DB)

Este repositorio contiene los scripts, datos de ejemplo y documentación para la base de datos **Cosmos DB** del laboratorio de APIs modernas en Azure.

## 📚 Caso de Uso: Biblioteca Online

Una plataforma de consulta de libros online con las siguientes entidades:
- **Books**: Catálogo de libros
- **Authors**: Autores
- **Categories**: Categorías/géneros
- **Reviews**: Reseñas de usuarios

## 📁 Estructura del Repositorio

```
apis-labs-db/
├── README.md
├── schema/
│   ├── books.json          # Esquema de documentos de libros
│   ├── authors.json        # Esquema de autores
│   ├── categories.json     # Esquema de categorías
│   └── reviews.json        # Esquema de reseñas
├── sample-data/
│   ├── books-seed.json     # Datos de ejemplo: libros
│   ├── authors-seed.json   # Datos de ejemplo: autores
│   ├── categories-seed.json # Datos de ejemplo: categorías
│   └── reviews-seed.json   # Datos de ejemplo: reseñas
├── scripts/
│   ├── init-database.ps1   # Script de inicialización
│   └── seed-data.ps1       # Script para cargar datos de ejemplo
└── queries/
    ├── common-queries.sql  # Queries SQL comunes para Cosmos DB
    └── examples.md         # Ejemplos de uso

```

## 🗄️ Diseño de Base de Datos

### Contenedor: `books`
- **Partition Key**: `/id`
- **Documentos**: Libros con información embebida de autor y categorías

### Contenedor: `authors` (opcional)
- **Partition Key**: `/id`
- **Documentos**: Información de autores

### Contenedor: `reviews`
- **Partition Key**: `/bookId`
- **Documentos**: Reseñas agrupadas por libro

## 🚀 Configuración

### 1. Pre-requisitos
- Azure CLI instalado
- Credenciales de Azure configuradas
- Cosmos DB desplegado (desde `apis-labs-infra`)

### 2. Variables de Entorno

```bash
export COSMOS_ENDPOINT="https://apislabsdev-cosmos-xxxxx.documents.azure.com:443/"
export COSMOS_KEY="tu-cosmos-primary-key"
export COSMOS_DATABASE="apis-labs-db"
```

### 3. Inicializar Base de Datos

```powershell
# Inicializar contenedores
.\scripts\init-database.ps1

# Cargar datos de ejemplo
.\scripts\seed-data.ps1
```

## 📖 Esquema de Datos

### Book Document
```json
{
  "id": "book-001",
  "isbn": "978-0-123456-78-9",
  "title": "El Señor de los Anillos",
  "author": {
    "id": "author-001",
    "name": "J.R.R. Tolkien"
  },
  "categories": ["Fantasía", "Aventura"],
  "publicationYear": 1954,
  "language": "es",
  "pages": 1200,
  "publisher": "Editorial Minotauro",
  "description": "Una épica historia de aventuras...",
  "coverImage": "https://example.com/covers/lotr.jpg",
  "available": true,
  "rating": 4.8,
  "reviewCount": 1543,
  "createdAt": "2024-01-15T10:00:00Z",
  "updatedAt": "2024-12-22T15:30:00Z"
}
```

### Review Document
```json
{
  "id": "review-001",
  "bookId": "book-001",
  "userId": "user-123",
  "userName": "Ana García",
  "rating": 5,
  "title": "¡Obra maestra!",
  "comment": "Una historia increíble que te atrapa desde la primera página...",
  "helpful": 45,
  "createdAt": "2024-12-20T14:23:00Z"
}
```

## 🔍 Queries Comunes

### Buscar libros por título
```sql
SELECT * FROM c 
WHERE CONTAINS(LOWER(c.title), "señor")
```

### Obtener libros por categoría
```sql
SELECT * FROM c 
WHERE ARRAY_CONTAINS(c.categories, "Fantasía")
ORDER BY c.rating DESC
```

### Top libros mejor valorados
```sql
SELECT TOP 10 c.id, c.title, c.rating, c.reviewCount
FROM c
WHERE c.available = true
ORDER BY c.rating DESC
```

## 🔗 Integración con API Management

Los datos de esta base de datos son consumidos por:
- **APIs Backend**: Azure Functions (repositorio `apis-labs-functions`)
- **API Management**: Expone los endpoints (repositorio `apis-labs-infra`)
- **Swagger/OpenAPI**: Definiciones de API (repositorio `apis-labs-api`)

## 📝 Notas Importantes

- **Partition Key Strategy**: Usamos `/id` para el contenedor de libros para distribución uniforme
- **Reviews por libro**: Usamos `/bookId` como partition key para co-localizar reseñas del mismo libro
- **Cosmos DB Serverless**: Configurado para pago por uso, ideal para laboratorio
- **Índices**: Cosmos DB indexa automáticamente todos los campos

## 🛠️ Mantenimiento

### Backup
Los datos se respaldan automáticamente por Azure Cosmos DB con retención de 30 días.

### Monitoring
- Query RU/s consumption en Azure Portal
- Alertas configuradas para uso excesivo

## 📚 Referencias

- [Azure Cosmos DB Documentation](https://learn.microsoft.com/azure/cosmos-db/)
- [SQL API Query Reference](https://learn.microsoft.com/azure/cosmos-db/sql-query-getting-started)
- [Partitioning Best Practices](https://learn.microsoft.com/azure/cosmos-db/partitioning-overview)

## 👤 Autor

**ImTronick2025**  
Laboratorio DevOps para APIs Modernas en Azure
