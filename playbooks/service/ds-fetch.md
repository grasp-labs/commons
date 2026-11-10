---
name: "ds-fetch: datalake access"
slug: ds-fetch
domain: service
description: "Playbook for reading the datalake through ds-fetch: gold datasets versus bronze/silver pipeline runs, discovery before SQL, the DuckDB SELECT dialect and function allowlist, row/size/time limits, history rows, caching and freshness."
when_to_use: "Answering a question from tenant data in the lakehouse, choosing which dataset or run to read, writing or debugging SQL against /datasets, or explaining a fetch error, truncated result or stale number."
prefer_skills: []
related_tools: [ls, preview, query, text_to_sql]
examples: []
---

ds-fetch runs read-only SQL over the tenant's Parquet lake. Agents reach it
through `ls /datasets`, `preview`, `query` and `text_to_sql`; see the
`preview`, `query` and `text_to_sql` playbooks for each tool. This one
covers how the lake is shaped and how to approach it.

## What is in the lake

- **Gold dataset**: `/datasets/gold/<dataset-id>`, SQL
  `gold."<dataset-id>"`. Long-lived and deduplicated across runs. Start
  here for business questions.
- **Run**: `/datasets/<bronze|silver>/<pipeline-id>/<job-id>`, SQL
  `silver."<pipeline-id>/<job-id>"`. The files one pipeline job produced.
  A snapshot run is the whole source; an incremental run only the
  changes. Never treat a run as the dataset over time.
- Names contain `-`, so always double-quote the id. IDs are lowercase
  UUIDs. Other layers are not served.
- Gold `key=value` folders are partition columns; `owner_id` is the first
  partition of a gold dataset.
- Gold with history keeps every version of a row. Current rows are
  `_valid_to IS NULL`; `preview` reports this as `history_mode: scd2`
  with a `current_rows_predicate`. Forgetting it inflates every count.

## Sequence

1. Discover: `ls /datasets` (or `/datasets/gold`, `/silver`, `/bronze`).
   The list holds only datasets you are granted.
2. Describe: `preview` each dataset you will read, for columns, types,
   partitions, the exact `sql_ref` and history mode.
3. Query: one statement, all aggregation in SQL. Never compute totals,
   averages or counts from returned rows.
4. Only if you cannot write the SQL, `text_to_sql` drafts it; it does
   not run it.

## SQL rules

- DuckDB dialect. Exactly one `SELECT` or `WITH … SELECT`, at most
  64 KiB. Joins across datasets are fine (up to 10 paths per `query`).
- Reference datasets only by name. Paths and table functions
  (`read_parquet`, `information_schema`, `duckdb_tables()`, settings,
  `ATTACH`) are rejected as `not_allowed`.
- Functions must be on the allowlist: common aggregates, window
  functions, math, string, regex, date/time, list/struct helpers,
  `coalesce`/`ifnull`/`nullif`/`if`. There are no JSON functions.
  `LIMIT … PERCENT` is not allowed.
- Columns are matched by name across files; a column missing from a file
  reads as NULL. If files disagree on a column's type, reading that
  column fails with `invalid_query` until the data is fixed.
- Filter on partition columns and select only needed columns: storage is
  columnar and partition filters skip files.
- Rows have no order without `ORDER BY`.

## Limits

- Inline result: at most 100,000 rows or 8 MiB; the server caps with a
  `LIMIT` and marks the result `truncated`. `query` returns `max_rows`
  inline (default 100, max 1000) and stores the rest as a file artifact.
- 25 s per query, then `504`: narrow the filter or aggregate more.
- Fair use: 60 queries per minute and 2 concurrent per principal; 1200
  per minute and 40 concurrent per tenant. `429` carries `Retry-After`.
- Large exports are not available today; split by a partition column
  such as `owner_id` or a date range.

## Freshness and caching

- Results are cached for 5 minutes per tenant, SQL and effective grants;
  new data in a dataset invalidates only queries that read it.
- Data written seconds ago may not be visible yet. Use `query` with
  `fresh: true` to re-list storage and bypass the cache; it is slower.
- If files vanish mid-query (a gold commit), fetch reruns once; still
  missing is `503` with `Retry-After`.

## Access

- Grants are per dataset and can narrow to partitions
  (`gold/<id>/owner_id=<owner>/**`). Two users can get different rows
  from the same SQL; never assume you see the whole dataset.
- An ungranted dataset and a missing one are both `unknown_dataset`.
  Do not probe names; check `ls /datasets`.

## Errors

| Code | Do |
| --- | --- |
| `syntax_error`, `unknown_column` | Fix the SQL against `preview` columns |
| `unknown_dataset` | Wrong id, unquoted name, or no grant |
| `not_allowed` | Remove the function, path or second statement |
| `invalid_query` | Type mismatch, often across files; cast or report |
| `resource_limit` | Aggregate earlier, filter partitions |

Outside AI Commons, the Python package `ds-fetch-py-sdk` wraps the same
API (`query`, `validate`, `datasets`, `dataset`).
