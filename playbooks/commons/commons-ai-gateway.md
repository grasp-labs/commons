---
name: commons-ai-gateway
description: ds-ai-gateway, the Commons AI control plane. OpenAI and Anthropic compatible model endpoints on Bedrock, the MCP server, tenant LLM profiles, tool grants, approvals, guardrails, external MCP servers, platform skills and playbooks. Use when calling models through Commons, configuring AI policy, connecting MCP clients or registering MCP servers.
when_to_use: ds-ai-gateway, the Commons AI control plane. OpenAI and Anthropic compatible model endpoints on Bedrock, the MCP server, tenant LLM profiles, tool grants, approvals, guardrails, external MCP servers, platform skills and playbooks. Use when calling models through Commons, configuring AI policy, connecting MCP clients or registering MCP servers.
prefer_skills: []
related_tools: []
---

# ds-ai-gateway

`https://grasp-daas.com/api/ai-gateway[-dev]/v1`. One governed entry for all AI: auth → IAM →
tenant policy → quota → audit → usage. Bearer JWT only (`x-api-key` is rejected).

## Endpoints

| Call | Use |
|---|---|
| `POST /openai/v1/chat/completions`, `GET /openai/v1/models` | OpenAI-compatible |
| `POST /anthropic/v1/messages` | Anthropic-compatible; SDK `base_url` = `…/v1/anthropic` |
| `POST /mcp` | MCP server (Streamable HTTP, stateless; `initialize`, `tools/list`, `tools/call`) |

Models run on Bedrock; the requested `model` must be in the tenant's `allowed_models`.

## Claude through the gateway

```bash
export ANTHROPIC_BASE_URL=https://grasp-daas.com/api/ai-gateway-dev/v1/anthropic
export ANTHROPIC_AUTH_TOKEN=<JWT>     # user's terminal; see commons-safety
```

Request shape decides behaviour: `tool_choice: "none"` = plain model; client `tools[]` = passed
through (Claude Code); no tools and tenant mode not `fast` = gateway harness with platform tools.
External image URLs are rejected; client-side `mcp_servers` are dropped.

## Tenant policy (Config `/llm/*`)

| Resource | Controls |
|---|---|
| `/llm/profile/` | Models, `allowed_tools`, `default_mode` (`fast`\|`adaptive`\|`auto`), `max_turns`, reasoning caps, `region_pin`, `guardrails` (`{"pii_redaction": "enabled"}`) |
| `/llm/policy-tier/` | `(operation, path glob) → tier` for mutating tool calls: P0 runs, P2 in-turn approval, P3 async hold |
| `/llm/governance-approval/` | P3 holds; approvers `approve` / `reject` |
| `/llm/rate-limit-tier/` | `starter`/`pro`/`enterprise`/`unlimited`: RPM, TPM, TPD, sessions, tool calls (standard, elevated, restricted). LLM only; compute blocks have separate tiers (`commons-message`). Credits gate use separately. |
| `/llm/model/`, `/llm/provider/` | Model catalogue and wire ids |
| `/llm/tool/`, `/llm/mount/` | Tool registry, external mounts (`/mnt`) |
| `/llm/skill/` | Platform skills (saved tool trajectories, `skill_invoke_<id>`) |
| `/llm/mcp-server/` | External MCP servers |

Effective policy: `GET /llm/profile/{id}/resolve/`. P2 approvals return an `approval_token` (HMAC)
that must be replayed with a stable `X-Session-ID`.

## MCP clients

Endpoint `…/v1/mcp` with a `client_credentials` token. This plugin configures it for Claude Code.
Cursor: `~/.cursor/mcp.json` with `"url"` and `"headers": {"Authorization": "Bearer ${env:COMMONS_JWT}"}`.

| Result | Meaning |
|---|---|
| 401 | Token missing or expired |
| `-32602 Unknown tool` | Not in `allowed_tools` |
| `-32000` + `retryAfter` | Rate or concurrency limit |
| `isError: true` | Tool ran; IAM or input rejected it |

## External MCP servers (gateway as client)

1. Upstream credential in vault. 2. `POST /llm/mcp-server/` with HTTPS URL, auth type and
`credential_ref`. 3. Allow tools explicitly in its `tools` map (deny by default). 4. IAM
`ai-gateway:callMcpTool` on `crn:aic:*:ai-gateway::mcp-tool:<slug>/<tool>`, with denies for
destructive tools. Models see them as `mcp_<slug>__<tool>`.

## Harness extras

`discover_tools`, `expand_tool` (tool schema, skill or playbook), `recall` (earlier sessions). Tool
results are truncated at each tool's token budget; every call is in the audit trail and billed.

Reference: `ds-ai-gateway/docs/walkthroughs/`, `ds-config/docs/llm/`.
