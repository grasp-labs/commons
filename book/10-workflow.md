# 10. Building a workflow

A **workflow** is a DAG of tasks: read, transform, write, branch, notify, run
Python. Use it for operational jobs (sync A → B, enrich, validate, notify).
Use a **pipeline** (chapter 9) when the goal is a governed bronze/silver/gold table.

## Anatomy

| Part | Stored in Config | Purpose |
|---|---|---|
| Workflow | `/workflow/` | Name + settings (executor, network, retry, timeout, variables, notify) |
| Tasks | `/workflow/task/` | One step each: `type`, `settings`, `bindings`, `condition`, `severity` |
| Dependencies | `/map/workflow-task-dependency/` | Edge: `workflow_task_id` runs after `dependency_id` |
| Triggers | `/map/workflow-schedule/`, `/map/workflow-event/` | When it runs |

At run time ds-message (or the scheduler) compiles these rows into one JSON
graph and `ds-workflow-manager` executes it.

## Task types

| Category | Types (`ds.workflow.task.*`) |
|---|---|
| IO | `io.read.dataset`, `io.create.dataset`, `io.update.dataset`, `io.upsert.dataset`, `io.delete.dataset`, `io.rename.dataset`, `io.purge.dataset`, `io.list.dataset` |
| Transform | `operational.transformation.{sql-query, query, filter-columns, filter-values, rename, dtypes, derived-columns, assign, map, join, concat, aggregate, series, extract-xml-value}` |
| Execution | `operational.execution.python` |
| Analytics | `operational.analytics.collect-errors` |
| Input | `functional.input.source` (turns the trigger payload into a table) |
| Notify | `functional.notification.email` |
| Control | `control.condition.choice`, `control.condition.channel-guard`, `control.wait.sleep` |

Ports per task: call the `schema` tool.

**Condition** (when a task runs given upstream results): `always`, `all-done`,
`all-success`, `any-success`, `all-failure`, `any-failure`.
**Severity**: `critical` (failure fails the run) or `minor`.

**Bindings** wire data into ports:

```json
{"source": {"kind": "task-ref", "channel": "success", "ref": {"id": "<task id>"}},
 "target": {"kind": "port", "port": "inputs", "entry": "input_0"}}
```

Sources: `variable` (e.g. `payload`), `task-ref` (output of another task).

## Build one: payload → SQL filter → write

Goal: accept rows in the trigger payload, keep Norwegian ones, upsert into a dataset.

```bash
CFG=https://grasp-daas.com/api/config-dev/v3
H=(-H "Authorization: Bearer $JWT" -H "Content-Type: application/json")
```

**1. Workflow**

```bash
curl -s -X POST "$CFG/workflow/" "${H[@]}" -d '{
  "name": "orders-no", "status": "active",
  "settings": {
    "compute_engine": "pandas", "executor": "lambda",
    "network": {"mode": "public"},
    "retry": {"max_attempts": 2, "backoff_seconds": 30},
    "notify": {"on_failure": true, "email": ["you@company.com"]},
    "variables": {}
  }}'
```

**2. Tasks**

```bash
# input
curl -s -X POST "$CFG/workflow/task/" "${H[@]}" -d '{
  "workflow_id": "<wf>", "name": "INPUT", "status": "active",
  "type": "ds.workflow.task.functional.input.source",
  "condition": "always", "severity": "critical",
  "bindings": [{"source": {"kind": "variable", "name": "payload"},
                "target": {"kind": "port", "port": "payload"}}],
  "settings": {"format": "semi-structured-json", "kwargs": {"record_path": "rows"}}}'

# filter
curl -s -X POST "$CFG/workflow/task/" "${H[@]}" -d '{
  "workflow_id": "<wf>", "name": "FILTER_NO", "status": "active",
  "type": "ds.workflow.task.operational.transformation.sql-query",
  "condition": "all-success", "severity": "critical",
  "bindings": [{"source": {"kind": "task-ref", "channel": "success", "ref": {"id": "<input task>"}},
                "target": {"kind": "port", "port": "inputs", "entry": "input_0"}}],
  "settings": {"query": "SELECT * FROM input_0 WHERE country = '\''NO'\''"}}'

# write
curl -s -X POST "$CFG/workflow/task/" "${H[@]}" -d '{
  "workflow_id": "<wf>", "name": "UPSERT", "status": "active",
  "type": "ds.workflow.task.io.upsert.dataset", "dataset_id": "<target dataset>",
  "condition": "all-success", "severity": "critical",
  "bindings": [{"source": {"kind": "task-ref", "channel": "success", "ref": {"id": "<filter task>"}},
                "target": {"kind": "port", "port": "input"}}],
  "settings": {}}'
```

**3. Dependencies**

```bash
curl -s -X POST "$CFG/map/workflow-task-dependency/" "${H[@]}" \
  -d '{"workflow_task_id": "<filter task>", "dependency_id": "<input task>"}'
curl -s -X POST "$CFG/map/workflow-task-dependency/" "${H[@]}" \
  -d '{"workflow_task_id": "<upsert task>", "dependency_id": "<filter task>"}'
```

**4. Run**

```bash
curl -s -X POST "https://grasp-daas.com/api/message-dev/v1/message/ds.workflow.pipeline.job.requested.v2/" "${H[@]}" \
  -d '{"id": "<wf>", "payload": {"rows": [{"id": 1, "country": "NO"}, {"id": 2, "country": "SE"}]}}'
```

**5. Watch**: ds-state `/cb-job/latest/`, or the `status` tool.

Add a schedule or webhook later (chapter 6). The workflow does not change.

## Run locally (no cloud)

```bash
cd ds-workflow-manager
uv sync --all-extras --dev
uv run python -m examples.01_run_pipeline     # runs examples/data/workflow.json
```

Edit `examples/data/workflow.json` to prototype a graph before writing Config rows.

## Settings reference

| Setting | Values |
|---|---|
| `executor` | `lambda` (short, ≤15 min) or `fargate` (long, heavy) |
| `network.mode` | `public`, `nat`, `static_ip` (allow-listed egress), `vpn` (on-prem) |
| `max_concurrent_jobs` | 1–100 (default 1) |
| `retry` | `max_attempts`, `backoff_seconds` |
| `timeout` | seconds |
| `variables` | Values available to tasks (e.g. `orgnr`) |
| `notify` | `on_success`, `on_failure`, `email[]` |

## Tips

- Prototype locally, then create rows in dev, then promote.
- Name tasks `CATEGORY::ACTION::TARGET`; it makes runs readable.
- Use `minor` severity for optional side effects (notifications).
- Keep secrets in linked services; tasks reference datasets, not credentials.
