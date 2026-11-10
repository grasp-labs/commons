---
name: Workflow control activities
slug: workflow-control
domain: workflow
description: Branch, gate, and pause workflows with the choice, channel guard, and sleep tasks, and predict which downstream tasks run or are skipped.
when_to_use: A workflow must take different paths based on data, stop a branch when a frame is empty or a write had no failures, wait between steps, or a task was unexpectedly skipped.
prefer_skills: []
related_tools: [ls, cat, write]
examples: [playbook/workflow/examples/workflow-control.json]
---

# Workflow control activities

| Task | `type` (version `1.0.0`) | Input port |
| --- | --- | --- |
| Choice | `ds.workflow.task.control.condition.choice` | `inputs`, map, optional |
| Channel guard | `ds.workflow.task.control.condition.channel-guard` | `input`, single, optional |
| Sleep | `ds.workflow.task.control.wait.sleep` | none |

Bindings and `upstream` edges work as in the `python` playbook.

## How the scheduler decides

A task waits until every `upstream` task is terminal, then:

1. If an upstream task emitted a branch selection (choice) that does not list
   this task, it is skipped.
2. Otherwise its `condition` is checked against upstream statuses.

Skipped means status `skipped` (412, `DS_TASK_CONDITION_NOT_MET_ERROR`).
Skips cascade: `all-success` is false for a skipped upstream, and so is
`all-done`, which only counts `success`, `failure` and `timeout`. A task
that joins branches after a choice needs `any-success` (or `always`).

## Choice

Settings: `expression` (string) and `choices`, a list of
`{type: "rule"|"default", downstream: {id, name}, value}`. The
example `playbook/workflow/examples/workflow-control.json` is a complete
payload.

- The expression runs once in a sandboxed Python evaluator (asteval). It sees
  `inputs`, a dict keyed by binding `entry`. `{{key}}` is shorthand for
  `inputs['key']`. For a DataFrame, `len({{rows}}) > 0` is the row count test.
- Every `rule` whose `value` equals the result is selected (several may
  match). If the result is a list, tuple or set, a rule matches when its
  `value` is a member. A `null` value never matches.
- No rule matched: the `default` choice runs. No default: no downstream runs.
- An evaluation error or an unknown `{{key}}` yields no result and silently
  takes the default branch; the task still succeeds. Test the expression on
  real input before relying on the default.
- Each branch task needs the choice as an `upstream` edge and must appear in a
  choice to run. Any other downstream task of the choice is skipped.
- The choice passes no data (its success content is `null`). Branch tasks bind
  their data from the original producer.
- `value` keeps its JSON type: `true` does not equal `"true"`.

## Channel guard

Settings: `allow_empty` (false). It inspects its bound `input` and:

- skips when the input is `null` (unbound, or the producer channel had no
  content);
- skips when the input has length 0 and `allow_empty` is false;
- otherwise succeeds and passes the input through unchanged as its success
  content.

Patterns:

- Stop a branch when a read returned no rows: guard after the read, bind
  `channel: success`.
- Act only on failed rows: bind a write task's `channel: failure` into the
  guard and give the guard `condition: all-done`. A fully successful write has
  no failure content, so the guard skips; a partial or failed write passes its
  failed rows on (see `workflow-io`).

The guard's own skip cascades like any other, so downstream tasks stop too.

## Sleep

Settings: `seconds` (required, number, not negative). The task blocks for that
long and returns no data. A task `timeout` smaller than `seconds` fails it.
Use it to space calls to a rate-limited API between tasks; retry spacing inside
a dataset task is `interval`/`backoff` on that task instead.

## Common failures

| Symptom | Likely cause |
| --- | --- |
| Default branch always taken | Expression error, unknown `{{key}}`, or `value` type mismatch |
| Nothing ran after the choice | No rule matched and no `default` |
| Join task after branches skipped | Its condition is `all-success` or `all-done`; use `any-success` |
| Extra downstream task skipped | Not named in any choice |
| Guard skips on success | Bound channel had no content or zero rows |
| `seconds is required` / `must be non-negative` | Missing or negative `seconds` |
