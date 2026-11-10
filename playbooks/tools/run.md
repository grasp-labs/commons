---
name: run
slug: run
domain: tools
description: Playbook for the run tool, covering firing workflows, clones and pipelines, parameters versus optional runtime payload, asynchronous job handles, and avoiding duplicate fires.
when_to_use: Execute configured work by firing a workflow, clone, or pipeline. The return value is a job handle, not a result.
prefer_skills: []
related_tools: [run, status, cat, info, write, ls]
examples: []
---

`run` fires exactly three config types: `/config/workflows/<uuid>`,
`/config/clones/<uuid>`, `/config/pipelines/<uuid>`. Any other path is a
`validation` error; schedules, events, datasets, linked services, and
schemas get a hint naming the right move.

## The contract

- **Parameters live on the config.** A job runs with the parameters
  stored on its target config. To change durable behaviour: `cat` the
  config, `write` the new parameters, then `run`.
- **`payload` is optional runtime JSON**, forwarded verbatim to the job's
  event. Use it for per-fire input that does not belong in config, never
  as a substitute for editing it. For a pipeline, `payload` is the run
  strategy: `{"strategy_policy": {"load_mode": "snapshot|incremental",
  "publish_mode": "upsert|replace"}}`. An explicit `null` is forwarded as
  a value; omit the key for no runtime input.
- Every fire is P2: the gateway pauses for user approval before
  dispatching.
- Compute is asynchronous. The response carries a `/state/jobs/<id>`
  handle; poll it with `status` (cheap, built for loops), `cat` it for
  the full record, `info` it for the record plus recent sibling runs.

## Rules

- Read before fire: `info /config/workflows/<uuid>` returns tasks, recent
  jobs, and linked schedules/events, enough to judge whether firing is
  sane and what a normal run looks like.
- The cb-job materialises asynchronously. A response saying `queued` with
  `_meta.job_visible: false` is normal: the publish succeeded and the row
  appears shortly. Do not re-fire.
- Schedules are not fireable: `run` the workflow the schedule references
  (`cat /config/schedules/<uuid>` shows which).
- One fire, one job. Duplicate fires create duplicate work downstream. If
  unsure whether a fire landed, run `ls /state/jobs --long
  --order_by=-created_at` and match the `request_id` from `_meta` instead
  of firing again.
- `_meta.job_count > 1` means several jobs share the request_id; the
  response shows the most recent.
