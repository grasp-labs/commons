---
name: commons-fetch
description: ds-fetch, read-only SQL (DuckDB) over the Commons datalake. Find datasets, name gold, silver and bronze tables, write efficient aggregate queries, and respect limits. Use for any data question against a tenant's lake, via the query tool or the REST API.
---

# ds-fetch

`https://grasp-daas.com/api/fetch[-dev]/v1`. Read-only DuckDB over the tenant's Parquet lake.
IAM: `fetch:query`, `fetch:listDataset`, `fetch:getDataset`; you only see datasets you are granted.

## Endpoints

| Call | Use |
|---|---|
| `GET /dataset/?layer=gold&name=&search=&limit=` | Datasets: `name`, `columns`, `row_count`, `byte_size`, `partition_columns` |
| `GET /dataset/{name}/` | One dataset |
| `POST /query/validate/` `{"sql"}` | Parse and authorize only |
| `POST /query/` `{"sql"}` | → `{columns, rows, row_count, truncated, elapsed_ms}` |

## Table names

| Layer | SQL name | Notes |
|---|---|---|
| Gold | `gold."<dataset-uuid>"` | Published table. SCD2: current rows `WHERE _valid_to IS NULL` |
| Silver | `silver."<pipeline-id>/<job-id>"` | One run's typed rows |
| Bronze | `bronze."<pipeline-id>/<job-id>"` | One run's raw rows |

Filter runs of one pipeline with `?prism=<pipeline-id>`.

## Limits

One `SELECT` or `WITH … SELECT`; SQL ≤ 64 KiB; ≤ 25 s (504 after); inline result ≤ 100,000 rows or
8 MiB (then `truncated: true`). Narrow by partition columns and time first.

## Query well

```sql
SELECT date_trunc('month', invoice_date) AS month, count(*) AS n, sum(net) AS net
FROM gold."<uuid>"
WHERE _valid_to IS NULL AND invoice_date >= DATE '2026-01-01'
GROUP BY 1 ORDER BY 1
```

- Aggregate in SQL; return the answer, not the rows. Select named columns, never `*` on personal data.
- Check shape first: `GET /dataset/{name}/` or tool `preview {rows: 0}`.
- Use `validate` before an expensive query.

## Tools

`ls /datasets/gold` → `preview {path, rows: 0}` (gives `sql_ref`) → `text_to_sql` → `query {paths,
sql, max_rows}` → `plot`. The full `query` result is stored as a file; only `max_rows` (default 100)
come back inline.

## Clients

Python `ds-fetch-py-sdk` (includes the `aic-fetch` CLI). Data safety: `commons-safety`.
