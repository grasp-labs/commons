---
name: Workflow dataset activities
slug: workflow-io
domain: workflow
description: Configure workflow dataset tasks (read, create, update, upsert, delete, purge, list, rename) with batching, retry, $. row values, overrides, and failure channels.
when_to_use: A workflow step reads from or writes to an external system through a dataset, or a dataset task retries unexpectedly, sends a literal $. value, or ends in partial failure.
prefer_skills: []
related_tools: [ls, cat, write]
examples: [playbook/workflow/examples/workflow-io.json]
---

# Workflow dataset activities

A dataset task runs one operation on the dataset set in the task's `dataset_id`.
The dataset and its linked service decide what the call does: configure them
with the `protocol-http`, `protocol-soap`, `protocol-graphql`, `provider-microsoft` or `provider-xledger` playbook. This
playbook covers the task wrapper. Bindings and `upstream` edges work as in the
`workflow-python` playbook.

Type `ds.workflow.task.io.<op>.dataset`, version `1.0.0`. Output: the
provider's DataFrame on the success channel.

| `<op>` | Input port | Mode |
| --- | --- | --- |
| `read`, `list`, `purge`, `rename` | none | one provider call |
| `create` | `input` (single, required) | batched, `batch_size` default `0` |
| `update`, `upsert`, `delete` | `input` (single, required) | batched, `batch_size` default `1` |

`playbook/workflow/examples/workflow-io.json` holds a read and a batched create
payload.

## Settings

`retry` (3), `interval` (5), `backoff` (2), `include_error_columns` (false),
`overrides` ({}), `batch_size` on batched ops, plus `timeout` and `variables`.

- `overrides` is merged over the dataset settings at run time, one level deep:
  a key replaces the whole top-level settings key (all of `path_params`, all
  of `json`).
- Task settings are rendered before the run. A string value that is exactly
  `#/variables/<name>`, `#/tasks/<uuid>/success/$.<path>` or
  `@{builtin, args}` is replaced; text around it is not templated. Dataset
  settings are not rendered, so route runtime values through `overrides`.
- Batched ops resolve every `$.<column>` string in dataset settings and
  `overrides` (nested too) from the first row of each batch. Missing cells
  become `null`. Non-batched ops never resolve `$.`.

## Batching and retry

- `batch_size` 0 or less sends the whole input as one call; `1` is one call
  per row. Empty input makes no call and succeeds with an empty frame.
- Each batch retries on its own: up to `retry + 1` attempts, waiting
  `interval * backoff^(attempt-1)` seconds (a `backoff` below 1 counts as 1).
- Retried: 408, 429, any 5xx, and any exception without a status code (for
  example a bad `$.` column). Not retried: other 4xx, provider validation and
  not-supported errors.
- Non-batched ops ignore `retry`, `interval` and `backoff`: one error fails
  the task.

## Results and channels

| Outcome | Status | `success` content | `failure` content |
| --- | --- | --- | --- |
| all batches ok | `success` | concatenated outputs | none |
| some failed | `failure`, status 207 | outputs of ok batches | failed input rows |
| all failed | `failure`, status 500 | empty frame | failed input rows |

- Partial success is a failure, so an `all-success` downstream is skipped.
  Use `condition: all-done` on a task that must see the good rows anyway.
- `include_error_columns: true` adds `_ds_status_code`, `_ds_code`,
  `_ds_message`, `_ds_details`, `_ds_exception` and `_ds_metadata` to the
  failed rows. Bind `channel: failure` into a write, a concat or an email
  (see `workflow-control` and `workflow-functional`).

## Authoring with tools

- `ls /config/datasets` finds the dataset; `cat` it before wiring.
- `write /config/workflows/<uuid>/tasks` creates the task (`workflow_id` comes
  from the path); `write /config/maps/workflow-task-dependencies` adds the
  `upstream` edge from the producer.
- Writing per row: `batch_size: 1` with `$.` values in the dataset body or in
  `overrides`. Bulk endpoints: `batch_size: 0` or a page size the API accepts.

## Common failures

| Symptom | Likely cause |
| --- | --- |
| Literal `$.col` reaches the API | `$.` in a read, list, purge or rename |
| `Column 'x' not found in DataFrame` after a long wait | `$.` names a missing column; it is retried first |
| Downstream skipped after a write | Partial success is `failure` |
| `missing required input port bindings` | Batched op without an `input` binding |
| `#/variables/...` sent literally | Written in dataset settings; use `overrides` |
| Whole `path_params` lost | `overrides` replaced the key; send all of it |
