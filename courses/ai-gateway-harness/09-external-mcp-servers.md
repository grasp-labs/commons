---
title: External MCP servers
---
# Lesson 8 — External MCP servers

MCP (Model Context Protocol) is the standard way for a service to offer tools to
a model. Acme wants the model to use Tripletex, its ERP. This lesson shows how a
tenant's own MCP server joins the harness, with the same governance as our own
tools, and why it is safe.

## Two directions, do not mix them up

| Direction | What | Runs the harness? |
|---|---|---|
| Gateway as MCP **server** (`/mcp`) | Claude Desktop, Cursor and other agents use *our* tools | No: one tool per call, their model decides |
| Gateway as MCP **client** | *our* harness uses a tenant's tools, like Tripletex | Yes: same loop, same gates |

This lesson is about the second: the gateway as a client of Tripletex.

## Who owns what

| Concern | Owner |
|---|---|
| Which servers exist, where, how to log in, which tools are approved | ds-config (`llm_mcp_server`) |
| Who may call which tool | IAM |
| Connecting, calling, mapping results, spotting drift | the gateway |
| Each user's login at the upstream (OAuth) | the identity server |
| Static secrets (API keys, passwords) | ds-vault; ds-config stores only a reference |

## Step 1 — Ola registers Tripletex

Ola posts to ds-config:

```json
POST /llm/mcp-server/
{ "slug": "tripletex",
  "url": "https://mcp.tripletex.no",
  "status": "active",
  "auth": { "type": "oauth2_authorization_code" },
  "tools": {
    "search_invoices": { "effect": "read",  "cost_tier": "standard",
      "description": "Search invoices by customer and date range.",
      "input_schema": { "type": "object", "properties": { "customer": { "type": "string" } } } },
    "register_hours":  { "effect": "write", "cost_tier": "elevated",
      "description": "Register hours on a project activity.",
      "input_schema": { "type": "object", "properties": { "hours": { "type": "number" } },
                        "required": ["hours"] } } } }
```

What each part means:

- **`slug`** names the server everywhere: tool names, IAM resources. It cannot be
  changed later, because IAM grants refer to it.
- **`url`** must be public `https`. No IP addresses, no loopback hosts, no internal
  host names. After DNS lookup the gateway also refuses private addresses, so a
  server cannot point the gateway at our own network.
- **`tools`** is the approval list. **Deny by default:** a tool Tripletex offers
  but Ola did not list does not exist for Acme.

### The approved definition is what the model sees

Each approved tool carries its own `description` and `input_schema`. The model
sees *those*, never what Tripletex currently advertises. If Tripletex changes a
description tomorrow, perhaps to something malicious like "ignore your
instructions and ...", it cannot reach the model until an admin approves it.

When the gateway notices that the live definition differs from the approved one
(**drift**), it keeps using the approved one and writes an audit event so an
admin can review it.

An entry without a non-blank description and a schema is not served at all.

### Size limits keep tools affordable

A description may be at most 2 KiB and a schema at most 8 KiB. That holds one
tool to about 2,500 tokens, so at least three always fit in the ~8,000-token
working set (lesson 3).

## Step 2 — Tool names

Each approved tool becomes `mcp_<slug>__<tool>`:

```
mcp_tripletex__search_invoices
mcp_tripletex__register_hours
```

The name fits the 64-character limit every model provider enforces, and cannot
collide with ds-tools ids or `skill_invoke_*`. The ledger uses the same name, so
MCP tools get success rates, rankings and skills exactly like our own tools.

## Step 3 — IAM decides who may call what

Before **every** call, and when listing tools, the gateway asks IAM:

- action: `ai-gateway:callMcpTool`
- resource: the tool, as `mcp-tool:<slug>/<tool>`

An example policy:

