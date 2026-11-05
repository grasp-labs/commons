---
name: commons-ingress
description: ds-ingress webhooks on Commons. Let a source system (Tripletex, Xledger, HubSpot, Visma, Jobbnorge, API key or OAuth) trigger blocks, with signature verification against a vault secret. Use when setting up, testing or debugging webhook-triggered runs.
when_to_use: ds-ingress webhooks on Commons. Let a source system (Tripletex, Xledger, HubSpot, Visma, Jobbnorge, API key or OAuth) trigger blocks, with signature verification against a vault secret. Use when setting up, testing or debugging webhook-triggered runs.
prefer_skills: []
related_tools: [schema, write, run, status]
---

# ds-ingress

`https://grasp-daas.com/api/ingress[-dev]/v1`. Receives a webhook, verifies it, and publishes a run
request for **every block mapped to the event**.

| Endpoint | Auth |
|---|---|
| `POST /webhook/{event_id}/` | No JWT: the provider signature **is** the authentication |
| `POST /oauth/webhook/{event_id}/` | Bearer JWT |

## Set up

1. Store the provider's signing secret in vault (user's terminal, `commons-vault`).
2. Create the event in Config:

   ```json
   POST /event/
   {"name": "tripletex-accounts", "type": "webhook", "status": "active",
    "settings": {"type": "webhook", "provider": "tripletex", "validate_payload": true,
                 "vault_ref": "<secret key>", "vault_id": "<secret id>"}}
   ```

3. Map blocks: `POST /map/workflow-event/` `{"workflow_id", "event_id"}` (or pipeline, clone).
4. Give the provider `https://grasp-daas.com/api/ingress[-dev]/v1/webhook/<event_id>/`.

| `provider` | Verified via |
|---|---|
| `xledger` | `X-XL-Webhook-Signature` + `Date` |
| `hubspot_v1`, `hubspot_v2`, `hubspot_v3` | `X-HubSpot-Signature[-v2\|-v3]` (+ timestamp for v3) |
| `tripletex` | `Authorization` |
| `jobbnorge` | `X-Jobbnorge-Signature` |
| `visma_bnxt` | `x-vwd-signature-v1` |
| `api_key` | `X-Api-Key` |

Keep `validate_payload: true`; without it anyone with the URL can trigger runs. For a provider not
listed, ask the platform team.

## Behaviour

- Pipelines triggered by webhook run in **webhook mode**: bronze is skipped and the payload goes
  straight to silver → gold.
- Workflows receive the body as `payload`.
- Each webhook run counts against the tenant's rate limits and may queue. Bursty sources share
  the pool with schedules and manual runs (see `commons-message`).
- Follow runs in ds-state (`commons-state`).

## Debug

401/403 = signature, secret or header mismatch (check `provider` and the vault secret). 404 = wrong or
inactive event id. Run accepted but nothing ran = no active map or inactive block.
