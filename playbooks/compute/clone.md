---
name: Clone compute block
slug: clone
domain: compute
description: Configure and run a clone that copies one source dataset into one target dataset, with column mappings and overwrite or snapshot-based delta sync.
when_to_use: Use when one dataset must be mirrored into another with no transformation beyond column renames and casts, or when debugging a clone that wiped, duplicated or missed rows.
prefer_skills: []
related_tools: [write, run, status, info, ls, cat, find]
examples: []
---
# Clone compute block

A clone reads one source dataset in full, applies column mappings, and writes the result to one target dataset. It is one job with no task graph. Use a workflow when you need filtering, joins, several sources, or per-run parameters.

## Config

`write /config/clones` with `name`, `status`, `source_id`, `target_id` (dataset ids; each dataset carries its linked service), optional `vpn_connection_id`, and `settings`:

| Key | Rule |
| --- | --- |
| `network.mode` | Required: `public`, `nat`, `vpn`, `static_ip` |
| `retry` | Required: `max_attempts` 0-100, `backoff_seconds` 0-10800 |
| `executor` | `lambda` (default) or `fargate` |
| `batch_size` | Rows per target call; default 1000; `0` = one call |
| `conflict_policy` | `overwrite` (default) or `delta` |
| `id_column` | Required for `delta` |
| `mappings.columns` | `{"<source col>": {"target": "<col>", "type": "<dtype>", "default": <value>}}` |

Mapping `type`: `string`, `int64`, `float64`, `boolean`, `datetime64[ns]`, `object`, `category`.

## What a run does

1. Reads the source once. No checkpoint is passed, so every run is a full read.
2. For each mapping, copies the source column into `target` (or fills `default` when the source column is missing) and casts to `type`. Source columns are kept. Every column of the result is sent to the target, so the target must accept them.
3. Applies the conflict policy, writing in `batch_size` chunks:
   - `overwrite`: one `purge` of the target, then `create` for all rows.
   - `delta`: loads the snapshot of the previous run. With no snapshot it purges and creates everything. Otherwise it diffs by `id_column`: new ids are created, changed rows updated, and ids missing from the source deleted. Then it saves the new snapshot.

The target provider must support `purge` and `create`; `delta` also needs `update` and `delete`.

## Delta rules

- The snapshot is a parquet file in the tenant's files, `<clone-uuid>.parquet`, one per clone. Find it with `ls /files/<clone-uuid>`. Removing it forces the next run to purge and reload the target.
- The diff is against the snapshot, not the target. Edits made directly in the target are not seen and are not repaired until the row changes at the source.
- `id_column` must exist in the mapped output and be non-null and unique in both source and snapshot, else the run fails.
- The source must return the full set every run. Any id missing from one read is deleted from the target.
- Change detection compares the columns shared by the source and the snapshot (NaN equals NaN). Adding a mapping changes the columns, so rows show up as updates.

## Triggers and execution

- `run /config/clones/<uuid>`. The clone ignores `payload`; parameters live on the config.
- Schedule: `write /config/schedules` (`cron` 5-field or `rate`), then `write /config/maps/clone-schedules` {`clone_id`, `schedule_id`}. Fires only when the clone and schedule are `active`; cron is matched in UTC.
- Webhook event: `/config/maps/clone-events` {`clone_id`, `event_id`}.
- One job runs per clone at a time; further fires queue and start when it finishes.
- A failed job is retried up to `retry.max_attempts` times, immediately (`backoff_seconds` is not applied). A retry is a full re-run: with `overwrite` it purges again.
- Track with `status /state/jobs/<id>`. On success the job result `details` holds the source and target ids and `diff` counts `added`, `updated`, `deleted`.

## Pitfalls

| Symptom | Cause |
| --- | --- |
| Target emptied, then partly filled | `overwrite` run failed after the purge; fix and re-run |
| Mass deletes on `delta` | Source returned a partial or filtered page set |
| `id_column ... contains duplicates` | Source key not unique; choose another column or dedupe in a workflow |
| Every row updated each run | A column with unstable values (timestamps) is mapped or present in the source |
| Unexpected columns rejected by target | Source columns are not dropped by mappings |