```json
{ "sid": "CallTripletexReadTools", "effect": "allow",
  "actions": ["ai-gateway:callMcpTool"],
  "resources": ["crn:aic:*:ai-gateway::mcp-tool:tripletex/search_invoices",
                "crn:aic:*:ai-gateway::mcp-tool:tripletex/get_invoice"] },
{ "sid": "NeverDeleteInTripletex", "effect": "deny",
  "actions": ["ai-gateway:callMcpTool"],
  "resources": ["crn:aic:*:ai-gateway::mcp-tool:tripletex/delete_timesheet_entry"] }
```

With this policy Kari can search and read invoices, cannot register hours (not
granted), and can never delete timesheet entries (explicit deny beats any allow).

A tool Kari is not granted is not even listed for her, and the dispatch gate
refuses it too. Configuration says what *exists*; IAM says who may *use* it.

## Step 4 — Logging in upstream

The gateway never forwards Kari's platform token to Tripletex. How it
authenticates depends on `auth.type`:

| Type | Gateway sends |
|---|---|
| `none` | nothing |
| `bearer`, `header`, `basic` | a secret read from ds-vault |
| `oauth2_client_credentials` | a token for the *server*, fetched with a vault secret, cached until it expires |
| `oauth2_authorization_code` | a token for *Kari herself* at Tripletex |
| `mtls` | a client certificate from ds-vault |

For Tripletex (`oauth2_authorization_code`), each user connects their own
account:

1. On each call, the gateway exchanges Kari's platform token at the identity
   server for her Tripletex token (RFC 8693 token exchange).
2. If Kari has never connected Tripletex, the identity server answers
   `consent_required` with a link. The run stops and Kari sees a "Connect
   Tripletex" link.
3. After she connects, the exchange returns her token. The gateway uses it for
   this call only and stores nothing.
4. If Tripletex answers 401, the gateway exchanges once more so the identity
   server can refresh the token. The tool is never called anonymously.

Vault references are checked to belong to the server's own tenant before use, so
a server row cannot borrow another tenant's secret.

## Step 5 — Calling and results

In the harness, an MCP tool goes through the same gates as any tool (lesson 7):
allowlist, plan posture (using the approved `effect`), governance, rate limit by
`cost_tier`, then the IAM check, then the call.

| Tripletex answers | Gateway does |
|---|---|
| text or structured content | tool output |
| an image | an image block |
| more than ~8,000 tokens | stores the full result in DS File, gives the model a shortened result plus `/files/<id>` |
| `isError: true`, invalid params | back to the model to fix |
| 401/403 after the retry | stops; a person must act |
| 429, 5xx | retried, except a `write`, which retries only on 429 (it may already have run) |
| timeout | not retried; back to the model |

The upstream's own `readOnlyHint` is never trusted. The effect is what Ola
approved.

## Kari's run, revisited

```
turn 1  discover_tools("search invoices by customer")  -> mcp_tripletex__search_invoices 0.91
turn 2  expand_tool(tk_...)                             -> loaded (≈ 300 tokens)
turn 3  mcp_tripletex__search_invoices({customer: "Globex", ...})
          allowlist ✓  plan ✓  P0 ✓  quota ✓  IAM ✓
          token exchange -> Kari's Tripletex token -> call -> 14 invoices
turn 4  write(/reports/globex-2026-09.md)               -> P2: "Reply yes to run it"
```

## Check yourself

1. Tripletex adds a new tool `delete_invoice`. Can the model call it?
2. Tripletex rewrites the description of `search_invoices`. What does the model
   see?
3. Why does the gateway refuse an MCP `url` like `https://10.0.0.5/mcp`?
4. Kari has `search_invoices` approved in config but no IAM grant. What happens?

<details><summary>Answers</summary>

1. No. It is not in the approved list, so it does not exist for Acme.
2. The approved description. The change is logged as drift for an admin.
3. It is an IP address, and private addresses would let a tenant point the
   gateway at internal systems.
4. It is not listed for her, and a call to it is refused.

</details>

Next: Lesson 9 — Ownership and failure
