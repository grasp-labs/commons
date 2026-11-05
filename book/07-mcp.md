# 7. Setting up MCP

The gateway is an **MCP server**. Connect Cursor or Claude to it and their own
model can call your tenant's governed tools (chapter 4). No gateway LLM runs on
this path; the gateway only enforces grants, rate limits and audit, and forwards
your token to ds-tools.

| | prod | dev |
|---|---|---|
| MCP URL | `https://grasp-daas.com/api/ai-gateway/v1/mcp` | `https://grasp-daas.com/api/ai-gateway-dev/v1/mcp` |
| Token URL | `https://auth.grasp-daas.com/oauth/token/` | `https://auth-dev.grasp-daas.com/oauth/token/` |

Transport: **Streamable HTTP**, stateless `POST /mcp` (`GET` returns 405 by design).
Methods: `initialize`, `ping`, `tools/list`, `tools/call`.

## 1. Get credentials

Ask the platform team for an OAuth client (`client_id`, `client_secret`) on your
tenant, and make sure your tenant's LLM profile grants the tools you need
(`allowed_tools`). Keep the secret in your keychain or vault, never in a repo.

```bash
export COMMONS_JWT=$(curl -s https://auth-dev.grasp-daas.com/oauth/token/ \
  -d grant_type=client_credentials \
  -d client_id="$CLIENT_ID" -d client_secret="$CLIENT_SECRET" | jq -r .access_token)
```

Tokens last one hour. Re-run before a session, or wrap it in a shell function.

## 2. Connect

### Cursor

`~/.cursor/mcp.json` (global) or `.cursor/mcp.json` (project):

```json
{
  "mcpServers": {
    "commons": {
      "url": "https://grasp-daas.com/api/ai-gateway-dev/v1/mcp",
      "headers": { "Authorization": "Bearer ${env:COMMONS_JWT}" }
    }
  }
}
```

Start Cursor from a shell where `COMMONS_JWT` is set, then check
**Settings → MCP**: `commons` should be green with its tools listed.

### Claude Code

Install the `commons` plugin (chapter 8). It connects this server, refreshes tokens from your
keychain, and adds the skills and the data-safety guard. In a session, `/mcp` shows the server.

Without the plugin:

```bash
claude mcp add --transport http commons \
  https://grasp-daas.com/api/ai-gateway-dev/v1/mcp \
  --header "Authorization: Bearer $COMMONS_JWT"
```

### Claude Desktop

Desktop needs the `mcp-remote` bridge (`claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "commons": {
      "command": "npx",
      "args": ["-y", "mcp-remote",
               "https://grasp-daas.com/api/ai-gateway-dev/v1/mcp",
               "--header", "Authorization: Bearer ${COMMONS_JWT}"],
      "env": { "COMMONS_JWT": "<JWT>" }
    }
  }
}
```

### Microsoft Copilot Studio

Copilot exposes the whole MCP server as one `InvokeServer` capability; its
orchestrator selects the underlying Commons tool. Prefer the existing,
administrator-approved **AI Commons MCP** connector. For a new connector, start
in dev and use manual OAuth with a registered `authorization_code` client,
`https://auth-dev.grasp-daas.com/oauth/{authorize,token}/`, and resource
`https://grasp-daas.com/api/ai-gateway-dev/v1`.

Put deterministic tool order and path limits in the agent instructions. See the
`commons-copilot-agent` playbook for DS-Fetch, image inspection and PDF extraction
recipes.

## 3. Verify with curl

```bash
MCP=https://grasp-daas.com/api/ai-gateway-dev/v1/mcp
H=(-H "Authorization: Bearer $COMMONS_JWT" -H "Content-Type: application/json")

curl -s "$MCP" "${H[@]}" -d '{"jsonrpc":"2.0","id":1,"method":"initialize",
  "params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"curl","version":"1"}}}'
curl -s "$MCP" "${H[@]}" -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
curl -s "$MCP" "${H[@]}" -d '{"jsonrpc":"2.0","id":3,"method":"tools/call",
  "params":{"name":"ls","arguments":{"path":"/config"}}}'
```

| Result | Meaning |
|---|---|
| `401` | Token missing or expired |
| `-32602 Unknown tool` | Tool not granted to your tenant |
| `-32000` + `retryAfter` | Rate limit or concurrency cap |
| `isError: true` | Tool ran but IAM or input rejected it |

## 4. External MCP servers (gateway as client)

Tenants can plug third-party MCP servers into the gateway so they are governed
like platform tools:

1. Store the upstream credential in ds-vault.
2. `POST /api/config/v3/llm/mcp-server/` with the upstream HTTPS URL, auth type
   (`none`, `bearer`, `header`, `basic`, `oauth2_client_credentials`,
   `oauth2_authorization_code`, `mtls`) and `credential_ref`.
3. Copy the upstream `tools/list` into the row's `tools` map with `effect: allow`
   (deny by default).
4. Grant IAM `ai-gateway:callMcpTool` on `crn:<tenant>::ai-gateway::mcp-tool:<slug>/<tool>`.

They appear to models as `mcp_<slug>__<tool>`.
