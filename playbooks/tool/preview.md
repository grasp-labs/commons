---
name: "preview"
slug: preview
domain: tool
description: "Playbook for the preview tool: describing one lakehouse dataset before querying it, sql_ref, partition and system columns, scd2 row history, stored sizes that are not business counts, and sample rows."
when_to_use: "Before writing SQL against a lakehouse dataset, or to identify what a /datasets path holds. Never to answer a question about the data."
prefer_skills: []
related_tools: [preview, ls, query, plot]
examples: []
---

`preview(path)` describes one lakehouse dataset so SQL can be written
against it. It is discovery only: no figure from a preview, including
`stored_rows`, is an answer. Totals and counts come from `query`.

Find the dataset with `ls /datasets` (or one layer,
`/datasets/gold|silver|bronze`); there is no `cat` for a dataset.

## Input

- `path`: `/datasets/gold/<id>` or
  `/datasets/<silver|bronze>/<pipeline-id>/<job-id>`; ids must be UUIDs.
  Leading and trailing slashes are optional.
- `rows`: sample rows, 0–5, default 5. `0` withholds them.
- `format`: `markdown` (default) or `json`. Use `json` when a program
  consumes the result.

## What to take from it

- `sql_ref`: the identifier to paste into SQL, already quoted
  (`gold."<id>"`). Copy it; do not rebuild it.
- `columns[]`: `name`, `type`, `partition`, `system`.
  - `partition: true` columns are the ones a `WHERE` should prefer; they
    prune files.
  - `system: true` (`_uid`, `_tenant_id`, `_system_time`, `_valid_from`,
    `_valid_to`) are platform columns: queryable, not business data.
- `history_mode`: `scd2` or `none`, decided from the columns (presence of
  `_valid_to`). With `scd2`, `current_rows_predicate` is
  `_valid_to IS NULL`; apply it or counts include superseded versions.
  If `_meta.history_source` says `columns (settings say …)`, the dataset's
  Config settings disagree with its real columns; the columns win.
- `primary_key_fields`, `ordering_field`: from Config, for joins and
  "latest" logic. Gold only.
- `name`, `description`: business name from Config (gold only).
  `_meta.source` is `fetch+config` when it was read, `fetch` otherwise.
  A Config failure is reported in `_meta.naming_error` and the preview
  still succeeds under the UUID.

## Stored sizes

`stored_rows`, `stored_bytes`, `stored_files` describe physical storage.
`stored_rows` counts rows as written, so a dataset that keeps history or
soft-deletes reports more rows than it has records; `stored_rows_note`
says so. It is absent for silver and bronze and for gold whose manifest is
not fully sized; `stored_files` is always present and predicts a slow
first query.

## Sample

- Read under your own grants, so it may hold fewer rows than asked, or
  none ("outside your grants" is a possible reason).
- With `scd2` the sample is filtered to current rows
  (`_meta.sample_filtered: true`).
- A failed sample is soft: `_meta.sample_error` is set and the schema is
  still returned.
- Use the sample to learn value shapes (`ACTIVE` vs `1`, date formats),
  never to total.

## Pitfalls

- A malformed id is rejected as `validation` before any call; an unknown
  or ungranted dataset is `not_found`. Take paths from `ls /datasets`.
- Preview each dataset in a join; history applies per dataset.
- The tool asks for at least 15 s when `timeout_ms` is omitted (a cold
  schema read is a storage round trip).
