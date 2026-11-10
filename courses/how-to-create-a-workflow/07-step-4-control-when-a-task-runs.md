---
title: Step 4 — Control when a task runs
---
# Step 4 — Control when a task runs

Every task carries a `condition`. It answers one question: *given how the tasks I directly depend on finished, am I allowed to run at all?* It is checked once all of them are done.

This is the field that turns a graph into a workflow with opinions.

## The default is stricter than you think

The common default is `all-success`: run only if everything upstream succeeded. That is the right default — it means failures stop rather than propagate quietly. A task that reads a dataset which failed to load should not run.

But it has a consequence people discover the hard way: **your notification will not fire when the run fails.** If your "email the team" task sits at the end with `all-success`, it runs only on the happy path. The one time you needed to hear about it, silence.

## The fix

Give your notification `always`, or split it in two: a success message on `all-success`, a failure message on `any-failure`. Either works. Silence is what doesn't.

## Skipped is not failed

When a condition is not met, the task is **skipped** — a distinct outcome from failure. This matters when reading a run: a wall of skipped tasks usually means one upstream failure cascaded, and the real problem is the first red task, not the twenty grey ones after it.

That cascade is a feature. It stops a broken run from writing bad data downstream.

## Choosing well

Ask what should happen when the step before this one fails.

- *Nothing should continue* → `all-success`
- *Someone must be told regardless* → `always`
- *This is the cleanup path* → `any-failure`
- *One good branch is enough* → `any-success`
- *Wait for everything, judge nothing* → `all-done`

> Set `condition` deliberately on every task. Accepting the default everywhere is how workflows end up failing silently at 3am.

<!-- ds-course-column:2 type=markdown -->

## The condition values

| Value | Runs when | Use it for |
| --- | --- | --- |
| `all-success` | Every upstream task succeeded | The default. The happy path |
| `any-success` | At least one upstream succeeded | Fan-in where one good branch is enough |
| `all-done` | Every upstream ran to an end (success, failure or timeout); a skipped one does not count | Barriers — wait for everything, judge nothing |
| `any-failure` | At least one upstream failed | Cleanup, error reports, failure alerts |
| `all-failure` | Every upstream failed | Total-collapse fallbacks |
| `always` | Unconditionally | Notifications, teardown, anything that must not be skipped |

### The pattern worth copying

A notification that tells you the truth either way:

```json
[
  {
    "name": "notify-success",
    "type": "ds.workflow.task.functional.notification.email",
    "condition": "all-success",
    "severity": "minor"
  },
  {
    "name": "notify-failure",
    "type": "ds.workflow.task.functional.notification.email",
    "condition": "any-failure",
    "severity": "minor"
  }
]
```

Two tasks, mutually exclusive conditions. For exactly one to fire, both must depend directly on every task that can fail: `any-failure` only sees direct upstreams, and a task skipped by an earlier failure counts as skipped, not failed.

Note `severity: minor` on both — a mail server having a bad day should not turn a successful data run into a failed one.

> If you only remember one thing: `always` for anything that must be heard, `all-success` for anything that touches data.
