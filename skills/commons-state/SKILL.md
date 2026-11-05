---
name: commons-state
description: ds-state on Commons. Compute-block job status, pipeline stages, run statistics, and tenant key/value state with TTL. Use when following or debugging a run, listing recent jobs, or storing small state such as checkpoints and flags.
---

# ds-state

`https://grasp-daas.com/api/state[-dev]/v1`. IAM: `state:<operationId>`.

## Jobs (read-only)

| Call | Use |
|---|---|
| `GET /cb-job/{id}/` | One run (`job_id` from ds-message or `run`) |
| `GET /cb-job/?config_id_in=&status=&type=&created_at_gte=&order_by=-created_at` | Run history |
| `GET /cb-job/latest/` | Latest run per block |
| `GET /cb-job/statistics/[{type}/]` | Counts and durations |
| `GET /cb-stage/` | Pipeline stages (bronze, silver, gold) per run |

Status: `new` → `requested` → `dispatched` → `queued` → `running` → `completed` | `failed` |
`cancelled`. `type`: `clone`, `pipeline`, `workflow`. Other filters: `request_id`, `session_id`,
`latest_per_config`, `omit` (drop heavy fields).

Tools: `status /state/jobs/<id>`; history `find /state/jobs {owner: <config id>, status: "failed", mtime: "-24h"}`.

## Debug a failed run

1. `status` / `GET /cb-job/{id}/`: read the error and the failing stage or task.
2. Pipelines: `GET /cb-stage/?…` shows which layer failed; check silver SQL and `non_null_columns`.
3. Workflows: the failing task name; `critical` tasks fail the run, `minor` do not.
4. Fix config in dev, run once, compare.

## Key/value state

| Call | Use |
|---|---|
| `POST /state/` | Create: `key`, `value` (string), `data_type`, `status`, `ttl_seconds`, `tags`, `metadata`, `description`, `version`, `acl`, `owner_id` |
| `GET /state/?key_prefix=&tag.<k>=&status=` | List |
| `GET /state/{id or key}/` | Read |
| `PATCH` / `PUT /state/{id}/` | Update / replace |
| `DELETE /state/{id}/` | Delete |
| `POST /search/` `{query, filters, snippets}` | Full-text |

Use namespaced keys (`<app>/<purpose>/<id>`) and `ttl_seconds` for temporary state. Never store
secrets here; use vault. Tools: `ls /state`, `cat /state/<id>`, `grep {path: "/state"}`.
