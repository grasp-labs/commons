---
title: Step 8 — Run it and read the result
---
## Firing and watching

Fire it by config path:

```text
run("/config/workflows/<workflow-id>")
```

A successful fire returns the materialised job path:

```text
/state/jobs/<job-id>
```

Read it:

```text
cat("/state/jobs/<job-id>")
```

### If it comes back queued

```yaml
status: queued
request_id: 9c1f...
```

The job has not materialised yet. List recent jobs (`ls /state/jobs --long --order_by=-created_at`) and match the `request_id` — do not fire again, or you will have two runs racing each other over the same output.

### The expanded view

```text
info("/config/workflows/<workflow-id>")
```

This returns the workflow with its tasks, recent jobs and linked schedules and events attached, which is usually what you actually want while debugging — the definition and its run history side by side.

### Triage order

| Symptom | Look at |
| --- | --- |
| Run failed | The **first** failed task, not the last |
| Lots of skipped tasks | The failure above them, and their `condition` |
| Task succeeded, output empty | Its `bindings` |
| Run never finished | `timeout` and `executor` on the container |
| Nobody was told | The email task's `condition` — is it `always`? (`settings.notify` sends nothing) |

> `info` on the workflow, `cat` on the job. Between those two you can diagnose almost anything without guessing.

<!-- ds-course-column:2 type=markdown -->

# Step 8 — Run it and read the result

You fire a workflow by hitting the Run-button (save your changes first; it is disabled while there are unsaved edits). If you are working in Postman or through a code editor, you can fire it by running its config path. 
What happens on the back side, is that the platform publishes a run message, materialises a job, and hands back that job's path so it can be watched.

## The config is the input; the payload is optional

**A run uses the parameters configured on the target config.** The only extra is an optional `payload`: JSON you pass at fire time (`run(path, payload: {...})`), or the body of a webhook that triggered the run. Tasks read it as `#/variables/payload`.

That is why `variables` on the container matters so much. If something should change durably between runs, it belongs in the config as a variable. Use `payload` for genuine per-run input, like a date window — and remember a job retry runs without it.

The upside is real: a run without a payload is reproducible by construction. The config *is* the input, so any two such runs of an unchanged config did the same thing.

## Queued is not broken

The job record takes a moment to appear. If you fire a workflow and it reports **queued** with a `request_id` instead of a job path, nothing is wrong — the job simply has not materialised yet. Poll with that `request_id`.

People re-fire at this point and end up with two runs. Wait a beat.

## Reading a finished run

Open the job and read task outcomes in order. Three things to keep straight:

- **Failed** — the task ran and errored.
- **Skipped** — its `condition` was not met, or a choice did not select it. It never ran.
- **Cancelled** — it had `breakpoint` set. It never ran.
- **Succeeded** — it did what it said.

When a run fails, find the **first** failed task. Everything after it is usually skipped as a consequence, and the twenty grey tasks below are noise. One real cause, a long shadow.

If a task succeeded but produced nothing useful, that is a `bindings` problem, not a failure — it ran happily on empty input.

## While you are still building

Set `breakpoint` on a task to stop the run there: it is cancelled unrun, and you read the results of everything before it in the job. It beats inferring what happened from logs after the fact.

> Fire, wait for the job to appear, then read it top to bottom. First failure, then check bindings on anything that succeeded suspiciously fast.
