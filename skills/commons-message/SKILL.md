---
name: commons-message
description: ds-message, the on-demand trigger on Commons. Run a workflow, pipeline or clone now with an optional payload, pick the right topic, and track the resulting job. Use when the user wants to start, re-run or test a compute block.
---

# ds-message

`https://grasp-daas.com/api/message[-dev]/v1`. Loads the block with IAM-scoped SQL, snapshots its
full config, publishes a run request to Kafka and returns the job id.

## Run

```bash
MSG=https://grasp-daas.com/api/message-dev/v1
curl -s -X POST "$MSG/message/<topic>/" -H "Authorization: Bearer $COMMONS_JWT" \
  -H "Content-Type: application/json" -d '{"id": "<block uuid>", "payload": {...}}'
# → {"request_id", "job_id", "session_id", "topic", "job_type"}
```

| Block | Topic | `payload` |
|---|---|---|
| Workflow | `ds.workflow.pipeline.job.requested.v2` | Any JSON; tasks read it as variable `payload` |
| Pipeline | `ds.pipeline..job.requested.v2` | Optional `{"strategy_policy": {"load_mode": "snapshot"\|"incremental", "publish_mode": "upsert"\|"replace"}}` |
| Clone | `ds.clone..job.requested.v1` | Any JSON |

`GET /topics/` lists topics; trust it over this table. Send `id` (`workflow_id`/`clone_id` are
deprecated aliases). IAM: `message:createMessage` plus read on the block (`config:getWorkflow`, …).

With tools: `run {path: "/config/workflows/<id>", payload}` (also clones). For pipelines use REST:
the `run` tool sends `pipeline_id`, which ds-message does not accept.

## Track

`GET https://grasp-daas.com/api/state[-dev]/v1/cb-job/{job_id}/` or `status /state/jobs/<job_id>`.
Poll with backoff until `completed`, `failed` or `cancelled`. Pipelines also report stages in
`/cb-stage/`. See `commons-state`.

## Rules

- `run` changes data downstream: dev first; say block, env and payload before approval.
- One run, then check status; never loop runs to "retry" without reading the failure.

## Rate limits

ds-message, schedules and ds-ingress all enforce one per-tenant pool: the tenant's tier caps runs
at once, starts per minute and per day, and queue depth (`starter` 50 / 100 / 20,000 / 1,000;
`pro`, `enterprise`, `unlimited` go higher). Over a limit, the run waits in the queue; when the
queue is full it is rejected or deferred. Optional allocations give a block or block type a
`priority` (who goes first) and reserved runs (guaranteed slots). The platform team sets
these; there is no API yet. A queued run is not a failure, so don't trigger it again.
