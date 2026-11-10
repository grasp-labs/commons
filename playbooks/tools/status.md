---
name: status
slug: status
domain: tools
description: Playbook for the status tool, covering the narrow polling projection for job wait loops, choosing among status, cat and info for job reads, terminal states, and finding a job you did not just fire.
when_to_use: Poll a running job. Built for wait loops; a narrow projection that does not bloat context however often you call it.
prefer_skills: []
related_tools: [status, run, cat, info, ls, find]
examples: []
---

`status /state/jobs/<uuid>` returns only the moving parts: `status`,
`progress`, `started_at`, `finished_at`, `duration_ms`, and a short
`error` summary (at most 200 chars). Everything static about the job you
already have from the `run` response.

## Choosing among the three job reads

- `status`: polling. Where is it *now*?
- `cat /state/jobs/<id>`: the full cb-job record for one-shot inspection,
  including config linkage, settings, payload, and result.
- `info /state/jobs/<id>`: the record plus its stages and the five most
  recent jobs of the same config. This is the "is this failure new or
  chronic?" read.

## Rules

- Jobs only. Any other path is a `validation` error with a redirect hint:
  configs have runs, not a status (use `info /config/workflows/<uuid>`),
  and other state records and resources are read with `cat`.
- An unknown job id is `not_found`, not an empty status.
- Terminal states are `completed`, `failed`, `cancelled`. On `failed`,
  the error summary is a lead; `cat` the job for the full error before
  diagnosing.
- Space polls sensibly (jobs run seconds to minutes); every poll is a
  turn. If a job stays `queued` unusually long, check siblings via `info`
  before assuming the worker is stuck.
- To find a job you did not just fire: `ls /state/jobs` (orderable;
  `--long` adds `config_id` and `request_id`), `ls
  /state/jobs/latest` for the newest job per config, or `find
  /state/jobs` with `owner=<config-uuid>`, `type`, and `status` filters
  for one config's jobs.
