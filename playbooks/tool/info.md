---
name: "info"
slug: info
domain: tool
description: "Playbook for the info tool: cat plus the related context each resource type naturally has, what each type adds, extras_included and extras_failed, and when to reach for cat or status instead."
when_to_use: "Read a resource together with the context that matters for reasoning about it: one call instead of a cat plus several follow-ups."
prefer_skills: []
related_tools: [info, cat, ls, status]
examples: []
---

`info` = `cat` + the related data each type naturally has, fetched
concurrently. It uses the same path scheme as `cat` (UUIDs; discover them
with `ls`/`find`/`grep` first). Cost 2.

## What each type adds

- KG node: top 5 neighbours and the 3 most recent evidence records. This is
  the cheapest way to orient in the graph.
- KG edge: its source and target nodes.
- cb-job (`/state/jobs/<uuid>`): its stages and the 5 latest jobs of the
  same config ("is this failure new?").
- Workflow: tasks, the 5 most recent jobs, and linked schedules and events.
- Clone: source and target datasets plus recent jobs.
- Dataset: its linked service. Linked service: the datasets using it.
- Schedule / event: linked workflows and clones (events also get their
  schema). Schema: parsed schema data and events using it.
- LLM profile: returned as the fully resolved bundle. Skills and catalogue
  entries add stats; models add their provider.
- File: metadata plus a preview of the first 4 KB (text when valid UTF-8).
- IAM group: its members and policies. Policy: its holders. Member: its
  group.

## Rules

- Types with no natural extras return what `cat` returns, with
  `_meta.extras_included: []`. Examples: State records, Vault metadata, KG
  evidence and workflow tasks. Do not spend a turn hunting for context that
  was declared absent.
- A failed extra never fails the call. Check `_meta.extras_failed`; the base
  resource is still there.
- Related entries are compact (path + identifying fields). Drill into one
  with `cat`/`info` on its `path`; do not expect full embeds.
- For file bytes, use `cat /files/<uuid>/content`. `info` only previews and
  rejects `/content` and `/thumbnail` paths.
- To poll a job, use `status`, not repeated `info` calls.
