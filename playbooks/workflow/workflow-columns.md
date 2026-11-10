---
name: Workflow column transformations
slug: workflow-columns
domain: workflow
description: Pick and configure the workflow column tasks (rename, assign, derived columns, dtypes, map, series) and avoid their silent no-ops and type traps.
when_to_use: A workflow must rename, add, recode, cast, or reformat DataFrame columns between a read and a write, or a column transformation task fails or leaves values unchanged.
prefer_skills: []
related_tools: [ls, cat, write]
examples: [playbook/workflow/examples/workflow-columns.json]
---

# Workflow column transformations

All six tasks take one DataFrame on port `input` (single, required), return one
DataFrame on the success channel, and are version `1.0.0`. Type prefix:
`ds.workflow.task.operational.transformation.`. Any exception fails the task
with its message. Bindings and edges work as in the `python` playbook;
`playbook/workflow/examples/workflow-columns.json` has one settings block per
task.

| Need | Task (`type` suffix) |
| --- | --- |
| Rename columns | `rename` |
| Overwrite values of an existing column | `assign` |
| New column: constant, copy, expression, concat, hash, split | `derived-columns` |
| Cast types or parse JSON strings | `dtypes` |
| Recode values through a lookup | `map` |
| Per-column pandas method, date formatting | `series` |

Prefer chaining these over a `python` task; use `python` when a step needs
string methods, row logic, or several inputs.

## rename

`columns`: `{"old": "new"}`. Column labels are cast to strings first. Unknown
old names are ignored without error.

## assign

`column`, `value`, `condition` (`notna`, `isna`, `all`). Sets `value` where
the condition holds on that same column. The column must exist (`Missing
required columns: ...`); empty input passes through. Fill nulls: `isna`.

## derived-columns

`operations`: a list applied in order, each `{type, column, ...}` (`type`
defaults to `eval`):

| `type` | Fields | Result in `column` |
| --- | --- | --- |
| `eval` | `expression` | pandas `eval`, e.g. `"net * 1.25"` |
| `assign` | `value` or `copy_from` | constant, or copy of another column |
| `function` | `func` | one value for all rows from `@{builtin, args}` or `#/variables/<name>` |
| `join` | `on` (list), `sep` (`-`) | row values joined as text, skipping `None`, `nan`, `NaN`, `NaT`, empty |
| `replace` | `old`, `new` | substring replace in strings; other values only on exact match |
| `explode` | `sep` | split by `sep`, one row per part |
| `hash` | none | hash of all current columns, as text |

- `hash` covers every column present at that point, including earlier derived
  ones; order the list accordingly. It fails on list or dict cells
  (`unhashable type`), for example after `dtypes` `json`.
- `replace` on a missing column is a silent no-op.

## dtypes

`mapping`: `{"column": "dtype"}` with pandas dtype names (`string`, `int64`,
`Int64`, `float64`, `bool`, `datetime64[ns]`), or `json` to parse JSON text
into objects. Columns not in the frame are skipped silently. `int64` fails on
nulls; use `Int64`.

## map

`column`, `mapping` (`{"from": "to"}`), `default_value`.

- Keys, values and the default are stored as strings. A numeric column never
  matches; cast it to `string` with `dtypes` first. Output values are strings.
- Values not in `mapping` get `default_value`. Always set `default_value`:
  without it the task fails with `Must specify a fill 'value' or 'method'.`
  even when every value is mapped. To keep unmapped values, map them to
  themselves.

## series

`operations`: a list of `{column, operation, arguments}`.

- `operation` is a pandas Series method called with keyword `arguments` only:
  `round` `{decimals}`, `fillna` `{value}`, `clip` `{lower, upper}`, `abs`,
  `replace` `{to_replace, value}`.
- `astype` `{dtype}` casts.
- `to_date` and `to_datetime` `{format, utc}` parse mixed inputs and write
  formatted text (default `%Y-%m-%d`, `utc` true), not a datetime dtype.
- Methods that need positional arguments are rejected, and so are module
  functions such as `to_numeric` (`requires positional arguments`). `.str`
  methods (`strip`, `lower`) are not reachable (`Unsupported series
  operation`): use `derived-columns` `replace`/`eval` or a `python` task.

## Common failures

| Symptom | Likely cause |
| --- | --- |
| `Missing required columns: x` | Column absent (assign, map, series, join, explode) |
| Rename or cast did nothing | Wrong column name; both skip unknown names |
| `Must specify a fill 'value' or 'method'.` | `map` without `default_value` |
| Map gives only the default | Column is numeric; cast to `string` first |
| `requires positional arguments` | Series op needs a positional argument or is a pandas function |
| Date column is text after `to_datetime` | It formats; cast with `dtypes` for a datetime |
