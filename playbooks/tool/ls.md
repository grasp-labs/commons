---
name: "ls"
slug: ls
domain: tool
description: "Playbook for the ls tool: browsing containers and prefixes, the name-vs-UUID convention, filter semantics per service, pagination, tombstones, and the IAM blast-radius counts."
when_to_use: "Browsing (\"what's here\"): enumerate a container or prefix before picking something to cat/info. Not for rich filtering (find) or content search (grep)."
prefer_skills: []
related_tools: [ls, cat, find, grep, info]
examples: []
---

`ls` lists children at a path. Start unknown territory at `/`. The roots are
`datasets`, `kg`, `state`, `files`, `config`, `vault` and `iam`, plus `mnt`
when the tenant has mounted domains. Containers like `/kg`, `/iam`,
`/config`, `/config/llm` and `/config/billing` are virtual listings that
need no backing call.

## The one convention that trips everyone

For State and Files, an entry's `path` is the record **UUID** and its `name`
is the human key (`key` / `file_path`). You browse by name, but every
follow-up (`cat`, `write`, `rm`) addresses the UUID from `path`. Never
construct `/state/<key>` or `/files/<file_path>`: those are names, not
addresses.

## Rules

- Prefix browsing: `ls /state/<prefix>` and `ls /files/<prefix>` match on a
  key / file_path prefix, and `filter` extends the prefix. `/state/jobs` is
  reserved for cb-jobs and is never a state key prefix. Its forms are
  `/state/jobs`, `/state/jobs/latest`, `/state/jobs/<config-uuid>` and
  `/state/jobs/<job-uuid>/stages`.
- `filter` semantics vary by path: prefix where the service supports it,
  substring otherwise. Paths with no name column (KG edges, cb-jobs) reject
  `filter` instead of ignoring it. Anything richer (types, time windows,
  tags, foreign keys) is `find`'s job.
- Paginate with `_meta.next_offset` as the next call's `offset` (`limit` max
  500, default 50). Trust `has_more`, not arithmetic on `total`. `total` is
  a floor, never less than what you have seen. `_meta.truncated` means the
  page was cut to fit the output budget, so keep paging.
- Soft-deleted records are hidden by default. To see tombstones where the
  service supports it, use `ls <container> status=deleted`. Soft-delete is a
  `write` of `status=deleted`; `rm` is a hard delete.
- `long=true` adds per-service extras (type, status, trust_level, tags...).
  Use it when choosing between entries, not by default.
- An empty result is `entries: []`, not an error.
- `/datasets[/gold|silver|bronze]` lists the lakehouse datasets you are
  granted. It is the entry point for a data question.

## IAM

- Group rows carry `member_count`/`policy_count` and policy rows
  `holder_count` even without `long`, so a blast-radius check is one listing.
- `ls /iam/policies/<uuid>/principals` lists who holds a policy.
- Principals are not enumerable. Read one identity's grants with
  `cat /iam/principals/<principal_id>/policies`.
