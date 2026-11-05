---
name: commons-workflow
description: Build, run and debug Commons workflows. Workflow settings, task types, bindings, dependencies, triggers, and local prototyping with ds-workflow-manager. Use when creating or editing a workflow or task, wiring a DAG, or when a workflow run fails.
---

# Build a Commons workflow

A workflow is a DAG of tasks (read, transform, write, branch, notify, Python) for operational jobs.
For governed bronze/silver/gold tables use a pipeline (`commons-datalake`).
Config `https://grasp-daas.com/api/config[-dev]/v3`; tools under `/config/workflows`.

## Anatomy

| Part | REST | Tool path |
|---|---|---|
| Workflow | `/workflow/` | `/config/workflows/<id>` |
| Task | `/workflow/task/` | `/config/workflows/<id>/tasks/<id>` |
| Edge | `/map/workflow-task-dependency/` `{workflow_task_id, dependency_id}` | `/config/maps/workflow-task-dependencies` |
| Trigger | `/map/workflow-schedule/`, `/map/workflow-event/` | `/config/maps/workflow-{schedules,events}` |

## Workflow settings

`compute_engine: "pandas"`, `executor` (`lambda` ≤ 15 min | `fargate` long/heavy), `network.mode`
(`public` | `nat` | `static_ip` | `vpn`), `retry {max_attempts, backoff_seconds}`, `timeout`,
`max_concurrent_jobs` (1–100), `variables`, `notify {on_success, on_failure, email[]}`.

## Tasks

Required: `workflow_id`, `name`, `type`, `status`, `condition`, `severity`, `settings`; optional
`bindings`, `dataset_id`, `linked_service_id`. Get exact settings with
`schema {path: "/config/workflows/<id>/tasks", type: "<task type>"}`.

| Category | `ds.workflow.task.` + |
|---|---|
| Input | `functional.input.source` (trigger payload → table) |
| IO | `io.read.dataset`, `io.{create,update,upsert,delete,rename,purge,list}.dataset` |
| Transform | `operational.transformation.{sql-query, query, filter-columns, filter-values, rename, dtypes, derived-columns, assign, map, join, concat, aggregate, series, extract-xml-value}` |
| Code | `operational.execution.python` |
| Analytics | `operational.analytics.collect-errors` |
| Notify | `functional.notification.email` |
| Control | `control.condition.choice`, `control.condition.channel-guard`, `control.wait.sleep` |

`condition`: `always`, `all-done`, `all-success`, `any-success`, `all-failure`, `any-failure`.
`severity`: `critical` fails the run, `minor` does not (use for notifications).

Bindings wire data into ports:

```json
{"source": {"kind": "variable", "name": "payload"}, "target": {"kind": "port", "port": "payload"}}
{"source": {"kind": "task-ref", "channel": "success", "ref": {"id": "<task id>"}},
 "target": {"kind": "port", "port": "inputs", "entry": "input_0"}}
```

`sql-query` reads `settings.query` over `input_0`, `input_1`, …. Port registry:
`ds-workflow-manager/src/common/tasks/tasks.yaml`.

## Example: payload → filter → upsert

1. `INPUT` `functional.input.source`, binding `payload` → port `payload`,
   settings `{"format": "semi-structured-json", "kwargs": {"record_path": "rows"}}`.
2. `FILTER_NO` `operational.transformation.sql-query`, `input_0` ← INPUT,
   `{"query": "SELECT * FROM input_0 WHERE country = 'NO'"}`.
3. `UPSERT` `io.upsert.dataset` with `dataset_id`, port `input` ← FILTER_NO.
4. Edges FILTER_NO → INPUT, UPSERT → FILTER_NO.
5. `run {path: "/config/workflows/<id>", payload: {"rows": [{"id": 1, "country": "NO"}]}}` →
   `status` until done.

## Build loop

1. Prototype locally: `cd ds-workflow-manager && uv sync --all-extras --dev && uv run python -m examples.01_run_pipeline`
   (edit `examples/data/workflow.json`).
2. Create rows in dev (`schema` → `write`), name tasks `CATEGORY::ACTION::TARGET`.
3. Run with a small payload; on failure read the failing task in `status` (`commons-state`).
4. Add schedule or webhook; promote reviewed JSON to prod.

Secrets live in linked services, never in task settings. Contract: `ds-workflow-manager/docs/contract.md`.
