---
name: Pipeline compute block (Prism datalakehouse)
slug: pipeline
domain: compute
description: Configure, run and query a Prism pipeline that lands one source dataset through bronze, silver and gold layers, with snapshot or incremental loads and upsert or replace publishing.
when_to_use: Use when a source must become a governed, queryable gold dataset with history or keyed merges, or when debugging a pipeline job, a stage failure, or a checkpoint that skipped or repeated rows.
prefer_skills: []
related_tools: [write, run, status, info, ls, cat, query, preview, schema]
examples: []
---
# Pipeline compute block

A pipeline moves one source dataset through three job stages: **bronze** reads the source into raw parquet, **silver** runs one SQL `SELECT` over it, **gold** merges the result into a curated, queryable gold dataset. Use a workflow for multi-source logic, a clone for a plain copy.

## Config

`write /config/pipelines` with `name`, `status`, `owner_id` (the gold partition this pipeline writes), `bronze_id` (source dataset), `gold_id` (a `ds.resource.dataset.aic-gold` dataset), `snapshot_profile_id` and `incremental_profile_id` (`/config/runtime-profiles`), `transform`, `settings`, optional `vpn_connection_id`.

`settings`:

- `strategy_policy.defaults.load_mode`: `snapshot` or `incremental` (default `incremental`).
- `artifact_policy.bronze_retention_days` and `silver_retention_days`: one of `7d`, `14d`, `30d`, `90d`, `180d` (default), `365d`, then yearly steps up to `3285d`.
- Optional `notify` `{email, on_failure, on_success}`. At least one flag must be true.

`transform`:

- `sql_query`: one `SELECT ... FROM bronze [AS b] [WHERE ...]`, run on DuckDB. No `WITH`, `UNION`, `DISTINCT`, `GROUP BY`, `HAVING`, windows, `ORDER BY`, `LIMIT`. Every expression needs `AS`; output names are unique; `_valid_from`/`_valid_to` are reserved.
- `non_null_columns`: required output columns; a null in any fails the run.

Gold dataset `settings` (the gold stage reads these):

| Key | Rule |
| --- | --- |
| `primary_key_fields` | Required; must not overlap `partition_keys` |
| `history_mode` | Required: `scd2` (adds `_valid_from`/`_valid_to`) or `none` |
| `ordering_field` | Optional. A row whose value is not newer than the stored row is ignored. Without it, rows whose content is unchanged are ignored |
| `delete_field` | Optional boolean column; true deletes the key |
| `partition_keys` | Optional |
| `publish_mode` | `upsert` (default) or `replace` |

## Strategies

- `snapshot` reads the full source and ignores the stored checkpoint.
- `incremental` resumes from the stored checkpoint. It requires a provider that supports checkpoints, otherwise bronze fails with a validation error. The first incremental run has no checkpoint and reads everything.
- The checkpoint is kept per pipeline and source dataset version. Bronze saves it after every successful read, including snapshot and empty reads, so a snapshot run moves the next incremental window. A failed read does not save it; a new dataset version starts empty.
- `upsert` merges by primary key and keeps rows it does not touch.
- `replace` rebuilds this `owner_id`'s data from the run's rows and leaves other owners alone. Pairing `replace` with `incremental` drops every row outside the window.
- The load mode also picks the runtime profile.

## Run and triggers

- `run /config/pipelines/<uuid>` with `payload` `{"strategy_policy": {"load_mode": "...", "publish_mode": "..."}}`; each key overrides the config. Unset `load_mode` falls back to `snapshot`; unset `publish_mode` to the gold dataset's, then `upsert`.
- `/config/maps/pipeline-schedules` `{pipeline_id, schedule_id, settings}` and `/config/maps/pipeline-events` `{pipeline_id, event_id, settings}` require `settings.strategy_policy` with both modes; it becomes the run payload. Only `active` pipelines and schedules fire; cron is UTC.
- One job runs per pipeline; later fires queue.
- A stage is retried only when dispatching it fails with a transient error. A stage that fails while running fails the whole job.
- If bronze or silver produces no rows, the job completes and gold is untouched.

## Status

`status /state/jobs/<id>` for the job; `ls /state/jobs/<id>/stages` for each stage's result and artifact stats. The gold result reports `rows_inserted`, `rows_updated`, `rows_closed`, `rows_noop`.

## Query results

- Gold: `/datasets/gold/<gold-dataset-uuid>`. In SQL, write it as `gold."<uuid>"`.
- One run's bronze or silver output: `/datasets/<bronze|silver>/<pipeline-uuid>/<job-uuid>`. It is kept for the retention period.
- `ls /datasets` to browse, `schema`/`preview` to inspect, `query` or `text_to_sql` for SQL.
- Gold adds the system columns `_uid`, `_tenant_id` and `_system_time`. In `scd2`, current rows have `_valid_to IS NULL`.

## Pitfalls

| Symptom | Cause |
| --- | --- |
| Incremental run repeats rows | The previous read failed, so the checkpoint was not saved |
| Incremental run misses rows | A snapshot run moved the checkpoint, or the window logic belongs to the source |
| `non_null_columns absent from query result` | Name the output column, not the bronze column |
| Gold rows disappeared | `replace` was used with `incremental` |
| Rows never updated | `ordering_field` not increasing at source |
| Bronze fails on `runtime_policy` | The runtime profile shape is not accepted; escalate |
