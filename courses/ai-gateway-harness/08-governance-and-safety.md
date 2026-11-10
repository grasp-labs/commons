---
title: Governance and safety
---
# Lesson 7 — Governance and safety

A model that can call tools can also call the wrong ones. This lesson shows what
stands between the model and a harmful action. The key idea: **safety is
enforced where tools are dispatched, not by asking the model to behave.**

## The gates, in order

Every real tool call, including each step of a skill, passes one chokepoint in
the harness (`dispatchTool`). The gates run in this order:

```
model asks for a tool
  1. Allowlist      is this tool granted to the tenant?
  2. Plan posture   is this run allowed to change things?
  3. Governance     does this action need a confirmation (P2) or a sign-off (P3)?
  4. Rate limit     is there quota left?
  5. Dispatch       ds-tools or the MCP server (MCP adds an IAM check)
  6. Record         ledger events, retries, error routing
```

The order matters. A tool the tenant was never granted is refused as "not
permitted", which is more useful than blaming plan posture. A call plan posture
refuses never creates a confirmation or a hold. A call that will not run is never
charged quota.

## Gate 1 — The allowlist

Acme's LLM profile lists the tools it has been granted. A tool outside the list
is refused with an error the model can read, and it never reaches ds-tools:

```
tool not permitted: rm is not in this tenant's allowlist
```

For MCP tools the allowlist is narrowed further to what IAM grants the caller
(lesson 8), so an approved tool Kari may not use is neither shown nor callable.

ds-tools then checks tenant access again on its side. Two independent checks.

## Gate 2 — Plan posture: look, don't touch

A caller can ask for a plan instead of action:

```http
X-DS-Posture: plan
```

In plan posture, **reads run and writes are refused, always.** It does not rely
on the model following instructions; the dispatch path itself refuses.

Whether a tool "writes" comes from the catalogue. Each tool declares an `effect`:

| Tool | Effect | Why |
|---|---|---|
| `cat`, `ls`, `find`, `grep`, `schema`, `status` | read | only observe |
| `inspect`, `transcribe`, `extract` | read | read a file; any file they save is delivery of the answer |
| `write`, `rm`, `run` | write | change, delete or start something |
| `generate_image`, `frames` | write | new files are the product |
| anything unclassified | **write** | unknown is treated as dangerous |

