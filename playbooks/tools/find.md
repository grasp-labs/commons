---
name: "find"
slug: "find"
domain: "tools"
description: "Playbook for the find tool: metadata filtering vocabulary, time-window syntax, the validated where escape hatch, name prefix vs substring semantics per service, and the job and IAM query patterns."
when_to_use: "Search by metadata: name, type, status, owner, time windows, tags, or service-specific fields. Use ls for plain browsing, grep for content search."
prefer_skills: []
related_tools: [find, ls, grep, cat, info]
examples: []
---

`find` is `ls` with a filter vocabulary. It returns the same envelope, uses
the same pagination (`_meta.next_offset`, `has_more`) and puts the UUID in
`path`. Cost 2 (ls is 1).

## Rules

- Filters are validated, never silently dropped. A filter the path has no
  column for is a `validation` error. For example, `mtime` on `/state/jobs`
  fails because jobs are immutable and have only `created_at`, so use
  `ctime`. An answered result applied every filter you passed.
- Virtual paths (`/`, `/kg`, `/config`, `/config/maps`, `/config/llm`,
  `/config/billing`) are not findable because there is nothing to filter.
  Use `ls`.
- Time filters: `mtime="-7d"` (units m/h/d/w), `ctime=">=2026-01-01"`, or
  RFC3339. Ranges are comma-separated: `mtime=">=2026-06-01,<2026-07-01"`.
- `tag` (key=value, AND-combined) works on State and Files only. Elsewhere,
  use `where`.
- `where` is the escape hatch for service-specific fields. Examples:
  `trust_level`/`confidence`/`has_body` on KG nodes, `root_only` on KG
  edges, `key_prefix`/`meta.<k>` on State, `latest_per_config`/`session_id` on
  jobs (filter jobs by config with `owner`, not `where`), `tags_all`/`tags_any`/`version` on
  `/config/schemas`, and foreign keys on IAM. An unknown key is a
  `validation` error naming the keys the path supports. On IAM, the service
  itself rejects unknown keys.
- `name` is a prefix match on the State root, Files and Vault, and a
  case-insensitive substring match on KG nodes, Config and IAM. KG edges are
  unnamed, so `name` there is an error; filter edges with `type`/`where`.
- `owner` maps to `owner_id`, or to `config_id_in` on `/state/jobs`.
- `order_by` is passed through; the backing service names its valid columns
  when you pick a wrong one.

## Patterns worth knowing

- Latest run per config: `find /state/jobs/latest`, or
  `find /state/jobs where={"latest_per_config": "true"}`.
- Recent failures: `find /state/jobs type=workflow status=failed
  ctime="-24h" order_by="-created_at"`.
- IAM membership: `find /iam/members where={"group_id": "<uuid>"}`.
- Groups holding a policy:
  `find /iam/maps/group-policies where={"policy_id": "<uuid>"}`.
  For principals, use `find /iam/policies/<uuid>/principals`.
- External mounts: `find /mnt/<domain>[/<prefix>]` takes only `name`
  (substring) and `type`. Other filters are rejected.
