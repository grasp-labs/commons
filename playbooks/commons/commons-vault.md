---
name: commons-vault
description: ds-vault secrets on Commons. Create, rotate and reference secrets without exposing values, secret references in linked services, events and MCP servers. Use whenever a credential, API key, token or password is involved.
when_to_use: ds-vault secrets on Commons. Create, rotate and reference secrets without exposing values, secret references in linked services, events and MCP servers. Use whenever a credential, API key, token or password is involved.
prefer_skills: []
related_tools: [ls, cat]
---

# ds-vault

`https://grasp-daas.com/api/vault[-dev]/v1`. Envelope encryption per secret (KMS-wrapped key,
AES-256-GCM, bound to tenant and key). **The API never returns plaintext**; services resolve it
server-side at run time.

## Endpoints

| Call | Use |
|---|---|
| `GET /store/` | Backends (`ds_vault`, `aws_ssm`) |
| `POST /secret/` | Create. Required `name`, `status`, `store`, `value`; optional `description`, `tags`, `metadata`, `acl` |
| `GET /secret/?name_prefix=&key=&status=` | List metadata |
| `GET /secret/{id}/` | Metadata, including the `key` used in references |
| `PATCH /secret/{id}/` | Metadata only (safe) |
| `PUT /secret/{id}/` | Replace, including `value` = rotate |
| `DELETE /secret/{id}/` | Delete |

IAM: `vault:<operationId>` on `crn:aic:*:vault::secret:*`.

## Claude never handles secret values

The user creates or rotates secrets in their own terminal; Claude may prepare the command. The value
is read silently and never appears in history or chat:

```bash
read -rs VALUE && jq -n --arg v "$VALUE" \
  '{name: "tripletex-employee", status: "active", store: "ds_vault", value: $v}' |
  curl -s https://grasp-daas.com/api/vault-dev/v1/secret/ -H "Authorization: Bearer $COMMONS_JWT" \
    -H "Content-Type: application/json" -d @- | jq '{id, key}'; unset VALUE
```

With tools, `/vault` is metadata-only (`ls /vault`, `cat /vault/<id>`); the plugin guard denies
`write /vault`.

## Referencing a secret

| Where | Form |
|---|---|
| Generic config fields | `@{get_secret, <key>}` |
| Typed linked-service fields | `/ds/vault/<name>/<tenant_id>/<secret_id>/<env>` |
| Webhook event | `settings.vault_ref` (key) + `settings.vault_id` |
| External MCP server | `credential_ref` |

Never write a literal credential into config, code, prompts, logs or commits.

## Rotate

1. `PUT /secret/{id}/` with the new value (user's terminal, as above).
2. References by key keep working; run the dependent block once in dev to confirm.
3. Revoke the old credential at the provider.

Go SDK `ds-vault-go-sdk`, Python `ds-vault-py-sdk`. Ops secrets (JWT keys, SSO, Basic headers) live
in AWS SSM, not here.
