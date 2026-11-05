# 6. Triggers

A trigger turns "run this block" into a Kafka request event. There are three.

| Trigger | Service | Stored as | Typical use |
|---|---|---|---|
| **Manual** | `ds-message` | nothing (direct publish) | Ad-hoc runs, the `run` tool, UI buttons |
| **Schedule** | pg_cron → `enqueued_job` → `ds-core-scheduler` | `schedule` + `map_<block>_schedule` | Nightly loads, recurring checks |
| **Event / webhook** | `ds-ingress` | `event` (type `webhook`) + `map_<block>_event` | Source system pushes a change |

`enqueued_job.trigger_type` is one of `manual`, `schedule`, `event`.

## Manual

```bash
curl -X POST "$MESSAGE/message/ds.workflow.pipeline.job.requested.v2/" \
  -H "Authorization: Bearer $JWT" -H "Content-Type: application/json" \
  -d '{"id":"<workflow_id>","payload":{"rows":[{"a":1}]}}'
```

ds-message loads the block with IAM-scoped SQL, builds the full snapshot,
sets `context.type = "manual"` and publishes. Response contains `job_id` —
poll it in ds-state. `payload` reaches the workflow as the `payload` variable.

## Schedule

1. Create the schedule (`cron` **or** `rate`, never both):

   ```json
   POST /schedule/
   {"name":"nightly-02","status":"active","type":"cron","cron":"0 2 * * *","timezone":"Europe/Oslo"}
   ```

2. Map it to a block: `POST /map/pipeline-schedule/` `{"pipeline_id":"…","schedule_id":"…"}`
   (or `/map/workflow-schedule/`, `/map/clone-schedule/`). Pipeline maps may carry
   `settings` to override the load mode per schedule.

3. Every minute pg_cron calls `dispatch_{clone,workflow,pipeline}_schedules()`.
   Due, active schedules on active blocks insert one `enqueued_job`
   (deduplicated on `(cb_id, scheduled_minute)`).

4. `ds-core-scheduler` picks `queued` rows, marks them `running` and publishes to
   the row's topic. It never marks success; the worker outcome does.

Audit: `GET /enqueued-job/?cb_type=pipeline`. `start_at`/`end_at` travel with
the job; consumers enforce them, not the dispatcher.

## Event / webhook

1. Store the provider's signing secret in ds-vault.
2. Create the event:

   ```json
   POST /event/
   {
     "name": "tripletex-accounts",
     "type": "webhook",
     "status": "active",
     "settings": {
       "type": "webhook",
       "provider": "tripletex",
       "validate_payload": true,
       "vault_ref": "<vault key>",
       "vault_id": "<vault secret id>"
     }
   }
   ```

   Providers with built-in verification: `xledger`, `tripletex`, `hubspot_v1..v3`,
   `jobbnorge`, `visma_bnxt`, `api_key`.
3. Map it: `POST /map/workflow-event/` (or pipeline / clone).
4. Point the source system at `POST https://grasp-daas.com/api/ingress/v1/webhook/<event_id>/`.
5. ds-ingress verifies the signature and publishes a request for every block mapped to the event.

Pipelines triggered by webhook run in **webhook mode**: bronze is skipped and the
pushed payload goes straight to silver → gold.

## Following a run

| Where | What |
|---|---|
| `GET /api/state/v1/cb-job/?…` / `cb-job/latest/` | Status per run |
| `GET /api/state/v1/cb-stage/` | Pipeline stage status |
| `status` tool | Same, from chat or MCP |
| Kafka `*.job.completed` / `*.failed` | Outcome events |

## Rate limits

All three triggers enforce the tenant's compute-block rate limits before a run starts, so the
same limits apply whether a run comes from `ds-message`, a schedule or `ds-ingress`.

**Tier.** Each tenant has one tier, a pool shared by every clone, pipeline, workflow and agent
it runs. Without a choice it runs on `starter`. A tenant may pick any tier at or below its
service level (`tenant.service_level_id`, `free` by default). A limit of 0 means no limit.

| Tier | Runs at once | Starts/min | Starts/day | Queue | Burst | Weight |
|---|---|---|---|---|---|---|
| `starter` | 50 | 100 | 20,000 | 1,000 | 1× | 1 |
| `pro` | 200 | 500 | 200,000 | 10,000 | 1.25× | 2 |
| `enterprise` | 1,000 | 2,000 | none | 50,000 | 1.5× | 4 |
| `unlimited` | none | none | none | none | 1× | 8 |

Burst lets a quiet tenant briefly exceed starts per minute. Weight is the tenant's share
when the platform is busy.

**Allocations** (optional) share the pool inside a tenant, per block type or per block (the
block's own allocation wins):

- `priority`: higher starts first when runs wait; ties go oldest first. Default 0.
- `reserved runs`: slots from "runs at once" that only this block or type may use. The total
  can't exceed the tier's runs at once.

Priority picks who is next; only reserved runs guarantee a free slot. Example: "pipelines
never wait on agents" means pipelines get priority 10 and 2 reserved runs.

Over a limit, the run waits in the tenant's queue. When the queue is full, new runs are
rejected or deferred. Tier and allocation changes take up to 5 minutes to apply. Counters
are per tenant, so changing tier does not reset them. Tiers, pools and allocations are
set by the platform team (`cb_rate_limit_tier`, `cb_rate_limit`, `cb_rate_limit_allocation`).
They have no API yet.

## Gotchas

- Inactive schedule **or** inactive block = nothing runs.
- A run that hasn't started may be queued by rate limits. Triggering it again adds another run
  to the queue.
- Workflow topics are `v2`; old docs mentioning `ds.workflow..job.requested.v1` are stale.
