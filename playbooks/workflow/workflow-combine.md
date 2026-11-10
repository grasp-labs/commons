---
name: Workflow combine transformations
slug: workflow-combine
domain: workflow
description: Merge, stack, and group workflow DataFrames with the join, concat, and aggregate tasks, including their defaults that silently change row counts.
when_to_use: A workflow must join two DataFrames on keys, stack the outputs of several tasks (including failure channels), or group and summarise rows, or such a task returns an unexpected row count.
prefer_skills: []
related_tools: [ls, cat, write]
examples: [playbook/workflow/examples/workflow-combine.json]
---

# Workflow combine transformations

Version `1.0.0`, type prefix `ds.workflow.task.operational.transformation.`,
one DataFrame out on the success channel. Any exception fails the task with
its message. Bindings and edges work as in the `workflow-python` playbook.

| Task | `type` suffix | Input ports |
| --- | --- | --- |
| Join two frames on keys | `join` | `left`, `right` (single, required) |
| Stack frames vertically | `concat` | `inputs` (list, required, at least one) |
| Group and summarise | `aggregate` | `input` (single, required) |

For three or more inputs, filtered joins or grouping with expressions, one
`sql-query` task (see `workflow-rows`) is usually simpler than a chain.

Settings and bindings for all three: `playbook/workflow/examples/workflow-combine.json`.

## join

`condition`: keyword arguments for pandas `merge`, passed through as is:
`on`, `left_on`, `right_on`, `how` (`inner` default, `left`, `right`,
`outer`, `cross`), `suffixes` (default `["_x", "_y"]`), `validate`
(`one_to_one`, `one_to_many`, `many_to_one`), `indicator`.

```json
{"condition": {"left_on": "customer_id", "right_on": "id", "how": "left", "validate": "many_to_one"}}
```

- Bind `left` and `right` separately, each with `target: {kind: "port",
  port: "left"}` or `"right"`.
- Key columns must have the same dtype; an int key against a text key fails.
  Align them with `dtypes` first (see `workflow-columns`).
- A frame with no columns (for example an empty read) fails: `Both
  DataFrames must have at least one column to perform a merge.` Guard empty
  reads with a channel guard (see `workflow-control`).
- Duplicate keys multiply rows; set `validate` to fail loudly instead.

## concat

Settings: `drop_duplicates` (true), `reset_index` (true). `ignore_index` is
accepted but has no effect; the index is always rebuilt.

- Frames stack in binding order; columns are the union, missing cells are
  null.
- `drop_duplicates` defaults to true and removes identical rows across all
  inputs. Set it to false when repeated rows are real data.
- Every bound value must be a DataFrame. A producer that was skipped or has no
  content on the bound channel yields `null` and fails the task (`Input must
  be a list of pandas DataFrame instances`).
- Dataset write tasks always put a DataFrame on their success channel, even
  when every batch failed, so they are safe to stack. To collect failed rows,
  bind each writer's `channel: failure` with `condition: all-done` on the
  concat (see `workflow-io`); this only works when every writer actually has
  failures.

## aggregate

Settings: `by` (column name or list), `func`, `round` (2), `filter`, `keep`
(true).

- `func` is a pandas `agg` spec: `"sum"`, `["sum", "mean"]`, or
  `{"amount": "sum", "lines": "count"}`. Prefer the dict form: a bare
  `"sum"` also aggregates every non-key column, including text.
- Groups keep null keys; key columns stay as regular columns.
- Numeric results are rounded to `round` digits (default 2).
- `filter` (aggregate only some key values) fails in every configuration
  (`'filter' aggregation requires a single group-by column.`), because `by`
  is always stored as a list. Filter rows first with `filter-values`, and
  leave `filter` and `keep` unset.

## Common failures

| Symptom | Likely cause |
| --- | --- |
| Fewer rows after concat | `drop_duplicates` default true |
| More rows after join | Duplicate keys on one side |
| `You are trying to merge on int64 and object columns` | Key dtypes differ |
| `Input must be a list of pandas DataFrame instances` | A bound channel had no content |
| `'filter' aggregation requires a single group-by column.` | `filter` set on aggregate |
| Amounts lose decimals | `round` default 2 |
