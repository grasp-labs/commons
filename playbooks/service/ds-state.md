---
name: "ds-state: state and jobs"
slug: ds-state
domain: service
description: "Playbook for ds-state: tenant key/value records (keys, prefixes, tags, ACL, TTL, full-text search limits), read-only compute-block job records and stages, statistics, who writes jobs, and how to watch a run."
when_to_use: "Storing or finding small key/value state (checkpoints, flags, notes, transcripts), searching state content, or finding, following and diagnosing clone, pipeline and workflow jobs under /state/jobs."
prefer_skills: []
related_tools: [ls, find, grep, cat, write, rm, status, info, run]
examples: []
---

ds-state holds two unrelated things under `/state`: key/value **records**
(written by tools and clients) and **cb-jobs** (compute-block job rows,
read-only). `/state/jobs` is reserved for jobs and is never a key prefix.

## Records

- Shape: `key` and `value` (both required strings), optional
  `data_type` (`string`, `int64`, `float64`, `decimal`, `time`,
  `datetime`, `bytes`, `uuid`, `map`), `status` (default `draft`),
  `tags` and `metadata` (string maps), `description`, `version`
  (semver), `owner_id`, `acl`, `ttl_seconds`.
- Keys allow only letters, digits, space, `.`, `,`, `_`, `/`, `-`. No
  `@` or `:`: encode them (e.g. `_at_`). Namespace keys as
  `<app>/<purpose>/<id>`.
- A key is unique per tenant, compared case-insensitively, including
  records you cannot see: a second create is `409`. A merge `write`
  never changes the key; only `replace=true` can.
- Addressing is by UUID: `write /state` with the key in the body
  creates; `write /state/<uuid>` merges (PATCH), `replace=true` replaces
  (PUT). `rm /state/<uuid>` is a hard delete. Find the UUID with `ls`,
  `find` or `grep` first; `/state/<key>` is a prefix listing, not a record.
- **ACL is per record.** The creator is always added to `acl.owners`;
  `viewers` defaults to empty, so a record is private to its creator
  even inside the tenant. Add subjects to `viewers`, or `"*"` for
  everyone. Only owners can update or delete.
- `ttl_seconds` (0 = forever) counts from `modified_at`, so every update
  restarts it. Expired rows are hidden from list and read, then swept.
- `ls` and `find` hide `status=deleted` records; `grep` does not.

## Listing and prefixes

- `ls /state` with `filter=<prefix>` sends the filter as a
  case-sensitive literal `key_prefix`.
- `ls /state/<prefix>` sends the path after `/state/` as the prefix, so
  it can never match a key that starts with `/`.
- Pitfall: the AI Commons chat client stores transcripts under
  `/chat/<user>/...` (leading slash). `ls /state/chat/<user>/` misses
  them; use `ls /state` with `filter=/chat/<user>/`. Chat recall is
  covered by the `memory` playbook.
- `find /state` adds `status`, `tag` (exact match, AND), `owner`, date
  ranges and `where` (`meta.<k>`, `key` substring).

## Searching content (`grep path=/state`)

- English full-text: stemmed, stop words dropped, and **every** term must
  match. Use 1-3 distinctive words, not a sentence.
- `where`: `key_prefix`, `tags`, `metadata`, `status`, `created_at_gte`
  /`_lte`, `modified_at_gte`/`_lte`.
- Indexed text is the key, description, version, status, data_type,
  owner_id, tags, metadata and only the **first 32,768 characters** of
  the value. A miss on a long value is not proof of absence: `cat` it.
- `limit` max 50; snippets are a 200-character window.
- Search does not filter expired-but-unswept or `status=deleted`
  records; check `status` before trusting a hit.

## Jobs

- Rows are written straight to the job table by the compute blocks:
  workflows by the workflow dispatcher, clones by the clone dispatcher,
  pipelines by the pipeline router. ds-state only serves them; `write`
  and `rm` on jobs are refused.
- Status: `queued`, `running`, then `completed`, `failed` or
  `cancelled`. A pipeline config runs one job at a time; a new fire
  while one is `running` or `queued` is inserted as `queued` and
  promoted later.
- Only pipeline jobs have stages: `ls /state/jobs/<job-uuid>/stages`,
  `cat /state/jobs/<job-uuid>/stages/<stage-uuid>`.
- `type` is `clone`, `pipeline` or `workflow`.

## Watching a run

1. `run` returns a `/state/jobs/<id>` handle and a `request_id`. The row
   appears asynchronously; do not re-fire (see the `run` playbook).
2. Poll with `status /state/jobs/<id>`; `cat` for the full record
   including `result`; `info` for stages and recent sibling runs.
3. Lost the handle: `find /state/jobs where={"request_id": "<id>"}`.
4. One config's jobs: `find /state/jobs owner=<config-uuid>`. Neither
   `ls /state/jobs/<config-uuid>` nor `where.config_id` filters today;
   both return every job.
5. Newest job per config: `ls /state/jobs/latest`.
6. Volume and failure rate: `cat /state/jobs/statistics[/<type>]`,
   counts by status and type for the last 24 hours.

## Pitfalls

- Values are strings. Serialize JSON yourself and set `data_type: map`.
- Do not store secrets in State; use Vault.
- Jobs are tenant-wide (no per-record ACL); records are not.
