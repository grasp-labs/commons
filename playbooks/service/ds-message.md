---
name: "ds-message: on-demand triggers"
slug: ds-message
domain: service
description: "How an on-demand run is triggered through ds-message: topic choice, config snapshot at publish time, payload rules, two-grant authorization, job correlation, and why publishes are not idempotent."
when_to_use: "Firing a workflow, clone, or pipeline on demand, diagnosing a failed or duplicate fire, or calling the message API directly instead of the run tool."
prefer_skills: []
related_tools: [run, status, cat, info, ls, write]
examples: []
---

ds-message turns "run this compute block now" into an event for the
workers. From a tool session, fire with `run` (see the `run` playbook);
it reads the config, picks the topic, and publishes here. Call the API
directly only when no tool session exists:
`POST /api/message/v1/message/<topic>/` with
`{"id": "<block uuid>", "payload": <optional JSON>}`.

## Topics

The catalog is compiled into the service (`GET /api/message/v1/topics/`
lists the ones you may publish to):

| Topic | Block |
| --- | --- |
| `ds.workflow.pipeline.job.requested.v1` | workflow |
| `ds.workflow.pipeline.job.requested.v2` | workflow |
| `ds.clone..job.requested.v1` | clone |
| `ds.pipeline..job.requested.v2` | pipeline |

The block's own `topic_id` field decides which topic it is fired on.
`run` reads it from the config and fails with "config record has no
topic_id" when it is empty: set it with `write` first. The topic name
decides how `id` is read, so a workflow id sent to the clone topic is a
404, not a clone run.

## What gets published

- **A snapshot, read at publish time.** ds-message reads the whole block
  from config (workflow with its task graph, datasets and linked
  services; clone with source and target; pipeline with datasets and
  runtime profiles) and ships it as the event `context`. Edit the config,
  then fire. Edits made after a fire do not change that run.
- **`payload` is opaque runtime input**, any valid JSON, forwarded as the
  event `payload`. Omit it for none; an omitted payload leaves the
  attribute off the event.
- **Pipeline topic only:** a payload, when sent, must be
  `{"strategy_policy": {"load_mode": "snapshot|incremental",
  "publish_mode": "upsert|replace"}}`. Anything else is a 422 naming the
  field.
- The event's `session_id` is the caller's `X-Session-ID` (a new one when
  absent); `owner_id` comes from the block.

## Authorization: two grants

1. `message:createMessage` on the topic. Missing: **403**.
2. `config:getWorkflow` / `config:getClone` / `config:getPipeline` on the
   block, applied as the read's filter. Missing: **404**.

A 404 therefore means "not visible to you" as often as "does not exist".
Confirm with `cat /config/workflows/<uuid>` under the same identity before
concluding the block is gone. Revoking the config read revokes firing.

## Responses

| Status | Meaning | Action |
| --- | --- | --- |
| 200 | Published | Track the job (below) |
| 422 on `id` | No block id in the body | Send `id` |
| 422 on `payload...` | Invalid JSON or bad pipeline strategy | Fix payload |
| 403 / 404 | Grant missing (see above) | Ask for the grant |
| 429 | Service overloaded | Wait `Retry-After` |
| 502 | Broker refused the event | Check jobs before retrying |
| 503 | IAM unreachable | Wait `Retry-After` |

The body carries `request_id`, `job_id`, `session_id`, `topic` and
`job_type`. The worker materialises the job asynchronously, so a job may
not be visible yet. Correlate it by `request_id`: `run` does this and
reports `queued` with `_meta.job_visible: false` until the job appears.
Poll with `status /state/jobs/<uuid>`.

## Idempotency: there is none

Every publish mints a new event id. There is no dedup key, no
idempotency header, and no "already running" check here. Two calls are
two runs.

- Never re-fire because a job is not visible yet or a call timed out.
  First `ls /state/jobs --long --order_by=-created_at` and match
  `request_id`, or `ls /state/jobs/<config-uuid>` for that block.
- A 502 or a client timeout leaves the outcome unknown. Look before you
  retry.
- If downstream writes must not repeat, make the workflow itself
  idempotent (upsert, keyed writes). The trigger will not protect you.

## Pitfalls

- `workflow_id` and `clone_id` are deprecated aliases for `id`. Send `id`.
- Schedules and events are not fired here. A schedule fires its workflow
  on its own. Webhooks arrive through ds-ingress (see the `ds-ingress`
  playbook).
- Under the default governance tiers, `run` is P2: the user confirms
  before the publish happens.