The model's product in plan posture is a proposal, sent through the `propose_plan`
tool: a draft skill, with placeholders for results that do not exist yet ("the
file id step 1 will return"). It can then be reviewed and run as a skill.

Plan posture is refused, not ignored, when it cannot be honoured. Asking for a
plan in `fast` mode, or with `tool_choice: "none"`, gets a clear error instead of
a normal answer that would look safe but was not constrained.

## Gate 3 — Governance tiers

ds-config ships each tenant's rules as an ordered list. The first rule matching
the operation and path wins:

```json
[ { "operation": "write", "path_glob": "/config/governance/**", "tier": "P3" },
  { "operation": "write", "path_glob": "/reports/**",           "tier": "P2" },
  { "operation": "write", "path_glob": "**",                    "tier": "P0" } ]
```

| Tier | Meaning | How |
|---|---|---|
| P0 | run freely | no gate |
| P2 | "are you sure?" | the person driving the chat confirms, in the same conversation |
| P3 | sign-off | an approver, maybe someone else, maybe hours later |

### P2 — confirm in the conversation

The model calls `write /reports/globex-2026-09.md`. The gateway does **not** run
it. It pauses the loop and answers Kari:

> "Confirmation required — this write on /reports/globex-2026-09.md was NOT
> executed. … Reply "yes" to approve, or anything else to decline."

along with the pending call and a signed `approval_token`. Kari replies "yes" (or
"ok", "approve", "go ahead"…, as the whole message). The gateway checks the
signature, removes the token, runs the call for real, and lets the model describe
the result.

Points worth knowing:

- **The model never confirms itself.** The person (or the calling program)
  driving the chat confirms. Otherwise the model could approve its own actions.
- **No database row.** The pending call lives in the signed token the client
  holds. It is valid for 10 minutes and only for that exact call.
- **Anything other than a clear yes declines.** "Hmm, what folder is that?"
  runs nothing; the model answers the question and may propose again.
- **A program can confirm too.** A calling program answers the pending call with
  a `tool_result`. The gateway ignores that body, runs the call itself, and uses
  the real result.

### P3 — sign-off, possibly later

For the most sensitive actions, the call becomes a **hold**: a row in
`llm_governance_approval`, and the model is told `approval_required:
/governance/approvals/<id>`. The turn ends.

```
pending ──approve──▶ approved ──executor──▶ executing ──▶ executed
   │                                            └──────▶ failed
   ├──reject──▶ rejected
   └──timeout──▶ expired
```

- An approver from Acme's `governance_approvers` decides, in the UI or with an
  `approve`/`reject` tool. Rejecting requires a reason.
- One gateway *executor* replays approved holds. A database lock makes sure only
  one replica drains at a time, and each hold is claimed atomically, so it runs
  once.
- Secrets are never stored in a hold: only a vault reference.
- Kari learns the outcome by asking, in the same session: the model reads
  `/governance/approvals/<id>` with `status`.

A skill with governed steps asks **once** for the whole skill, listing every
governed step. A P3 step inside an approved skill still gets its own hold.
Accepting a plan never skips a sign-off.

## Gate 4 — Rate limits

Limits live in Valkey and are shared by all replicas:

- requests per minute, charged at the door (`429` when over);
- tokens per minute and per day, charged after each answer;
- concurrent sessions per tenant;
- tool calls per minute, by cost tier (`standard`, `elevated`, `restricted`),
  charged **before** dispatch, so a throttled call is never run or billed.

A tool throttled mid-loop comes back to the model as a readable error ("retry
after 12s"), not as a failed request.

## After dispatch — when a tool fails, who fixes it?

Every failure has a class, and the class decides who can unblock it:

| Route | Classes | What happens |
|---|---|---|
| Model | validation, not_found, conflict | the error goes back to the model, which can fix its arguments |
| Retry | timeout, upstream_unavailable | the gateway retries a few times with back-off (a timeout is not retried), then hands the error to the model |
| Step in | unauthenticated, unauthorised, cancelled | the run stops; a person must act (log in, get access) |
| Terminal | internal, unknown | the error goes back to the model as a failed result; it can work around the broken tool |

The model is never asked to fix what only a person can fix. It would just waste
turns.

## Guardrails

Each tenant can turn on `pii_redaction` (emails, card numbers, US social
security numbers, IBANs) and `profanity_filter`. They mask text in the request, the
response, streamed chunks, and tool results inside the loop. If a guardrail
fails, the turn is refused rather than served unguarded.

## Modes: how much may the model reach for?

Posture asks "may it change things?". Mode asks "how much may it reach for?". They
are separate settings.

| Mode | What the model gets |
|---|---|
| `fast` | no tools; one direct model call |
| `adaptive` (default) | meta-tools + working set |
| `auto` | as adaptive, plus `request_more_tools` and `request_reasoning` to escalate itself |

In `auto`, the model can ask for extended reasoning on the next turn, within the
tenant's reasoning budget per session. When the budget is spent, the tool answers
`{"allowed": false}` and the model carries on without it.

The tenant's `max_turns` is a ceiling: a request can lower it, never raise it.

## Check yourself

1. The model is in plan posture and calls `extract` on a PDF. Does it run?
2. Kari replies "yes, but use the /archive folder" to a P2 question. Is the write
   approved?
3. Why is the tool rate limit charged *before* dispatch?
4. A tool returns `unauthorised`. Does the model get a chance to retry?

<details><summary>Answers</summary>

1. Yes. `extract` is classified `read`: the file it saves only delivers what was
   asked for, and the source is untouched.
2. No. Only a clear approval, as the whole message, counts. This reply declines;
   nothing runs, and the model can propose a write to `/archive` instead.
3. So a throttled call is never run, and therefore never billed by ds-tools.
4. No. It is a "step in" failure: the run stops and the error goes to the caller,
   because only a person can grant access.

</details>

Next: Lesson 8 — External MCP servers
