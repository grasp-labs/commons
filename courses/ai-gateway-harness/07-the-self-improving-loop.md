---
title: The self-improving loop
---
# Lesson 6 — The self-improving loop

This is the heart of the vision: the system gets better at Acme's work by doing
Acme's work, without anyone tuning it. Lesson 6 shows the loop, the services in
it, and the safeguards that stop it learning the wrong things.

## The loop in one picture

```
            ┌──────────────── ds-client ────────────────┐
            │ chat ▲                      thumbs up/down │
            ▼      │ x_ds_feedback                    ▼
  ds-tools ◄── ds-ai-gateway ─────────────►  ds-config POST /feedback/
               │        │ Kafka: conversation
               │        ▼
               │   ds-skill-sink
               ▼        ▼
        ┌────────── Config database ──────────┐
        │ ledger · conversations · skills · stats │
        └──────────────────────────────────────┘
               ▲ every 5 min          ▲ nightly
        ds-ranker-refresh     ds-skill-autocapture
```

1. The gateway runs tools and skills and records every outcome (the ledger).
2. The user rates answers; ds-config copies the verdict for each skill run in
   the answer into the same ledger.
3. ds-ranker-refresh turns the ledger into success rates every 5 minutes.
4. The gateway ranks on those success rates (lesson 3), so what works rises.
5. ds-skill-sink stores the conversations.
6. ds-skill-autocapture finds repeated tool sequences every night and proposes
   them as `candidate` skills.
7. An admin promotes a good candidate to `active`, and it enters step 1.

Each part can fail without stopping the chat. Lesson 9 covers that.

## Signal 1 — Did the call work?

Straight from the ledger: `success`, `error`, `timeout`, `cancelled`. A timeout
and a cancellation are kept apart from a plain error, so a tool is not punished
when the *user* closed the tab.

## Signal 2 — Did the user keep the result?

When a run ends, the gateway groups the model's calls by tool (or skill) and
exact arguments, and labels each group:

| Label | Rule | Example |
|---|---|---|
| `user_kept` | called once, succeeded, and the model finished on its own | Kari got her report and moved on |
| `user_redid` | the identical call made twice | `search_invoices(Globex, 2026-09)` again, because the first answer did not satisfy |
| `loop_detected` | the identical call made 3+ times | the model is stuck |

`user_kept` is not given when the run hit the turn limit: the task never
finished, so "kept" would be a guess. A tool that often needs redoing ranks
lower, even if it never errors.

## Signal 3 — Did the user like it?

The response carries the ids needed to rate it:

```json
"x_ds_feedback": {
  "session_id": "<uuid>",
  "response_id": "<uuid>",
  "skills": [{ "skill_id": "3f6c...", "turn_id": "9e8d...", "tool_use_id": "toolu_01AB..." }] }
```

`skills` lists the skill runs in this answer that succeeded (`[]` when none ran).

ds-client shows thumbs up/down. A click posts `{"kind": "answer", "rating": "up", ...}`
to ds-config `POST /feedback/` with Kari's own token. ds-config stores the rating
and copies the verdict to the ledger only for listed skill runs the ledger
records **for Kari**. Someone else's run in the list is ignored.

The gateway adds `x_ds_feedback` only when it can be honoured:

- the caller is a **person** (JWT `cls = "user"`), not an app or service;
- tenant, session and request ids are UUIDs (so the run was recorded).

Where it sits on the wire: `choices[0]` for OpenAI (on the final chunk when
streaming), top level for Anthropic (in the final `message_delta` when streaming).

## Turning signals into rankings

ds-ranker-refresh runs every 5 minutes. For each skill and tool it computes
success over 24 hours, 7 days and 30 days. For a skill run, "success" means:

> the user approved it, **or** the user kept it and did not reject it.

A rating that arrives late recounts the hour of the original run. Ratings do not
change "last used", so rating an old run does not make it look recent.

### Reinforcement is per tenant

Stats are grouped by **tenant and skill** (or tool). Acme's experience shapes
Acme's rankings. While Acme has only a few runs of something, the ranker leans
on the pooled record of all tenants (weighted as about 10 runs); once Acme is
busy, its own record dominates. Acme's skills are Acme's alone; a skill becomes
global only when the platform tenant publishes it as `public`.

Users matter for integrity, not for personalisation: a rating counts only from
the user who ran the skill, and capture needs several different users.

## Capture: finding new skills

Every night at 02:30 UTC, ds-skill-autocapture looks at the last 30 days.

It looks for **the same sequence of raw tool calls** (not skill runs) that
appears **at least 3 times, from at least 2 different users** at the same tenant.

Example. Over September:

```
Kari  search_invoices(Globex, 2026-08)  → write(/reports/globex-2026-08.md)
Kari  search_invoices(Initech, 2026-08) → write(/reports/initech-2026-08.md)
Per   search_invoices(Umbrella, 2026-09)→ write(/reports/umbrella-2026-09.md)
```

Same shape, three times, two users: a candidate. Customer and month differ
between runs, so they become **parameters**. A value is baked in as a constant
only if every run, across 2+ users, used the same value. So Kari's personal
choices never get frozen into a skill other people use.

Safety rules for capture:

- **Read-only steps only.** Every step must be `effect = read` and not gated by
  P2 or P3 for the tenant. Capturing writes would mean replaying mutations
  nobody confirmed.

  > In the example, `write` is a write, so this exact pair would *not* be
  > captured today. A read-only shape such as `search_invoices → query` would.

- **Real inputs only.** Values come from the stored conversation, never invented.
- **Never promotes.** It writes `candidate` only. A person decides.
- **Never re-proposes a rejected shape.**

## The human in the loop

Ola sees the review queue (`GET /llm/skill/?lifecycle=candidate`), renames the
candidate to "Monthly invoice summary", checks the steps, and promotes it to
`active`. From the next sync it is discoverable, starts at the cold-start score
(0.7), and earns its own ranking from then on.

## Privacy: forgetting a user

When a user is deleted in the identity server, ds-skill-sink waits 65 minutes
(past the 1-hour token lifetime, so no request is still in flight) and then:

- deletes their stored conversation messages, session summaries and saved facts;
- sets `user_sub` to `NULL` on their ledger events.

Stats and ratings stay, but cannot be traced back to the person.

## Check yourself

1. A tool never errors, but the model often calls it twice with the same
   arguments in one run. Will it rank well?
2. Ola sends a rating that names Kari's skill run. What happens?
3. Three runs of the same read-only sequence, all by Kari. Will it be captured?
4. Why is capture limited to read-only sequences?

<details><summary>Answers</summary>

1. Worse than it would otherwise: the retries are labelled `user_redid`, which
   lowers its success rate.
2. ds-config stores Ola's rating, but it never reaches Kari's run on the ledger:
   a verdict counts only from the user whose run it was.
3. No. Capture needs at least two different users.
4. Replaying a captured write would run a mutation nobody confirmed for this new
   context. Write-skill capture is deferred until it can be governed.

</details>

Next: Lesson 7 — Governance and safety
