---
name: "text_to_sql"
slug: "text_to_sql"
domain: "tools"
description: "Playbook for the text_to_sql tool: turning a natural-language question into one validated DuckDB SELECT without running it, scoping datasets, refusals, caching, and handing the SQL to query."
when_to_use: "Only for callers with no model of their own (SDK, CLI, BI panel, scheduled job) that need SQL from a question. An agent writes SQL itself with preview then query."
prefer_skills: []
related_tools: [text_to_sql, query, preview, ls]
examples: []
---

`text_to_sql` translates a question into one read-only DuckDB `SELECT`
over the caller's lakehouse datasets and stops. It never runs the
statement: a person or program sees the SQL before any number exists,
then passes it to `query`.

**Not for agents.** An agent already holds the conversation and earlier
results; calling a second model with a bare question costs two inferences
and produces worse SQL. Agents use `preview` then `query`.

## Input

- `question`: natural language, at most 2000 bytes.
- `datasets`: optional, at most 10. Paths (`/datasets/gold/<id>`,
  `/datasets/<silver|bronze>/<pipeline-id>/<job-id>`) or ds-fetch names
  (`gold.<id>`). Omitted, the tool considers every granted dataset up to a
  cap of 25 and tells the model when more were left out.

Scope with `datasets` whenever you know them: the prompt is smaller, the
SQL better, and you know which `paths` to give `query`.

## Output

The bare statement as plain text: no envelope, no fences, no trailing
semicolon. Assign it straight to `query`'s `sql`, with the datasets it
reads in `paths`.

Before returning, the candidate is validated by ds-fetch (parsed,
authorized and bound against real columns, no data read). On a rejection
the tool makes exactly one repair attempt, and only if enough time remains;
a second failure is returned as the error.

## How the model is grounded

- Each dataset is described by `sql_ref`, business name and description
  (gold, from Config), columns, partition columns, primary key and
  `history_mode`. For `scd2` datasets the prompt gives the current-rows
  predicate `_valid_to IS NULL`; check the SQL applies it.
- At most 60 columns per dataset reach the prompt: primary keys, partition
  and system columns first, then schema order. A question about a column
  past the cap may be refused as ungrounded; scope it or ask more narrowly.
- Everything is read under the caller's token; the tool cannot see a
  dataset ds-fetch would not let the caller query.

## Determinism

Results are cached per tenant on the question (whitespace collapsed,
case kept), the exact schema fingerprint and the translator version. The
same question over the same schema returns the same SQL; a schema change
invalidates it.

## Failures

| Class | Meaning | Action |
| --- | --- | --- |
| `validation` (refusal) | Ambiguous, ungrounded (no column behind a term) or out of scope (not a data question, not one SELECT) | Rephrase: which figures, period, grouping. Retrying unchanged fails identically |
| `validation` | Reply was not SQL, or ds-fetch rejected the repaired statement | Rephrase or narrow scope |
| `not_found` | No datasets granted, or not every named dataset is available | Check `ls /datasets`; the tool will not say which name failed |
| `unauthorised` | Tenant LLM policy grants no model this tool can use | An administrator must grant one in the tenant's LLM policy |
| `upstream_unavailable` | Translation service busy or unavailable; may carry "retry in …" | Retry later |
| `timeout` | Translation did not finish | Retry with a narrower scope |

## Pitfalls

- Treat the SQL as a draft to review: the real risk is a plausible query
  answering a slightly different question, not an error.
- `query`'s `_meta.model_free` describes the `query` call only; it does
  not know a model wrote the SQL. Record that provenance yourself.
- The tool asks for at least 45 s when `timeout_ms` is omitted; a short
  explicit `timeout_ms` skips the repair or times out.
