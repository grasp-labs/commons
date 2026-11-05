---
name: commons-config
description: ds-config, the Commons source of truth. Resources, list and filter conventions, create and update semantics, linked services, datasets, compute blocks, schedules, events, maps, runtime profiles and LLM policy, plus change events. Use when reading or changing any tenant configuration or scheduling a block.
---

# ds-config

`https://grasp-daas.com/api/config[-dev]/v3`. Everything a tenant **is** and **runs**. Each change
publishes `ds.core.config.resource.changed.v1` on Kafka. IAM: `config:<operationId>`
(`config:createWorkflow`, `config:listDataset`).

## Conventions

- List: `?limit=&offset=` → `{data: [...], page: {...}}`. Filters: `name` (contains), `status`,
  `owner_id`, `<field>_in` (comma list), `order_by` (`-modified_at`).
- `POST` creates; `PUT /{id}/` is a **full replace** (send the whole object); most deletes are hard.
- Common fields: `name`, `status` (`active`, `draft`, `closed`, …), `description`, `tags`,
  `metadata`, `owner_id`, `acl`.
- Inactive block **or** inactive trigger = nothing runs.

## Resources

| Area | Endpoints |
|---|---|
| Tenancy | `/tenant/`, `/owner/`, `/contact/` |
| Data | `/linked-service/`, `/dataset/`, `/schema/` (`activate`, `close`, `data`), `/record/`, `/vpn-connection/` |
| Compute | `/clone/`, `/workflow/`, `/workflow/task/`, `/pipeline/`, `/runtime-profile/` |
| Triggers | `/schedule/`, `/event/`, `/map/{clone,workflow,pipeline}-{schedule,event}/`, `/map/workflow-task-dependency/` |
| Queue audit | `/enqueued-job/` |
| AI policy | `/llm/{profile,model,provider,tool,skill,mcp-server,mount,policy-tier,rate-limit-tier,governance-approval}/` |
| Billing, learning | `/billing/*`, `/exam/*` |

Tool paths are plural (`/config/linked-services`, `/config/maps/workflow-schedules`); pipelines,
pipeline maps, runtime profiles, skills and MCP servers are REST only.

## Safe change loop

1. Read first: `cat /config/<type>/<id>` or `GET /<type>/{id}/`.
2. Shape: `schema {path, operation}` (tools) or `<base>/docs/`.
3. Write in dev, then `cat` it back. With REST, `PUT` the full object you read, modified.
4. Promote to prod by re-creating from reviewed JSON, not by hand edits.

## Schedules

```json
POST /schedule/
{"name": "nightly-02", "status": "active", "type": "cron", "cron": "0 2 * * *", "timezone": "Europe/Oslo"}
```

Use `cron` **or** `rate`, never both; optional `start_at`, `end_at`. Map it:
`POST /map/workflow-schedule/` `{"workflow_id": "…", "schedule_id": "…"}` (or `pipeline_id` on
`/map/pipeline-schedule/`, which may carry `settings` to override the load mode, or `clone_id`).
pg_cron enqueues due jobs every minute (deduplicated per block and minute); `ds-core-scheduler`
publishes them, subject to the tenant's rate limits (see `commons-message`). Audit:
`GET /enqueued-job/?cb_type=pipeline`.

## Runtime profiles

`/runtime-profile/` sets `executor`, `memory_mb` and `cpu`; `cpu` must match the memory size.

| Executor | `memory_mb` → `cpu` |
|---|---|
| `lambda` | 256→128, 512→256, 1024→512, 2048→1024, 4096→2048, 8192→4096, 10240→6144 |
| `fargate` | 2048→1024, 4096→2048, 8192→4096, 16384/20480/30720→4096, 61440→8192 |

## Tenant

`/tenant/` carries `service_level_id` (default `free`). The service level decides which
compute-block rate-limit tiers the tenant may choose.

## Events

`/event/` with `type: "webhook"` + `/map/<block>-event/`. See `commons-ingress`.

## Linked services and datasets

Linked service = how to reach a source; credentials are vault references (`commons-vault`). Types:
`aws`, `aic-aws`, `azure-storage-account`, `graphql`, `http`, `microsoft-sql`, `postgresql`, `sftp`,
`soap`, `xledger`, `simployer`, `powerofficego`, `unimicro`, `tripletex`
(`ds.resource.linked-service.<type>`). Dataset = what to read or publish
(`ds.resource.dataset.<type>`, gold = `aic-gold`). Full flow: `commons-datalake`.

## LLM policy

`/llm/profile/` binds a tenant to models, `allowed_tools`, rate limits, approvals and guardrails;
`/llm/profile/{id}/resolve/` shows the effective policy. See `commons-ai-gateway`.

Schemas per type: `ds-config/api/openapi/components/schemas/`; examples: `ds-config/docs/examples/`.
