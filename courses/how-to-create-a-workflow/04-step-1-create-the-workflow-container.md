---
title: Step 1 — Create the workflow container
---
# Step 1 — Create the workflow container

Start with the container, always. Tasks belong to a workflow, so the workflow has to exist before there is anywhere to put them.

## Give it a real name

Name it after the outcome, not the mechanism. `Analyze customer A` tells the next person what it is for. `workflow-2` tells them nothing, and they will open all six of your workflows looking for the right one.

## Choose the executor honestly

This is the setting people get wrong most often.

- **`lambda`** — fast to start, tight ceilings on time (`timeout` at most 900 seconds) and memory. Right for most small-to-medium jobs.
- **`fargate`** — slower to start, far more headroom. Right when you are moving real volume or running something genuinely slow.

If you are unsure, start on `lambda`. Move to `fargate` when you actually hit a wall, not in anticipation of one.

## Set the timeout deliberately

A timeout is not a limit on how long you are *willing* to wait. It is a promise that a hung run will eventually stop instead of holding resources forever. Set it comfortably above your realistic worst case — and never so wide that a stuck run goes unnoticed until morning.

## Use variables from the start

Anything that appears in more than one task belongs in `variables`: dataset names, environments, thresholds, recipient lists. Change it once and every task follows. Hard-code it and you will miss one.

## Retry is not a fix

`retry` exists for *transient* failure — a network blip, a service briefly unavailable. It re-runs the whole job, not one task, and the retry starts immediately without the original run `payload`. It does nothing for a logic error except make it fail several times more slowly. If a task fails deterministically, retries only delay the bad news.

> Set the container up properly and most "mysterious" workflow problems never happen. Rush it and you will debug infrastructure while convinced you have a data bug.

<!-- ds-course-column:2 type=markdown -->

## The container, in JSON

```json
{
  "name": "Analyze customer A",
  "description": "Read ledger data from the ERP, analyze it with an AI model, then send the report on email",
  "status": "active",
  "settings": {
    "compute_engine": "pandas",
    "executor": "lambda",
    "network": { "mode": "public" },
    "retry": { "max_attempts": 2, "backoff_seconds": 0 },
    "timeout": 900,
    "notify": { "email": [], "on_success": false, "on_failure": false },
    "variables": {
      "source": "raw_ledger",
      "target": "ledger_analyzed",
      "min_rows": 1
    }
  }
}
```

### Reading it back

| Field | Why it is set this way |
| --- | --- |
| `compute_engine` | `pandas` — a dataframe engine, fine for anything that fits in memory |
| `executor` | `lambda` — this job is small and quick |
| `network` | `public` — required; `fargate` would need `nat` or `static_ip` |
| `retry` | `2` extra job attempts — enough to survive a blip, few enough to fail fast |
| `timeout` | `900` — the `lambda` maximum, a ceiling, not an expectation |
| `notify` | Required, but its emails are never sent today. Put an email task in the graph instead |
| `variables` | Names referenced by tasks instead of repeated inside them |

> Confirm the exact field names against the live schema before you save — `schema("/config/workflows")` is the authority, and it is cheaper to check than to debug.
