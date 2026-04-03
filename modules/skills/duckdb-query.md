---
name: duckdb-query
description: Query any data file (CSV, JSON, Parquet, Excel) with SQL using DuckDB CLI
read_when: "user wants to query, analyze, or explore data files like CSV, JSON, Parquet, Avro, or Excel"
---

# DuckDB Query

Use DuckDB CLI to run SQL against local or remote data files without loading them into a database.

## Prerequisites

```bash
# Install if missing
brew install duckdb
# Or: curl -fsSL https://install.duckdb.org | sh
```

## Core Patterns

### Query any file directly
```bash
duckdb -c "SELECT * FROM 'data.csv' LIMIT 10"
duckdb -c "SELECT * FROM 'data.parquet' WHERE amount > 100"
duckdb -c "SELECT * FROM 'https://example.com/data.json'"
duckdb -c "SELECT * FROM read_csv('file.tsv', delim='\t')"
duckdb -c "SELECT * FROM read_xlsx('report.xlsx', sheet='Sheet1')"
```

### Explore schema
```bash
duckdb -c "DESCRIBE SELECT * FROM 'data.csv'"
duckdb -c "SELECT column_name, column_type FROM (DESCRIBE SELECT * FROM 'file.parquet')"
```

### Aggregations and joins
```bash
duckdb -c "
  SELECT category, COUNT(*) as cnt, AVG(price) as avg_price
  FROM 'sales.csv'
  GROUP BY category
  ORDER BY cnt DESC
"
duckdb -c "
  SELECT a.id, a.name, b.total
  FROM 'users.csv' a
  JOIN 'orders.parquet' b ON a.id = b.user_id
"
```

### Export results
```bash
duckdb -c "COPY (SELECT * FROM 'input.csv' WHERE status='active') TO 'output.parquet' (FORMAT PARQUET)"
duckdb -c "COPY (SELECT * FROM 'data.json') TO 'output.csv' (HEADER, DELIMITER ',')"
```

### Attach a database for interactive work
```bash
duckdb mydb.duckdb
# Then: CREATE TABLE t AS SELECT * FROM 'file.csv';
```

## Key Features
- **Friendly SQL**: `FROM tbl` without SELECT, `EXCLUDE` columns, `GROUP BY ALL`
- **Auto-detect**: CSVs, JSONs, Parquets detected automatically
- **Remote files**: HTTP(S), S3, GCS, Azure Blob supported
- **Extensions**: `INSTALL httpfs; LOAD httpfs;` for remote access

## When to Use
- Quick data exploration without Python/pandas
- Converting between formats (CSV to Parquet, JSON to CSV)
- SQL queries on files too large for spreadsheets
- Ad-hoc joins across different file formats
