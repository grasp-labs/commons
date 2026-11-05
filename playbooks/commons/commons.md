---
name: commons
description: Entry point for AI Commons (Grasp DaaS). Platform map, environments, login and tokens, Commons MCP setup, error codes, and which commons-* skill to load next. Use for any Commons question or task, or when Commons MCP tools fail to connect.
when_to_use: Entry point for AI Commons (Grasp DaaS). Platform map, environments, login and tokens, Commons MCP setup, error codes, and which commons-* skill to load next. Use for any Commons question or task, or when Commons MCP tools fail to connect.
prefer_skills: []
related_tools: []
---

# AI Commons

**1 IdP, 12 services, 4 compute blocks (clone, workflow, pipeline, agent), 20 tools.** Every tenant is
isolated; every request carries a JWT; every action is checked by IAM.

## Environments

| | dev | prod |
|---|---|---|
| APIs | `https://grasp-daas.com/api/{svc}-dev/{v}` | `https://grasp-daas.com/api/{svc}/{v}` |
| IdP | `https://auth-dev.grasp-daas.com` | `https://auth.grasp-daas.com` |
| MCP | `https://grasp-daas.com/api/ai-gateway-dev/v1/mcp` | `https://grasp-daas.com/api/ai-gateway/v1/mcp` |
| App | `https://dev.aic-project.com` | `https://aic-project.com` |

Versions: `config/v3`, `file/v2`, all others `v1`. OpenAPI docs at `<base>/docs/`.
Work in **dev** unless the user explicitly says prod.

## Two ways in

1. **MCP tools** (preferred). The plugin connects the `commons` MCP server; tools appear as
   `mcp__plugin_commons_commons__<tool>`. Governed by tenant profile + IAM + audit. Load `commons-tools`.
2. **REST** with `curl` and `Authorization: Bearer $COMMONS_JWT`, for things tools do not cover.
   Use the variable; never print, echo or log its value.

## Setup (the user does this in their own terminal, never in chat)

1. Get an OAuth client (`client_id`, `client_secret`) for your tenant from the platform team.
   Prefer a dedicated, least-privilege client for Claude (`commons-safety`).
2. Store it in the OS keychain (prompts for the value; nothing lands in shell history):

   ```bash
   # macOS
   security add-generic-password -s commons-dev -a client_id -w
   security add-generic-password -s commons-dev -a client_secret -w
   # Linux (libsecret)
   secret-tool store --label commons-dev service commons-dev account client_id
   secret-tool store --label commons-dev service commons-dev account client_secret
   ```

   Or export `COMMONS_DEV_CLIENT_ID` / `COMMONS_DEV_CLIENT_SECRET` (`PROD` for prod).
3. In Claude Code: `/plugin` → `commons` → configure the environment and `data_access`. `/mcp` must
   show `commons` connected. Tokens refresh automatically.
4. For REST in a session, start Claude from a shell that ran
   `export COMMONS_JWT=$(<plugin dir>/scripts/auth.sh --token dev)` (valid 1 h).

Claude must never run `auth.sh`, read the keychain, or ask for a secret; the guard hook blocks it.

## Identity

Token claims: `iss` (IdP), `sub` (email or client_id), `cls` (`user`|`app`), `rsc`
(`<tenant_uuid>:<tenant_name>`), `exp`. The token carries **no permissions**; IAM decides per request.
Staff log in via SSO (`{IdP}/oidc/authorize`, PKCE). Machines use `client_credentials` at
`{IdP}/oauth/token/` (1 h, no refresh token).

## Skill map

| Task | Skill |
|---|---|
| Keep data and secrets safe with Claude | `commons-safety` |
| Use the 20 tools | `commons-tools` |
| Permissions, groups, policies | `commons-iam` |
| Secrets | `commons-vault` |
| Any configuration, schedules | `commons-config` |
| Run a block now | `commons-message` |
| Webhooks from source systems | `commons-ingress` |
| SQL over the datalake | `commons-fetch` |
| Files and documents | `commons-file` |
| Job status, key/value state | `commons-state` |
| Knowledge graph, retrieval | `commons-knowledge-graph` |
| LLM, MCP, AI policy | `commons-ai-gateway` |
| Build bronze → silver → gold | `commons-datalake` |
| Build a Prism and Facet | `commons-prism-datalakehouse` |
| Build a workflow DAG | `commons-workflow` |
| Build a Microsoft Copilot agent | `commons-copilot-agent` |
| Ask natural-language questions over data | `commons-talk-to-data` |
| Publish playbooks, courses, books | `commons-publish` |

## How it fits

```text
IdP ──JWT──► every API ──► IAM decides (default deny, deny wins)
config ─► message / ingress / scheduler ─► Kafka ─► dispatchers ─► clone | workflow | pipeline
                                                                   └─► state (cb-job), datalake (S3) ─► fetch
ai-gateway ─► tools ─► config | file | state | knowledge-graph | fetch | vault (metadata) | iam
```

## Errors

| Code | Meaning | Do |
|---|---|---|
| 401 | Token missing, expired or wrong env | Reconnect `/mcp`; check `iss` matches the env |
| 403 | IAM deny for `{service}:{operationId}` | `commons-iam`: check effective policies |
| 404 | Missing, or owned by another tenant | Check the id and tenant |
| 409 | Duplicate or version conflict | Re-read, then retry |
| 422 | Validation | Call `schema` for the path |
| 429 / -32000 | Rate limit | Wait `retryAfter` |
| 503 | IAM or backing service down | Retry later |

Look things up rather than guess: `<base>/docs/`, the book at `book/ai-commons/` in ds-file, and the
OpenAPI spec in each `ds-*` repo.
