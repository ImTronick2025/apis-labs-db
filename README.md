[![Validate Cosmos DB Data Model](https://github.com/ImTronick2025/apis-labs-db/actions/workflows/validate-db.yml/badge.svg)](https://github.com/ImTronick2025/apis-labs-db/actions/workflows/validate-db.yml)

# APIs Labs - Database (Cosmos DB)

This repo contains schema, sample data, and scripts for the Book Catalog.

## Containers
- books (partition key: /id)
- reviews (partition key: /bookId)

## Scripts

```
cd scripts
.\init-database.ps1
.\seed-data.ps1
```

## Environment

Set these variables or pass parameters:
- COSMOS_ENDPOINT
- COSMOS_KEY
- COSMOS_DATABASE (apis-labs-db)


