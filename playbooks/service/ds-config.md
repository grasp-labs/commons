---
name: "ds-config: configuration"
slug: ds-config
domain: service
description: "Author and change AI Commons configuration under /config safely: resource types, references between them, create order, delete order and conflicts, and secrets as vault references."
when_to_use: "Use when creating, wiring, changing or deleting workflows, tasks, datasets, linked services, schedules, events, clones, pipelines, maps, LLM profiles/skills or billing records, or when a /config write or rm fails with conflict, validation or upstream."
prefer_skills: []
related_tools: [ls, find, cat, info, schema, write, rm, run]
examples: []
---
Configuration is the tenant's declarative control plane, at `/config/<type>[/<uuid>]`. `ls /config` lists the types:

- **Data and compute:** `linked-services`, `datasets`, `workflows` (tasks at `/config/workflows/<uuid>/tasks`), `schedules`, `events`, `schemas`, `clones`, `pipelines`, `runtime-profiles`, `vpn-connections`, `owners`.
- **Wiring:** `maps/<type>` join rows: `workflow-schedules`, `workflow-events`, `workflow-task-dependencies`, `clone-schedules`, `clone-events`, `pipeline-schedules`, `pipeline-events`, `pipeline-owners`.
- **AI:** `llm/<type>`: `profiles` (plus a read-only `/resolved` view), `models`, `providers`, `tools`, `skills`, `mcp-servers`, `mounts`, `policy-tiers`, `rate-limit-tiers`, `catalogue`.
- **Money:** `billing/<type>`. Writes there pause for asynchronous sign-off (see the `write` playbook).

## Reference graph

Rows point at each other by UUID. A dataset points at its `linked_service_id`; a task at `workflow_id` and optionally `dataset_id`/`linked_service_id`; a clone at `source_id`/`target_id` datasets; an event at `schema_id`; a map at the two rows it joins. Most rows also take an optional `owner_id`.

A workflow does nothing on a timer or event until a map row joins it to a schedule or event. Task order is `maps/workflow-task-dependencies` (`workflow_task_id` depends on `dependency_id`). The task's `condition` (`always`, `all-done`, `all-success`, `any-success`, `all-failure`, `any-failure`) decides whether it runs given its dependencies. `severity` is `minor` or `critical`.

## Create order

Build leaves first and carry each returned `id` forward: owner (optional), linked service, dataset, workflow, tasks, dependency maps, schedule or event, then the schedule/event map.

Call `schema(path)` before each new type: dataset and linked-service settings are provider-specific (see the protocol and provider playbooks). Writing `/config/workflows/<uuid>/tasks` fills in `workflow_id` for you.

A missing reference is a `validation` error naming the field, e.g. `owner_id does not reference an existing record` (422) or `linked service does not exist` (400).

## Uniqueness (409 `conflict`)

- LLM profile `name` per tenant.
- Skill `slug` per issuer.
- MCP server `slug` per tenant (deleted rows excluded).
- One `aic-aws` linked service per tenant.
- Schema `name` is unique across the whole platform, not per tenant: a clash may be another tenant's schema. Pick a distinctive name.

## Changing

`write` on `/config/...` is GET, merge, PUT: concurrent edits to one row can overwrite each other. `replace=true` clears unmentioned fields.

Platform-published rows (shared catalogue entries) are readable by every tenant. Only the platform can change them: a write or `rm` on one is `not_found`, not `forbidden`. To customise one, create your own copy.

## Deleting

Delete dependents before what they point at. There is no cascade except where noted:

| Delete | Effect |
| --- | --- |
| workflow | Also removes its tasks, their dependency maps, and its schedule/event maps, in one transaction. |
| clone | Also removes its schedule/event maps. |
| pipeline | Its schedule maps cascade. |
| linked service | Refused with `conflict` (409) while any dataset uses it. |
| owner | Refused with `conflict` while datasets, linked services or billing records use it. Config and map rows are detached (`owner_id` set to null). |
| dataset, schedule, event, schema, task | No pre-check. A still-referenced row is refused by the database, but this currently surfaces as `upstream`/`internal` (500), not `conflict`. |

Before deleting a dataset, schedule, event or task, find its referrers yourself with `ls`/`cat` and check the id fields:

- tasks (`ls /config/workflows/<uuid>/tasks`, `dataset_id`)
- clones (`source_id`/`target_id`) and pipelines
- `maps/*` rows carrying the schedule's or event's id
- dependency maps on the task

Treat a 500 on such an `rm` as "still referenced", not as an outage. Deleting a whole workflow is the clean way to drop its tasks.

## Secrets

Never put plaintext credentials in config. There are two forms, and they are not interchangeable:

- **Placeholder** in linked-service and dataset string settings: `@{get_secret, <key>}`, substituted at run time. Schema-marked credential fields require this form.
- **Bare key** in event `settings.vault_ref` (required unless the provider is `oauth`) and MCP server `credential_ref`.

`<key>` is the secret's `key` field, not its name. See the `ds-vault` playbook. Config does not check that a key resolves; a wrong one fails only when the work runs, which you start with `run`.
