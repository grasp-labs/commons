---
name: Workflow row transformations
slug: workflow-rows
domain: workflow
description: Select rows and columns in workflows with the filter-values, filter-columns, query, SQL query, and extract XML value tasks, and pick the right one.
when_to_use: A workflow must drop or keep rows, keep a subset of columns, run SQL over one or more DataFrames, or pull a value out of an XML column, or such a task returns too many, too few, or no rows.
prefer_skills: []
related_tools: [ls, cat, write]
examples: [playbook/workflow/examples/workflow-rows.json]
---

# Workflow row transformations

Version `1.0.0`, type prefix `ds.workflow.task.operational.transformation.`,
one DataFrame out on the success channel. Any exception fails the task with
its message. Bindings and edges work as in the `python` playbook. Settings
shapes: `playbook/workflow/examples/workflow-rows.json`.

| Need | `type` suffix | Input port |
| --- | --- | --- |
| Keep/drop rows by list, substring, null, duplicate | `filter-values` | `input`, single |
| Keep listed columns, in order | `filter-columns` | `input`, single |
| Boolean row expression | `query` | `input`, single |
| SQL: joins, grouping, windows, casts, several inputs | `sql-query` | `inputs`, map, optional |
| Text of one XML element per row | `extract-xml-value` | `input`, single |

There is no plain `filter` type; use `filter-values` or `filter-columns`.

## filter-values

`filters`: a list, applied in order (AND). Each item has `column` plus any of
`include`, `exclude`, `contains` (lists) and `drop_duplicates`, `drop_none`,
`drop_empty`, `isna`, `notna` (booleans). Within one item the order is fixed:
duplicates, include, exclude, contains, none, empty, notna, isna.

- `include`, `exclude` and `contains` values are stored as strings. On a
  numeric column `include: [1]` matches nothing; cast the column with
  `dtypes` `string` first (see `workflow-columns`), or use `query`.
- `contains` is a plain substring match (no regex) on the value as text; any
  listed string matches.
- `drop_duplicates` keeps the first row per value of that one column.
- `drop_empty` removes only `""`; `drop_none` removes nulls.
- A missing column fails: `Missing required columns: x`.

## filter-columns

`columns`: names to keep, output in that order. Names not in the frame are
dropped without error, so a typo silently loses a column.

## query

`expr`: a pandas query string, e.g. `amount > 100 and status == "open"`.
Quote column names with spaces in backticks. Text around a reference is not
templated; to make the filter dynamic, set the whole `expr` to
`#/variables/<name>`.

## sql-query

`query`: DuckDB SQL. Each binding into `inputs` registers its DataFrame as a
table named by the binding `entry`, so `entry` must be a usable SQL
identifier. With no bindings the query still runs. Use it for joins across
more than two inputs, `GROUP BY`, window functions and `CAST`; it replaces
chains of filter and combine tasks. Output column names come from the
`SELECT` list.

## extract-xml-value

`column` (XML text or bytes), `new_column`, `xml_tag`. Per row the task runs
the XPath `./<xml_tag>` from the document root and writes the first match's
text to `new_column`.

- The path is relative to the root element: omit the root name
  (`Body/Result/Id`, not `Envelope/Body/Result/Id`).
- Only namespace prefixes declared on the root are usable (`soap:Body`).
  Elements in a default namespace (no prefix) never match by plain name; use
  `*[local-name()='Body']/*[local-name()='Id']`.
- Rows that fail to parse or do not match get `null`; the task still succeeds.
- If `column` is missing the task succeeds with an empty frame. Check the
  column name when a step returns no rows.

## Common failures

| Symptom | Likely cause |
| --- | --- |
| `include` keeps nothing | Numeric column vs string values |
| Column vanished | Misspelled in `filter-columns` |
| `name 'x' is not defined` in query | Column name has spaces or a typo; use backticks |
| `Catalog Error: Table with name x does not exist` | SQL table name differs from binding `entry` |
| `new_column` all `null` | Root name in `xml_tag`, or default namespace |
| Extract returns no rows | `column` not in the input |
