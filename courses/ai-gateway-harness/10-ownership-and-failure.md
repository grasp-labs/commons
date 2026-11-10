---
title: Ownership and failure
---
# Lesson 9 — Ownership and failure

The harness is spread over several services. This last lesson answers two
questions you will be asked in practice: *who owns this?* and *what happens when
it breaks?*

## Who owns what

| Service | Owns | Does not own |
|---|---|---|
| **ds-ai-gateway** | the loop, discovery, working set, skill execution, gates, ledger writes, session summaries, saved facts, MCP client | any table schema, tool execution |
| **ds-config** | the database, every `llm_*` table and migration, the user-facing APIs (skills, MCP servers, ratings, governance decisions) | runtime behaviour |
| **ds-tools** | the tool catalogue and tool execution | skills, rankings |
| **ds-ranker-refresh** | turning the ledger into stats (every 5 min), ledger retention | user APIs |
| **ds-skill-sink** | storing conversations from Kafka, erasing deleted users | ranking |
| **ds-skill-autocapture** | proposing `candidate` skills (nightly) | promotion |
| **ds-client** | the chat UI and the rating buttons | ranking, storage |
| **IAM** | who may call which MCP tool | which tools exist |
| **identity server** | users, tokens, upstream OAuth for MCP | tool policy |
| **ds-vault** | static secrets | where they are used |

One rule ties this together: **ds-config owns the data shape; everyone else is a
client of it.** A new event type must be added to ds-config's enum *before* the
gateway emits it, or the database rejects those rows.

## The golden rule of failure

> **Nothing in rating, ranking, capture or memory may block a chat.**

The harness treats every learning feature as an enhancement. If it is missing,
the chat still works, just a little less cleverly.

## What breaks, and what Kari notices

| Failure | Effect | Kari notices |
|---|---|---|
| ds-ranker-refresh down | rankings use the last stats | nothing |
| ds-skill-autocapture down | no new candidates | nothing |
| ds-skill-sink down | Kafka keeps the messages; capture waits | nothing |
| Ledger database down | the batch is dropped; ratings of those runs never reach the rankings | nothing |
| One bad ledger row | only that row is dropped, the rest of the batch is kept | nothing |
| Valkey down | rate limits fail open (or use per-replica counters if Valkey was absent at start-up) | nothing, usually |
| Knowledge graph down | discovery returns tools and skills, no playbooks | slightly weaker answers |
| Summary store missing | `recall` is not offered | the model cannot look up old sessions |
| ds-tools catalogue sync fails | the last good copy keeps serving | nothing |
| A tool times out | the model gets an error and can choose another way | maybe a slower answer |
| Kari has not connected Tripletex | the run stops with a "Connect" link | she connects and retries |
| Plan posture cannot classify a tool | plan runs refuse that tool and a warning is logged | a plan with gaps, never a write |

Notice the pattern: **failures that only lose learning degrade quietly; failures
that would lose safety fail closed.** A missing ranker costs quality. A tool
whose effect is unknown is treated as a write.

## Fail open, fail closed

Choosing which way to fail is a design decision, made once per gate:

| Gate | On error | Why |
|---|---|---|
| Ranking, stats | open: cold-start scores | quality only |
| Knowledge graph | open: local results | quality only |
| Tool rate limit | open: allow the call | a broken limiter must not stop all work |
| Allowlist with no policy | open: no gateway gate | degraded mode; ds-tools' own access check still applies |
| Allowlist with a policy | closed: an empty list refuses everything | the tenant said "nothing" |
| Plan posture | closed: unknown effect is write | safety |
| Guardrails | closed: the turn is refused | never serve unguarded |
| MCP approval without a definition | closed: not served | never show the model an unapproved text |
| IAM | closed: no grant, no call | access control |

## Deploy order for skill-loop changes

Because ds-config owns the schema, changes ship in this order:

1. **ds-config** — the migration (new tables, enum values, indexes).
2. **ds-ai-gateway** — starts writing the new fields.
3. **ds-ranker-refresh, ds-skill-sink, ds-skill-autocapture** — any order.
4. **IAM** — grant end users `config:submitFeedback` so they can rate.
5. **ds-client** — the rating UI.

## Where to go from here

You now have the whole picture. For exact rules:

- `harness_design.md`: the authoritative design, section by section.
- `mcp_server_contract.md`: MCP servers.
- ds-config `docs/llm/skill-contract.md`: the skill loop across services.
- `making-skills.md`: how to author skills.
- `how-to-tenant-guardrails.md`: guardrails.

## Final check

Explain, in your own words, everything that happens to Kari's sentence:

> "Find the September invoices for Globex in Tripletex and save a summary to our
> reports folder."

<details><summary>A model answer</summary>

ds-client posts it to the gateway's chat endpoint with Kari's token and a session id.
Middleware verifies the token, loads Acme's policy, and charges one request.
Guardrails mask any PII. The harness runs because no bypass applies.

On turn one the working set is seeded with Acme's granted tools, and perhaps a
proven "monthly invoice summary" skill if it clearly beats everything else. If
not, the model calls `discover_tools`, which ranks tools, skills and playbooks
by keyword fit, Acme's success rates, recency and admin priority.
`mcp_tripletex__search_invoices` comes first. `expand_tool` loads it within the
token budget.

The call passes the allowlist, plan posture (it is a read), governance (P0) and
the rate limit, then IAM. The gateway exchanges Kari's token for her Tripletex
token and calls Tripletex. The ledger records `invoke` and `success`.

The model then calls `write` to `/reports/...`. That is P2 for Acme, so the loop
pauses and asks Kari to reply yes. She does, the gateway verifies the signed
token and runs the write, and the model reports the result.

At the end, the run's calls are labelled `user_kept`, a session summary is saved
for `recall`, and the conversation goes to Kafka. The response carries
`x_ds_feedback`, so Kari can rate the answer and any skill run in it.

Within 5 minutes the ranker folds this run into Acme's stats. If Kari and her
colleagues keep doing the same read-only sequence, autocapture proposes it as a
skill one night, Ola promotes it, and next month the whole task is one call.

</details>
