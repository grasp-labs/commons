---
title: Step 6 — Wire the data with bindings
---
## Bindings, in JSON

A transformation that needs one frame in:

```json
{
  "name": "validate-ledger",
  "type": "ds.workflow.task.operational.transformation.filter-values",
  "condition": "all-success",
  "severity": "critical",
  "bindings": [
    {
      "source": { "kind": "task-ref", "ref": { "id": "<task-uuid>", "name": "read-raw-ledger" }, "channel": "success" },
      "target": { "kind": "port", "port": "input" }
    }
  ]
}
```

One entry: take what `read-raw-ledger` produced on its success channel, hand it to this task's `input` port.

### A join needs two

```json
{
  "name": "join-customers",
  "type": "ds.workflow.task.operational.transformation.join",
  "bindings": [
    { "source": { "kind": "task-ref", "ref": { "id": "<task-uuid>", "name": "validate-ledger" } }, "target": { "kind": "port", "port": "left" } },
    { "source": { "kind": "task-ref", "ref": { "id": "<task-uuid>", "name": "read-customers" } }, "target": { "kind": "port", "port": "right" } }
  ]
}
```

Two sources, two distinct targets. Swap `left` and `right` and you get a different result — silently. Joins are where wiring mistakes hide best, so check the sides.

### The empty case

```json
"bindings": []
```

A read task that fetches by `dataset_id` needs nothing handed to it, so an empty array is correct here. On a transformation, the same empty array means its required `input` is missing and the task fails.

> Port names vary by task type (`input`, `inputs`, `left`/`right`, `payload`, `named_inputs`). Check the typed schema rather than copying this verbatim — a binding to a port the task does not have fails the task.

<!-- ds-course-column:2 type=markdown -->

# Step 6 — Wire the data with bindings

`bindings` is how data reaches a task. It is an array on the task record, and each entry connects something that produces a value to an input the task needs.

This is the part people skip, and then wonder why their transformation received nothing.

## The rule that trips everyone up

**Order and data are separate concerns.**

A task finishing before yours does not mean its output arrives at your task. Dependency edges govern sequencing; `bindings` govern dataflow. A task with an empty `bindings` array receives no upstream data — no matter how many tasks ran before it, no matter how obvious the intent looks in the diagram.

It works the other way too: every task you bind from must also be upstream of yours through dependency edges, directly or further back. Bind without the edge and your task may run before its input exists.

The runtime does not guess. If you did not wire it, it is not there.

## What a binding says

Each entry answers three questions:

1. **What input am I filling?** The `target` port on this task.
2. **Where does the value come from?** Usually the output of an upstream task (`task-ref`); sometimes a workflow variable (`variable`).
3. **Which part of it?** The `channel`: `success` (the default) for the normal output, `failure` for the failed rows of a task that failed.

## Name your tasks like you mean it

Bindings point at tasks by `id` and carry the task's `name` alongside. The id does the resolving; the name is what a person reads.

`read-raw-ledger` in a binding tells you exactly what is flowing. `task-3` tells you nothing. Name tasks well on the first pass, before anything references them.

## Debugging a task with no data

When a task behaves as though its input is empty, check in this order:

1. Does it have a `bindings` entry at all? (Most often: no.)
2. Does the source `ref` point at the right upstream task, with a dependency edge to it?
3. Did that upstream task actually run, or was it skipped by its own `condition`?
4. Are you reading the right `channel` — `success` or `failure`?

Four checks, in that order, will find almost every wiring bug.

> Confirm the exact port names with `schema("/config/workflows/<id>/tasks", type: "<your-type>")`. A wrong port name fails the task; a misspelled setting is silently ignored.
