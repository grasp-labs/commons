---
name: Python script workflow activity
slug: python
domain: workflow
description: Configure the sandboxed Python script workflow task, its main(**kwargs) contract, settings, and DataFrame bindings.
when_to_use: A workflow step needs custom Python or multi-step pandas logic that no built-in transform task (filter, SQL query, and so on) covers.
prefer_skills: []
related_tools: []
examples: [playbook/workflow/examples/python-activity.json]
---

# Python script workflow activity

Prefer a built-in transform when one task already fits. Use this task for
custom DataFrame logic that needs arbitrary Python.

| Field | Value |
| --- | --- |
| `type` | `ds.workflow.task.operational.execution.python` |
| `version` | `1.0.0` (a leading `v` is accepted) |
| Input port | `inputs`, kind `map`, optional (0..n DataFrames) |
| Output | One `pd.DataFrame` on the success channel |

The example `playbook/workflow/examples/python-activity.json` is a complete
ds-config `POST /workflow/task/` payload with one upstream DataFrame bound.

## Script contract

```python
import pandas as pd

def main(**kwargs) -> pd.DataFrame:
    clients = kwargs["clients"]  # key = binding target.entry
    return clients
```

1. Define a callable `main`; it receives every bound input as a keyword
   argument named by the binding's `target.entry`, not the upstream task name.
2. Return a `pd.DataFrame`. Anything else fails with `TypeError`.
3. Import everything you use. Nothing is pre-injected.
4. Use `kind: "inline"` with `content`. `kind: "ref"` deserializes but raises
   `NotImplementedError` at run time.
5. Put newlines in `content` as `\n` in JSON.

## Sandbox limits

The script runs in a subprocess with three restrictions:

- Environment: only `PATH`, `HOME`, locale, Python path, library path, and
  `VIRTUAL_ENV` variables are forwarded. No credentials.
- Network: `socket.socket` and `socket.create_connection` raise
  `PermissionError`. `requests`, `boto3`, and `sqlalchemy` import but cannot
  connect. Fetch data with upstream tasks instead.
- Builtins: RestrictedPython `safe_builtins` plus `abs`, `all`, `any`, `bool`,
  `dict`, `enumerate`, `filter`, `float`, `int`, `len`, `list`, `map`, `max`,
  `min`, `range`, `reversed`, `round`, `set`, `sorted`, `str`, `sum`,
  `tuple`, `zip`, `super`, and `__import__`. Not available: `print`, `open`,
  `eval`, `exec`, `compile`, `getattr`, `hasattr`, `type`, `iter`, `next`,
  `format`, `object`. Using one raises `NameError`.

Stdout is discarded. On failure, at most the last 8192 bytes of stderr are
surfaced.

## Settings

```json
{"source": {"kind": "inline", "content": "..."}, "timeout": 60, "variables": {}}
```

`timeout` is the subprocess limit in seconds; `null` sets none at task level.

## Wiring inputs

Data and control flow are separate.

- `bindings` move data. Bind a producer's result into the `inputs` map:
  `source: {kind: "task-ref", ref: {id, name}, channel: "success"|"failure"}`,
  `target: {kind: "port", port: "inputs", entry: "<kwarg name>"}`.
  Every map binding needs a unique `entry`.
- Every value in `inputs` must be a DataFrame. A `variable` source bound into
  `inputs` fails input validation; use task settings for scalars.
- `upstream` controls scheduling only. A task with empty `upstream` is ready
  immediately, and a task-ref producer must be a transitive `upstream`
  ancestor of the consumer. Always add the edge for every bound producer.
- In ds-config, edges are rows in `/map/workflow-task-dependency/`
  (`workflow_task_id` waits on `dependency_id`).
- `condition`: `always`, `all-done`, `all-success`, `any-success`,
  `all-failure`, `any-failure`. `severity`: `critical` or `minor`.

## Common failures

| Symptom | Likely cause |
| --- | --- |
| `Script must define a callable named 'main'.` | `main` missing or misnamed |
| `main() must return a pandas.DataFrame` | Wrong return type |
| `KeyError` in the script | `entry` does not match the `kwargs` key |
| `NameError` on a builtin | Builtin not in the sandbox allowlist |
| `PermissionError` | Network use inside the script |
| `Input dict values must be pandas DataFrame instances` | Non-DataFrame bound into `inputs` |
| `Script references (RefPythonScript) are not yet supported` | `kind: "ref"` |
| Task runs before its input exists | Missing `upstream` edge |
| Deserialization error | Unknown `type`/`version` or bad settings shape |

## Source

`ds-workflow-manager`: `src/common/tasks/operational/execution/python.py`,
`_sandbox.py`, `src/common/tasks/tasks.yaml`, `docs/task-contract.md`.
