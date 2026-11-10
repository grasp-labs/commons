---
name: "ds-tools: the tool plane"
slug: ds-tools
domain: service
description: "How the AI Commons tools work together: the path model and roots, discovery before addressing, read and write effects, P0/P2/P3 approval tiers, output budgets and overflow files, timeouts, and the error classes."
when_to_use: "Orienting in AI Commons before a multi-tool task, deciding which tool addresses a resource, or interpreting an approval, overflow, timeout or error class from any tool."
prefer_skills: []
related_tools: [ls, find, grep, cat, info, schema, write, rm, run, status, query, preview, text_to_sql, plot, extract, inspect, transcribe, frames, generate_image, websearch]
examples: []
---

Every AI Commons capability is one of 20 tools addressed by path. Each
tool runs under the caller's own token, so a backing service decides what
the caller may see or change; a tool cannot widen it. Per-tool detail
lives in each tool's playbook (same slug as the tool).

## Path model

`ls /` lists the roots: `/datasets`, `/kg`, `/state`, `/files`, `/config`,
`/vault`, `/iam`. `/mnt/<domain>/…` appears when the tenant has trusted
external mounts. Resources are `/<service>/<type>/<id>`, e.g.
`/kg/nodes/<uuid>`, `/config/workflows/<uuid>`, `/files/<uuid>/content`,
`/datasets/gold/<uuid>`. Container nodes (`/`, `/config`, `/config/llm`,
`/iam`) are virtual and list their children. `/governance/approvals/<id>`
is served by the gateway, not a root (see Tiers).

## Discovery before addressing

Most resources are addressed by UUID and no tool resolves names.

1. Find: `ls` (children, prefix/filter), `find` (rich filters), `grep`
   (content search).
2. Read: `cat` (one resource verbatim) or `info` (resource plus context).
3. Act: `schema` for the body, then `write` / `rm` / `run`; `status` for
   jobs.

Data questions: `ls /datasets` → `preview` → `query` → `plot`.
Documents: `extract` first, `inspect` for scans and images; `transcribe`
for audio/video, `frames` for video stills. External: `websearch`.
Media tools and `text_to_sql` are registered only where their backend is
configured, so the catalogue may hold fewer than 20.

## Effects

The catalogue classifies every tool `read` or `write`; there is no other
class.

- `write`: `write`, `rm`, `run`, `generate_image`, `frames`.
- `read`: everything else, including tools that store an overflow or
  result file (`query`, `plot`, `extract`, `inspect`, `transcribe`):
  delivering what was read is not a mutation.
- Plan posture dispatches only explicit reads. A write returns
  `not_executed_plan_posture`; keep reading, then propose the plan.
- A tool missing from the tenant's allowlist fails with "tool not
  permitted" before any dispatch.

## Approval tiers

The gateway resolves `(tool name, path argument)` against the tenant's
ordered tier rules; the first match wins and no match means ungated.

- **P0**: runs freely.
- **P2**: synchronous confirmation. The call is not executed; the caller
  gets a confirmation ask with a token bound to the exact arguments and
  session, valid 10 minutes. Any changed argument invalidates it.
- **P3**: asynchronous hold. Result `approval_required` with
  `approval_id` and `path` `/governance/approvals/<id>`; an approver has
  24 h to decide. Do not approve your own request; poll with `status` on
  that path. Approvers get `approve` / `reject` (reject needs a reason).

Platform defaults (a tenant may add rules):

| Tier | Rules |
| --- | --- |
| P0 | `status` everywhere |
| P2 | `write` under `/state`, `/kg/nodes`, `/kg/edges`, `/files`, `/config`, `/vault`; every `rm`, `run` |
| P3 | `write` and `rm` under `/config/billing/**` and `/config/llm/**` (profiles, policy tiers, models, providers, MCP servers) |

Rules match the call's `path` argument. A call without `path` is not gated,
so always pass it (`generate_image` defaults to `/files`). `generate_image`
and `frames` are never gated: config accepts no rules for them.
Put secrets in `/vault` and pass `/ds/vault/…` references, never
plaintext.

## Output budget

- Each tool has a result budget. List tools (`ls`, `find`) return fewer
  rows plus `_meta.next_offset`; page with `offset`.
- A result over budget is stored whole as a file and replaced by
  `result too large to return inline: N bytes; the complete result is
  stored as /files/<id>` plus an opening excerpt. Read it with `cat` or
  `grep`; do not re-run the call. If storing is unavailable the result is
  cut and flagged truncated.
- Tools with their own artifacts (`query`, `extract`, `plot`, …) say so
  in their result.

## Timeouts

Default 8 s, maximum 120 s (`timeout_ms`, clamped). Slow tools raise
their own floor (e.g. `query` 30 s, `text_to_sql` 45 s) only when
`timeout_ms` is omitted; an explicit lower value wins. Omit it unless you
need longer.

## Error classes

| Class | Gateway reaction | Do |
| --- | --- | --- |
| `validation` | back to the model | Fix the arguments; the message names the field |
| `not_found` | back to the model | Re-discover; an ungranted resource also looks missing |
| `conflict` | back to the model | Re-read current state, then retry |
| `timeout`, `upstream_unavailable` | bounded retry, then to the model | Wait, or narrow the work |
| `unauthenticated`, `unauthorised`, `cancelled` | ends the run | Needs a human: sign-in or access |
| `internal` | to the model | Report; retrying will not help |

See the `ds-iam` playbook for access, `memory` for saved memory.
