---
title: Step 2 — Anatomy of a task
---
# Step 2 — Anatomy of a task

A task is a small, boring, predictable record. That is a feature. Every task in the system — whether it reads a dataset or sends an email — has the same outer shape, and only the `settings` change.

## The five fields that matter

**`type`** — which task this is, chosen from a fixed registry. You do not invent types. If you find yourself wishing for a type that does not exist, the answer is usually a Python task, not a new type.

**`settings`** — the parameters for that specific type, and the only part of the record that varies. Saving does not check them. They are checked when the job starts: a missing or wrong-shaped setting fails the whole job before any task runs, while an unknown (misspelled) field is silently ignored. So a typo can leave you on a default without a word — check the typed schema.

**`condition`** — whether this task is allowed to run, based on how the tasks before it finished. Defaults matter here; the next step is entirely about this.

**`severity`** — `critical` or `minor`. Whether this task failing should sink the run or merely be recorded.

**`bindings`** — where this task's input data comes from. No bindings means no upstream data, regardless of what ran before it.

## Two more worth knowing

**`breakpoint`** — stop the run here: the task is cancelled without running, and tasks that needed it to succeed are skipped. Invaluable while developing: you get to inspect the results up to a specific point instead of guessing from logs.

**`dataset_id`** — a top-level field on tasks that read from or write to a specific dataset.

**`version`** and **`status`** — `version` is `1.0.0` for every built-in type; `status` is required when you save.

## The habit to build

Before writing a task, say out loud what it does. If it takes more than one sentence, it is two tasks.

One task per outcome makes conditions meaningful, failures diagnosable, and retries safe. A task that reads *and* transforms *and* writes gives you nowhere to stand when it fails halfway.

> The registry is a constraint, and constraints are what make workflows readable. Someone can understand your graph without reading a single line of your logic.

<!-- ds-course-column:2 type=markdown -->

## A task, in JSON

```json
{
  "name": "read-raw-ledger",
  "status": "active",
  "type": "ds.workflow.task.io.read.dataset",
  "version": "1.0.0",
  "dataset_id": "<dataset-uuid>",
  "condition": "all-success",
  "severity": "critical",
  "breakpoint": false,
  "settings": {},
  "bindings": []
}
```

### Type names come in two forms

The same type can be written two ways:

- **Dotted, fully qualified** — `ds.workflow.task.io.read.dataset`
- **Colon short name** — `io:read:dataset`

Only the dotted form goes in a task's `type`: the runtime looks types up by their exact name, and an unknown type fails the whole job at start. The short name is a convenience for `schema` lookups.

### Looking up any type's settings

You do not have to guess what `settings` a type accepts. Ask:

```text
schema("/config/workflows/<id>/tasks", type: "io:read:dataset")
```

That returns the required fields, the optional ones, and the defaults for that specific type.

Omit the `type` argument and you get the generic envelope instead — the outer shape plus the full enum of every type available to you. That is the fastest way to see the whole catalogue.

> Two calls give you everything: the envelope for what tasks look like, the typed schema for what one task needs.
