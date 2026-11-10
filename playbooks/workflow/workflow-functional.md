---
name: Workflow input, notification and error activities
slug: workflow-functional
domain: workflow
description: Turn a workflow variable into a DataFrame with the input source task, send email notifications with CSV attachments, and report failed rows without relying on collect-errors.
when_to_use: A workflow starts from a payload passed in as a variable, must email people (optionally with data attached), or must report which rows or tasks failed.
prefer_skills: []
related_tools: [ls, cat, write]
examples: [playbook/workflow/examples/workflow-functional.json]
---

# Workflow input, notification and error activities

| Task | `type` (version `1.0.0`) | Input port |
| --- | --- | --- |
| Input source | `ds.workflow.task.functional.input.source` | `payload`, single, required |
| Email | `ds.workflow.task.functional.notification.email` | `named_inputs`, map, optional |
| Collect errors | `ds.workflow.task.operational.analytics.collect-errors` | none |

Bindings and edges work as in the `python` playbook. Full payloads:
`playbook/workflow/examples/workflow-functional.json`.

## Runtime values

Task settings (except `variables`) are rendered just before a task runs. A
string value is replaced only when the whole value is a reference:

- `#/variables/<name>` and `#/variables/<name>/$.<path>`: workflow
  `settings.variables`, plus `run_id`, `session_id`, `pipeline_id`,
  `tenant_id`.
- `#/tasks/<uuid>/<field>` with `field` one of `status`, `success`,
  `failure`, `metadata`, `result`; add `/$.<path>` to select inside. On a
  DataFrame, `$.rows.0.total` is the first row's `total`.
- `@{builtin, arg, ...}`, e.g. `@{get_iso_timestamp_now}`.

Text around a reference is not substituted: `"Total: #/variables/x"` stays
literal. A missing variable or task fails the task. A `#/tasks/` target must
already have run, so make it an `upstream` ancestor.

## Input source

Settings: `format` (`json` default, `semi-structured-json`, `csv`,
`parquet`, `excel`, `xml`, `binary`) and `kwargs` for the pandas reader.

- Bind the port from a variable: `source: {kind: "variable", name:
  "<var>"}`, `target: {kind: "port", port: "payload"}`.
- A dict or list payload is JSON-encoded first, text is read as text, bytes as
  a file.
- `json` (pandas `read_json`) needs a list of records or a column-oriented
  object. For nested objects or one object of scalars use
  `semi-structured-json` with `kwargs.record_path` (and `meta`), as for HTTP
  responses.
- Errors fail with status 400, `DS_TASK_INVALID_INPUT_ERROR`, `Failed to
  deserialize input source payload.`; the reader error is in
  `details.error`.

## Email

Settings: `subject`, `content`, `content_type` (`html` or `text`),
`to_recipients` (list), `cc_recipients`, `attachment` (false).

- Mail is sent through Microsoft Graph from the platform notification
  mailbox. No linked service or tenant credentials are involved, and the
  sender cannot be chosen.
- `attachment: true` attaches every `named_inputs` entry as `<entry>.csv`.
  Each must be a DataFrame, and at least one must be bound, else the task
  fails with 400 `Invalid input data.`. With `attachment: false` bound inputs
  are ignored.
- Dynamic text: build it upstream (a `python` task returning one row with a
  `body` column) and set `content` to `#/tasks/<uuid>/success/$.rows.0.body`.
- Delivery is not verified. A Graph or network error is logged and the task
  still succeeds; an empty `to_recipients` sends nothing and succeeds. Confirm
  delivery once by hand before relying on a new notification.
- Typical wiring: email with `condition: any-failure` after critical tasks,
  or after a channel guard on a write's failure channel (see
  `workflow-control`).

## Reporting errors

`collect-errors` (setting `include_warnings`) reads per-task error entries
from the run context, but the runner does not record such entries, so it
returns an empty frame. Do not use it to detect failures.

Instead:

1. Set `include_error_columns: true` on dataset write tasks (see
   `workflow-io`); their failure channel then carries the failed rows with
   `_ds_code` and `_ds_message`.
2. Bind that `channel: failure` into a channel guard (`condition: all-done`),
   then into an email with `attachment: true`, or into a write that stores the
   rows.
3. For a task-level summary, reference `#/tasks/<uuid>/result` or
   `#/tasks/<uuid>/status` in settings.

## Common failures

| Symptom | Likely cause |
| --- | --- |
| `Failed to deserialize input source payload.` | Format does not match the payload shape |
| `missing required input port bindings` | No binding to `payload` |
| Reference text appears in the mail | Reference embedded in longer text |
| Task succeeded, no mail arrived | Send error swallowed, or empty `to_recipients` |
| `Invalid input data.` | `attachment: true` without a DataFrame bound |
| Collect errors always empty | Runner does not record its source entries |
