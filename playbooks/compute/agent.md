---
name: "Agent compute block"
slug: agent
domain: compute
description: "What the agent compute block is (a versioned, fenced, headless agent definition run as a job), its current status (designed, not yet runnable), how a definition is shaped, and how it differs from chat in the AI Gateway."
when_to_use: "The user asks to build, schedule, or run an autonomous agent, asks what an agent block is or how it differs from chatting with the assistant, or wants an agent definition drafted or reviewed."
prefer_skills: []
related_tools: [cat, ls, write, run, status]
examples: []
---

## Status first

The agent block is **emerging**: its contract and definition schema are
published, but nothing executes one yet. Today:

- `/config/agents` is not a config type. `write` and `ls` reject it.
- `run` fires only `/config/workflows`, `/config/clones` and
  `/config/pipelines`.
- The message service has no agent topic, and the gateway does not
  enforce an agent fence.

Do not try to create or fire an agent. Tell the user it is not available
yet, and offer what works now (below). You may draft a definition for
review. Label it a draft and do not store it under `/config`.

## What an agent block is

An agent is a versioned JSON definition that runs as a queued job, the
way a workflow does. A run compiles the definition into a **fence**,
drives the AI Gateway harness inside it, validates the answer, and writes
a run record. The model chooses the path, and the fence decides the
reach.

Definition fields (required: `name`, `version`, `instructions`, `io`,
`grant`):

- `name` `^[a-z0-9][a-z0-9-]{1,62}$`, `version` SemVer. A published
  version is immutable.
- `instructions`: intent, rules and stop conditions. May reference
  `#/inputs/<name>` and `#/variables/<name>`.
- `io.input` and `io.output` are JSON Schemas. `output` must be a closed
  object (`additionalProperties: false`, non-empty `required`).
  `io.evidence` is `required` (default) or `none`. When required, the
  compiler adds an `evidence` array of `{claim, path, sql?}`, and the
  author must not declare it.
- `grant`: `tools` (ids or `all`), `tools_except`, and path globs for
  `read`, `write`, `run` (fireable block paths only), plus
  `require_approval`. A missing list means nothing, never `all`. `*` is
  one segment, a trailing `/**` covers descendants, and a glob may be
  `#/inputs/<name>`.
- `model`: `name` (from the tenant's allowed models), `mode`
  `adaptive` | `auto` (`fast` is rejected), `max_turns`,
  `reasoning_tokens`, `repair_turns` 0-2.
- `posture`: `plan` (default) or `execute`.
- `runtime`: `executor` `lambda` (default) or `fargate`, `timeout_s`
  (default 600, at most 900 on Lambda and 3600 on Fargate).

Run rules in the contract:

- Fence = grant ∩ tenant LLM profile ∩ the requester's own entitlement.
  `all` means all the requester is entitled to. Request overrides may
  only narrow: drop tools or paths, lower turns, `execute` → `plan`.
- Unknown or unentitled names fail at compile time, before any token is
  spent, and every error is reported.
- Runs are headless. Every P2 tier becomes P3, so gated mutations are
  held for an approver and the run does not wait. `require_approval`
  forces P3 on its paths.
- External systems change only through `run` of a workflow that validates
  its own payload.
- The final message must be exactly one JSON object matching `io.output`.
  Each `evidence.path` must have actually been read in the run.
- Terminal status is `success`, `failure`, `cancelled` or `timeout`, and
  the job is polled at `/state/jobs/<id>`.

## Agent vs chat in the gateway

| | Chat | Agent run |
| --- | --- | --- |
| Started by | A user message | A job (on demand, schedule, workflow, A2A) |
| Boundary | Tenant LLM profile | Profile narrowed by the definition's fence |
| Confirmations | P2 asks the user in-turn | None. P2 becomes a P3 hold |
| Output | Free text | One JSON object, schema-validated, with evidence |
| Session | Client's `X-Session-ID` | One session per run (the run id) |
| Result | The reply | A run record plus job status |

## Until it ships

- For one-off analysis, use chat. Add `X-DS-Posture: plan` for a dry run
  (see the `ds-ai-gateway` playbook).
- For repeatable automation, build a workflow and fire or schedule it
  (see the `run` and `ds-message` playbooks).
- When drafting a definition, keep grants as narrow as the job, use
  `query` for every number the output relies on, close the output schema,
  and enumerate what may change.
