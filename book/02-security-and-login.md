# 2. Security and logging in

## Identity vs authorization

| Concern | Owner | Mechanism |
|---|---|---|
| Who are you? | `identity-server` (Django + OAuth Toolkit) | RS256 JWT |
| What may you do? | `ds-iam` + `ds-go-policy` in every service | Policies, evaluated per request |

The token carries **identity only**. Permissions are never in the token.

## Logging in

1. **SSO (preferred).** Open any Commons app and enter your work email. The app
   sends you to `{IdP}/oidc/authorize` (Authorization Code + PKCE, S256) with
   `login_hint=<email>`. Your domain routes you to Entra ID / OIDC / GitHub,
   and you return via `{IdP}/sso/callback`.
2. **Password + MFA.** `POST {IdP}/auth/login/` → if TOTP is enrolled,
   `POST {IdP}/mfa/login/` with the ephemeral token.

Check who you are: `GET {IdP}/auth/me/` or `GET {IdP}/oauth/userinfo/`.

## Getting a token for scripts and services

Client credentials, one tenant per client. Ask the platform team for an OAuth
client and keep the secret in your keychain:

```bash
IDP=https://auth-dev.grasp-daas.com
JWT=$(printf '%s' "$CLIENT_SECRET" | curl -sS --fail "$IDP/oauth/token/" \
  -d grant_type=client_credentials --data-urlencode "client_id=$CLIENT_ID" \
  --data-urlencode "client_secret@-" | jq -r .access_token)
```

Narrow the audience to one API with RFC 8707:
`-d "resource=https://grasp-daas.com/api/config-dev/v3"`.

| Grant | Use |
|---|---|
| `authorization_code` + PKCE | Interactive apps, agents |
| `client_credentials` | Machines, CI, MCP clients (no refresh token) |
| `refresh_token` | Interactive only |

Scopes: `openid`, `read` (default), `write`. Access token lives **1 h**, refresh **1 d**.

## What is in the token

| Claim | Meaning |
|---|---|
| `iss` | IdP host for the env |
| `sub` | email (user) or `client_id` (app) |
| `cls` | `user` or `app` |
| `rsc` | `<tenant_uuid>:<tenant_name>` — your tenant |
| `aud` | `https://grasp-daas.com` (+ requested resources) |

Keys: `{IdP}/oauth/.well-known/jwks.json`. Discovery: `{IdP}/.well-known/openid-configuration`.

## How a request is authorized

```text
Bearer JWT
 → ds-go-echo-middleware   verify iss, exp, kid; parse cls/sub/rsc     → 401 on failure
 → ds-go-iam-middleware    fetch effective policies from ds-iam (cached)
 → ds-go-policy            Decide / Constrain; default deny, deny wins → 403 on deny
                                                                       → 503 if IAM unreachable
```

## IAM model

AWS-IAM-like:

| Primitive | Role |
|---|---|
| Group | Membership container |
| Member | IdP `sub` → group |
| Policy | Allow/deny on actions `{service}:{operationId}` over CRN patterns |
| Binding | Group ↔ policy |

Example action: `config:createWorkflow`, `message:createMessage`, `ai-gateway:callMcpTool`.
In patterns, `aic` means "the caller's tenant". New tenants get `IAMFullAccess`
at bootstrap. IAM API: `https://grasp-daas.com/api/iam/v1/docs/`.

**SCIM.** Entra pushes users and groups to `{IdP}/scim/v2/`; groups sync into
IAM. SCIM carries membership only; an unbound synced group has **no permissions**.

## Secrets

- Never put secrets in config, code or prompts. Store them in **ds-vault**.
- Vault encrypts per secret (KMS-wrapped DEK, AES-256-GCM, AAD bound to tenant + key).
  Plaintext is never returned by the API; services resolve it server-side.
- Reference a secret from config with `@{get_secret, <key>}`.
- MCP servers and linked services use `credential_ref` → vault key.

## Rules

1. Use SSO with MFA. Never share tokens; they are bearer credentials.
2. Use dev for experiments. Prod writes need a reason and a reviewer.
3. Least privilege: request the IAM policy you need, nothing broader.
4. Platform-tenant tokens publish to every tenant. Treat them as root.
5. Report suspected leaks immediately and rotate the secret in vault.
