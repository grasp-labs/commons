---
name: "query"
slug: query
domain: tool
description: "Playbook for the query tool: running read-only DuckDB SQL over lakehouse datasets, sql_ref quoting, capped vs truncated results, row-history predicates, float columns, and the engine's limits."
when_to_use: "Any number, total, count, average or ranking drawn from lakehouse data. Call preview first for each dataset; never compute figures yourself from rows."
prefer_skills: []
related_tools: [query, preview, ls, plot, cat, text_to_sql]
examples: []
---

`query` runs one read-only statement against lakehouse datasets and returns
the rows plus the provenance of how they were produced. It is the only way
to obtain a number: put every total, count, average and percentage in the
SQL, never in your head.

## Sequence

1. `ls /datasets` (or `/datasets/gold|silver|bronze`) to find the dataset.
2. `preview` each dataset: columns, partition columns, `sql_ref`,
   `history_mode`.
3. `query` with `paths` and `sql`. To chart the same statement, pass it to
   `plot`; do not carry rows from `query` to `plot`.

## Input

- `paths`: 1–10 dataset paths, all under `/datasets`:
  `/datasets/gold/<id>` or `/datasets/<silver|bronze>/<pipeline-id>/<job-id>`.
  Every id must be a UUID. `/files` is not queryable.
- `sql`: one `SELECT` or `WITH … SELECT`, DuckDB dialect, at most 64 KiB.
  Several datasets may be joined. Sent byte for byte; only surrounding
  whitespace is trimmed.
- `max_rows`: rows returned inline, 1–1000, default 100.
- `fresh`: bypass the result cache (used right after data was written).

## Rules

- **Reference datasets by `sql_ref` verbatim**: `gold."<id>"` or
  `silver."<pipeline-id>/<job-id>"`. The layer is a bare schema, the id is
  quoted because it contains hyphens. Getting this wrong is the most
  common parse failure.
- **Row history.** If `preview` says `history_mode: scd2`, add
  `_valid_to IS NULL` for current rows, on every side of every join.
  `_meta.history_warning` lists historied datasets in `paths` but never
  checks whether your SQL already applies the predicate.
- **System columns** (`_uid`, `_tenant_id`, `_system_time`, `_valid_from`,
  `_valid_to`) are queryable but not business data; do not group by them.
- **Filter on partition columns** where possible; it eliminates files.
- **Money.** `_meta.float_columns` names DOUBLE/FLOAT/REAL result columns.
  DuckDB returns DOUBLE for decimal division and `AVG()` over decimals, so
  cast back (e.g. `CAST(AVG(x) AS DECIMAL(18,2))`) when exactness matters.
- Authorization is ds-fetch's, under your own token: dataset grants and
  partition row filters apply. A dataset you cannot see fails like one that
  does not exist.

## Reading the result

`{columns, rows, _meta}`. `_meta` carries `sql`, `paths`, `row_count`,
`capped`, `truncated`, `note`, `float_columns`, `history_warning`,
`artifact_file_id`, `artifact_error`, `elapsed_ms`, `cache`.

- `capped`: more than `max_rows` rows. The full result is stored as a JSON
  file at `_meta.artifact_file_id` (`{columns, rows, row_count, truncated,
  sql, paths}`); read it with `cat /files/<id>/content`. If
  `artifact_error` is set, the rest was not kept: any total over the
  inline rows is wrong.
- `truncated`: the engine hit its own ceiling (100,000 rows or 8 MiB) and
  never produced the rest. Any aggregate over the rows is wrong. Aggregate
  in SQL or narrow the query.
- `note` states which applies in words; read it before quoting a figure.
- `row_count` is what the query produced, not what is inline.

## Failures

| Symptom | Fix |
| --- | --- |
| `validation` naming `paths` | Wrong path form, mixed roots, more than 10, or not a UUID |
| `validation` with ds-fetch code `syntax_error` / `invalid_query` | Check `sql_ref` quoting and DuckDB syntax |
| `not_allowed` | Not a single SELECT, or a function outside ds-fetch's allowlist |
| `unknown_column` / `unknown_dataset` | Re-`preview`; the id or column is wrong or not granted |
| `resource_limit` | Memory/spill exceeded; aggregate or filter earlier |
| `timeout` "exceeded the engine's execution limit" | 25 s engine ceiling. Add a filter, aggregate, or read fewer partitions. A longer `timeout_ms` cannot help |

The tool asks for at least 30 s when `timeout_ms` is omitted; do not set
`timeout_ms` lower than that. `text_to_sql` is for callers with no model;
an agent writes the SQL itself.
