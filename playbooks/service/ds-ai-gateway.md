---
name: "ds-ai-gateway: the AI harness"
slug: ds-ai-gateway
domain: service
description: "How the AI Gateway harness behaves: OpenAI/Anthropic/MCP edges, the resolved LLM profile and its clamps, discover_tools/expand_tool and the working set, governance tiers P0/P2/P3 and approvals, plan posture, X-Session-ID, and rate limits."
when_to_use: "Integrating a client with the gateway, explaining why a tool is missing, a call needs confirmation, a request is refused (401/402/403/409/422), output is cut short, or a confirmation loops; or inspecting a tenant's LLM profile or governance rules."
prefer_skills: []
related_tools: [cat, ls, find, status, info]
examples: []
---

The gateway serves `POST /api/mcp/v1/openai/v1/chat/completions`,
`/anthropic/v1/messages`, and `/mcp` under the same prefix. Clients use
the stock wire format. The tenant's LLM profile decides everything else.

## The profile

Each request resolves **exactly one** LLM profile for the bearer. None
is 403 `no LLM policy`, two or more is 409, and a rejected token is 401.
Read it with `cat /config/llm/profiles/<uuid>/resolved`. Per request:

- `status` must be active (`policy.inactive`). A closed credit gate is
  402. `region_pin` must match.
- `model` must be in `allowed_models` by id, name or provider model id,
  otherwise 422 `policy.model_not_allowed`.
- `max_tokens` is clamped to the lower of the model's `max_output_tokens`
  and the profile's `max_output_tokens_default`. If omitted, it gets that
  ceiling. Answers cut mid-sentence often mean a low ceiling.
- `system_prompt_prefix` is prepended, and the profile's `guardrails`
  replace the client's. Reasoning is off unless `allow_reasoning` and the
  model supports it.
- If the config service is down, the request is served without a profile
  and without the harness.

## When the harness runs

The agentic loop engages only when the model `supports_tools`,
`tool_choice` is not `none`, the mode is not `fast`, and the client sent
no `tools[]` (client tools mean client-side execution). Mode comes from
`default_mode`: `fast`, `adaptive` (the default), or `auto` (requires
`allow_auto_mode`; adds `request_more_tools` and `request_reasoning`).
The loop stops at `max_turns`: default 8, and the profile value is a
ceiling. On that stop the reason is `max_turns`.

## Discovery

The model starts with meta-tools, not the catalogue.

- `discover_tools {intent, k}` returns ranked tools, skills and playbooks
  (`type` `tool` | `skill` | `doc`). `k` defaults to 8, capped at 12.
  Summaries only.
- `expand_tool {token}` loads one result. A tool joins the working set, a
  skill becomes callable, and a playbook returns its guidance with the
  body clamped to about 1200 tokens. Tokens are single-use and expire
  after 10 minutes (`token_expired`: discover again).
- The working set holds 8 tools plus 2 skills and evicts the least
  recently used. Catalogue tools share about 8000 tokens of schema, and a
  tool that alone exceeds this is `tool_too_large`.
- Only active `allowed_tools` grants dispatch. Tenant MCP tools appear as
  `mcp_<slug>__<tool>`. Each tool result is clamped to that tool's
  `max_result_tokens`.
- Past sessions: `recall`, see the `memory` playbook. `remember` /
  `forget` keep up to 30 user facts of at most 300 characters.

## Governance tiers

Each call is matched against the profile's `policy_tiers`, top-down,
first rule whose `operation` equals the tool name and whose `path_glob`
matches the call's `path` argument. Calls with no `path` are not gated.

- **P0**: runs.
- **P2**: the turn ends with a confirmation question plus the held tool
  call, carrying `approval_token`. The token is bound to tenant, session,
  tool, path and the exact arguments, and expires in 10 minutes. The
  user's whole reply must be an approval word (`yes`, `ok`, `approve`,
  `confirm`, `go ahead`, `do it`, `proceed`, ...). Any longer sentence
  declines. Changed arguments or a different session fail closed.
- **P3**: the call is queued at `/governance/approvals/<id>` with 24 hours
  to decide, and the model gets `approval_required`. Read it with
  `status` or `cat`. `approve` / `reject` are offered only to the
  profile's `governance_approvers`. Never approve your own hold. External
  MCP tools cannot be P3.

Usual defaults: `write`, `rm` and `run` are P2; billing and `/config/llm/**` changes are P3. Check the
profile's `policy_tiers` rather than assuming.

## Client contract

- **`X-Session-ID`**: one stable UUID per conversation. Without it every
  request is a new session, so there is no working-set reuse, P2
  approvals cannot verify, and recall hits do not join to transcripts.
- Store and replay assistant messages verbatim, tool calls included.
  Dropping or re-serialising them makes the confirmation loop forever.
- `X-DS-Posture: plan` makes the run propose instead of act: no mutation
  is dispatched, and `propose_plan` is offered. It is refused
  (`posture.harness_bypassed`) when the harness would not run, and an
  unknown value is `posture.unsupported`.
- `X-DS-Progress` sets the streaming progress detail.

## Limits

`rate_limit_tier` caps requests per minute, tokens per minute and per
day, and tool calls per minute and per day. Tool calls count against a global bucket, and `elevated` /
`restricted` tools also count against their own. A limit of 0 means
uncapped. Per-minute limits scale by `burst_multiplier`. Daily limits do
not.
