---
name: Workflow compute block
slug: workflow
domain: block
description: Author and run a workflow end to end - workflow, tasks, dependency edges, bindings, variables, triggers, retries, and job status.
when_to_use: Use when building, wiring, triggering or debugging a workflow (a DAG of tasks over datasets), or deciding how a workflow should start and pass runtime values.
prefer_skills: []
related_tools: [write, run, status, info, ls, cat, find]
examples: [playbook/block/examples/workflow.json]
---
# Workflow compute block

A workflow is a DAG of tasks run as one job by the workflow manager. The full write sequence is in `playbook/block/examples/workflow.json`.

## Authoring order

1. `write /config/workflows` with `name`, `status`, `settings`. Required settings: `timeout` (≥1; max 900 on `lambda`, 86400 on `fargate`), `notify`, `compute_engine: pandas`, `executor` (`lambda`|`fargate`), `network.mode` (`public`|`nat`|`vpn`|`static_ip`; `fargate` only `nat`|`static_ip`), `variables` (object). Optional `retry` {`max_attempts`, `backoff_seconds`}, `max_concurrent_jobs` 1-100 (default 1).
2. `write /config/workflows/<uuid>/tasks` per task: `name`, `status`, `type`, `version` (`1.0.0`), `settings`, `condition`, `severity`, `bindings`, plus `dataset_id` for IO tasks.
3. `write /config/maps/workflow-task-dependencies` per edge: `workflow_task_id` waits on `dependency_id`.
4. `info /config/workflows/<uuid>` to review it before the first `run`.

Config does not check `type`, `version` or task `settings`; an unknown `(type, version)` or bad settings fails the whole job at start, before any task runs.

## Task catalogue (by playbook)

`workflow-python`; `workflow-io` (dataset read/write/list/purge); `workflow-control` (choice, channel-guard, sleep); `workflow-columns`, `workflow-rows`, `workflow-combine` (transforms); `workflow-functional` (input source, email, collect-errors). Sources: the `protocol-*` and `provider-*` playbooks.

## Wiring

- Edges control *when*; `bindings` control *what data*. Nothing flows along an edge by itself. A `task-ref` producer must be a transitive upstream ancestor of its consumer.
- Binding: `source {kind: task-ref, ref {id, name}, channel: success|failure}` or `source {kind: variable, name}`; `target {kind: port, port, entry?}`. `entry` is required for map ports and unique per port. A single port takes one binding; list ports append in binding order.
- Port names come from the task registry (`input`, `inputs`, `left`/`right`, `payload`, `named_inputs`).
- `condition` is evaluated once every direct upstream is terminal: `all-success` (default), `any-success`, `all-failure`, `any-failure`, `all-done`, `always`. Not met → `skipped`, which fails `all-success` joins downstream.
- `severity`: the job fails if any `critical` task fails; `minor` failures are tolerated. Route a failure branch with `channel: failure` and `any-failure`.
- `breakpoint: true` cancels the task unrun.

## Variables and runtime values

- Whole-string placeholders in task settings: `#/variables/<name>` (workflow `settings.variables`), `#/variables/<name>/$.a.0.b` (projection), `@{fn, args}` builtins (e.g. `@{get_start_date_last_month}`), `@{get_secret, /ds/vault/...}`.
- Built-ins: `run_id`, `session_id`, `tenant_id`, `pipeline_id`, and `payload` (the trigger body: `run` payload or webhook body).
- Dataset incremental checkpoints are not persisted between runs: datasets have no checkpoint field and the workflow manager never loads or saves one, so every read starts fresh. Drive windows with variables in IO task `settings.overrides`, e.g. `"from": "#/variables/from"` or `"#/variables/payload/$.from"`.

## Triggers

- `run /config/workflows/<uuid>` (optional `payload`): manual, one job per fire.
- Schedule: `write /config/schedules` with exactly one of `cron` (5-field) or `rate` (`rate(1 hour|day|week|month|year)`), then `write /config/maps/workflow-schedules` {`workflow_id`, `schedule_id`}. Only `active` workflows and schedules fire; cron is matched in UTC and `timezone`, `start_at`, `end_at` do not gate dispatch.
- Event/ingress: `write /config/events` (`type: webhook`) plus `/config/maps/workflow-events`. A signed POST to the event's ingress webhook fires every mapped workflow with the body as `payload`.

## Execution and status

- The dispatcher queues per workflow and runs at most `max_concurrent_jobs` at once; extra fires wait in `queued`.
- `retry.max_attempts` = extra attempts after a failed job, each a new job with the same `request_id`. They start immediately (`backoff_seconds` is ignored) and without the original `payload`.
- `settings.timeout` bounds the job; a task `settings.timeout` bounds one task.
- Track with `status /state/jobs/<id>`; `cat` it for per-task results and `details.errors`.

## Pitfalls

| Symptom | Cause |
| --- | --- |
| Task ran before its input existed / input `None` | Missing dependency row for a bound producer |
| `Pipeline scheduling made no progress` | Dependency cycle |
| Edge silently ignored | Dependency points at a task of another workflow |
| Failure email never arrives | Config stores `notify.email`, the manager reads `notify.emails`; use an email task |
| Schedule never fires | Workflow or schedule not `active`, or cron written for local time |
