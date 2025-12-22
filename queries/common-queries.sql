# Queries SQL Comunes para Cosmos DB - Biblioteca Online

Este documento contiene queries SQL útiles para consultar la base de datos de libros en Azure Cosmos DB.

## 📖 Queries de Libros (Contenedor: books)

### 1. Obtener todos los libros disponibles
```sql
SELECT * FROM c 
WHERE c.available = true
ORDER BY c.rating DESC
```

### 2. Buscar libros por título (búsqueda parcial)
```sql
SELECT * FROM c 
WHERE CONTAINS(LOWER(c.title), "señor")
```

### 3. Buscar libros por autor
```sql
SELECT * FROM c 
WHERE CONTAINS(LOWER(c.author.name), "tolkien")
ORDER BY c.publicationYear
```

### 4. Libros por categoría
```sql
SELECT * FROM c 
WHERE ARRAY_CONTAINS(c.categories, "Fantasía")
ORDER BY c.rating DESC
```

### 5. Top 10 libros mejor valorados
```sql
SELECT TOP 10 
    c.id, 
    c.title, 
    c.author.name as authorName,
    c.rating, 
    c.reviewCount
FROM c
WHERE c.available = true AND c.reviewCount > 0
ORDER BY c.rating DESC
```

### 6. Libros publicados en un rango de años
```sql
SELECT * FROM c 
WHERE c.publicationYear BETWEEN 1950 AND 2000
ORDER BY c.publicationYear DESC
```

### 7. Libros por idioma
```sql
SELECT * FROM c 
WHERE c.language = "es"
```

### 8. Libros con múltiples categorías (Fantasía y Aventura)
```sql
SELECT * FROM c 
WHERE ARRAY_CONTAINS(c.categories, "Fantasía") 
  AND ARRAY_CONTAINS(c.categories, "Aventura")
```

### 9. Libros con precio específico
```sql
SELECT 
    c.title,
    c.author.name as author,
    c.price.amount,
    c.price.currency
FROM c 
WHERE c.price.amount <= 20
ORDER BY c.price.amount
```

### 10. Búsqueda full-text en título y descripción
```sql
SELECT * FROM c 
WHERE CONTAINS(LOWER(c.title), "anillo") 
   OR CONTAINS(LOWER(c.description), "anillo")
```

## ⭐ Queries de Reseñas (Contenedor: reviews)

### 11. Reseñas de un libro específico
```sql
SELECT * FROM c 
WHERE c.bookId = "book-001"
ORDER BY c.createdAt DESC
```

### 12. Reseñas con 5 estrellas
```sql
SELECT * FROM c 
WHERE c.rating = 5
ORDER BY c.helpful DESC
```

### 13. Reseñas verificadas de un libro
```sql
SELECT * FROM c 
WHERE c.bookId = "book-001" AND c.verified = true
ORDER BY c.helpful DESC
```

### 14. Promedio de rating por libro (agregación)
```sql
SELECT 
    c.bookId,
    AVG(c.rating) as avgRating,
    COUNT(1) as totalReviews
FROM c
GROUP BY c.bookId
```

### 15. Reseñas más útiles
```sql
SELECT TOP 10 
    c.title as reviewTitle,
    c.userName,
    c.rating,
    c.helpful,
    c.bookId
FROM c
ORDER BY c.helpful DESC
```

### 16. Reseñas recientes (últimos 30 días)
```sql
SELECT * FROM c
WHERE c.createdAt >= DateTimeAdd("day", -30, GetCurrentDateTime())
ORDER BY c.createdAt DESC
```

### 17. Usuarios más activos en reseñas
```sql
SELECT 
    c.userId,
    c.userName,
    COUNT(1) as totalReviews,
    AVG(c.rating) as avgRating
FROM c
GROUP BY c.userId, c.userName
ORDER BY COUNT(1) DESC
```

## 🔍 Queries Avanzados

### 18. Libros con categorías y ratings (JOIN con filtros)
```sql
SELECT 
    c.title,
    c.author.name as author,
    JOIN category IN c.categories,
    c.rating,
    c.reviewCount
FROM c
WHERE c.rating >= 4.5
```

### 19. Estadísticas generales de la biblioteca
```sql
SELECT 
    COUNT(1) as totalBooks,
    AVG(c.rating) as avgRating,
    SUM(c.reviewCount) as totalReviews,
    AVG(c.pages) as avgPages,
    MAX(c.publicationYear) as newestYear,
    MIN(c.publicationYear) as oldestYear
FROM c
```

### 20. Búsqueda combinada (título, autor, categoría)
```sql
SELECT * FROM c
WHERE CONTAINS(LOWER(c.title), @searchTerm)
   OR CONTAINS(LOWER(c.author.name), @searchTerm)
   OR ARRAY_CONTAINS(c.categories, @searchTerm)
ORDER BY c.rating DESC
```

## 💡 Notas de Rendimiento

### Índices
Cosmos DB indexa automáticamente todos los campos por defecto. Para optimizar:
- Usa `WHERE` con campos indexados
- Evita `ORDER BY` en campos no indexados
- Limita resultados con `TOP` cuando sea posible

### Partition Keys
- **books**: partition key = `/id` (buena distribución)
- **reviews**: partition key = `/bookId` (co-localiza reseñas del mismo libro)

### RU/s (Request Units)
- Consultas simples: ~3-5 RU/s
- Consultas con ORDER BY: ~10-20 RU/s
- Consultas con agregaciones (GROUP BY): ~50-100 RU/s

### Buenas Prácticas
1. Siempre incluye la partition key en WHERE cuando sea posible
2. Usa `SELECT` específico en lugar de `SELECT *`
3. Agrega límites con `TOP` para consultas exploratorias
4. Usa índices compuestos para queries frecuentes con múltiples campos en ORDER BY

## 🔗 Parámetros en Queries

Para usar parámetros en tus queries desde código:

```javascript
// Ejemplo con Azure Cosmos DB SDK
const query = {
    query: "SELECT * FROM c WHERE CONTAINS(LOWER(c.title), @searchTerm)",
    parameters: [
        {
            name: "@searchTerm",
            value: "señor"
        }
    ]
};
```

## 📚 Referencias

- [SQL Query Reference](https://learn.microsoft.com/azure/cosmos-db/sql/sql-query-getting-started)
- [Query Performance Tips](https://learn.microsoft.com/azure/cosmos-db/sql-query-metrics)
- [Indexing Policies](https://learn.microsoft.com/azure/cosmos-db/index-policy)
