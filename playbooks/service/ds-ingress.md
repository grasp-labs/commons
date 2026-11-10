---
name: "ds-ingress: webhook triggers"
slug: ds-ingress
domain: service
description: "Set up and debug inbound webhooks through ds-ingress: event config, provider signature verification, Vault secret reference, schema validation, mapping an event to workflow, clone and pipeline runs, and duplicate-delivery risk."
when_to_use: "An external system (Xledger, HubSpot, Tripletex, Jobbnorge, Visma, or any API-key caller) must start a run by calling a URL, or a webhook returns 400/401/404/422/500 or fires the wrong or duplicate runs."
prefer_skills: []
related_tools: [write, cat, ls, find, info, status, rm]
examples: []
---

An **event** in config is the webhook's identity. Its UUID is the URL:
`POST /api/ingress/v1/webhook/<event-uuid>/`. ds-ingress loads the event,
verifies the caller, and publishes one run request per compute block
mapped to the event. No tool calls the webhook. You configure it, and the
external system calls it.

## Setup sequence

1. Stage the shared secret in Vault. Note its **key** (`/ds/vault/...`),
   not its UUID.
2. `write /config/events`: `type: webhook`, `name`, `status`,
   `settings: {provider, vault_ref, validate_payload}`. Add `schema_id`
   only if `validate_payload` is true.
3. Map the event to each block to fire:
   - `/config/maps/workflow-events` `{event_id, workflow_id}`
   - `/config/maps/clone-events` `{event_id, clone_id}`
   - `/config/maps/pipeline-events` `{event_id, pipeline_id,
     settings: {strategy_policy: {load_mode, publish_mode}}}`
4. Give the provider the URL and secret. Verify with `ls /state/jobs` after
   its first delivery.

Each mapped block fires on its own `topic_id`. A block without one
cannot be published.

## Providers (`settings.provider`)

| Value | Caller must send |
| --- | --- |
| `xledger` | `X-XL-Webhook-Signature`: HMAC-SHA256 of `<unix-seconds>.<body>`, base64url; `Date` (RFC 1123) within 15 min; secret stored base64url |
| `hubspot_v1` | `X-HubSpot-Signature`: hex SHA-256 of secret + body |
| `hubspot_v2` | `X-HubSpot-Signature-v2`: hex SHA-256 of secret + method + URI + body |
| `hubspot_v3` | `X-HubSpot-Signature-v3`: HMAC over method + absolute URI + body + timestamp, base64; `X-HubSpot-Request-Timestamp` (ms) within 5 min |
| `tripletex` | `Authorization: Bearer <secret>`, `Content-Type: application/json` |
| `jobbnorge` | `X-Jobbnorge-Signature`: HMAC-SHA256 of body, hex |
| `visma_bnxt` | `x-vwd-signature-v1`: HMAC-SHA256 of body, base64; secret stored base64 |
| `api_key` | `X-Api-Key: <secret>`, `Content-Type: application/json` |

Any other value is 400 "unknown provider". Match the secret encoding the
provider expects. An HMAC secret that does not decode is a 500.

The second route, `POST /api/ingress/v1/oauth/webhook/<event-uuid>/`,
takes a platform bearer token instead of a signature. Use it for callers
that already hold a platform identity.

## What a delivery publishes

- The body must be non-empty, valid JSON.
- With `validate_payload`, the body is checked against the event schema:
  422 with field errors. A missing schema is a 500.
- One event per mapped block, `created_by` the ingress service principal,
  with the event's `owner_id`.
- Workflow and clone runs receive the webhook body as `payload`. A body of
  800 KiB or more is stored in the tenant data lake under
  `datalake/raw/webhook/` and sent by `payload_uri` instead.
- **Pipeline runs do not receive the body.** Their payload is the
  mapping's `strategy_policy`. A pipeline webhook is a pure trigger.
- A workflow on the v1 topic receives only its `metadata` as context. The
  v2 topic carries the full workflow snapshot.

## Diagnosing

| Response | Cause |
| --- | --- |
| 400 `invalid id` | Path is not a UUID |
| 400 missing/invalid header or timestamp | Wrong provider, header, or clock skew |
| 401 invalid signature/token | Secret or encoding mismatch, or wrong `vault_ref` |
| 404 | No event with that UUID |
| 422 | Body fails the event schema |
| 500 | No block mapped to the event, schema missing, or undecodable secret |
| 502 | Broker or config database unavailable |
| 503 | Tenant storage not provisioned (large bodies) |

Read the setup back with `cat /config/events/<uuid>` and
`ls /config/maps/workflow-events` (likewise clone and pipeline) filtered
on the event.

## Pitfalls

- **No dedup.** Each delivery publishes fresh run requests. Providers
  retry on timeouts and 5xx, so expect duplicates. Make the workflow
  idempotent. A failure after some blocks were published (502) still
  leaves those runs queued, and the provider's retry fires them again.
- **Event `status` is not checked.** A `draft` or `inactive` event still
  fires. To stop a webhook, `rm` its mappings or the event.
- The event UUID is the only address. Treat the URL as sensitive, and
  always use a verifying provider on the unauthenticated route.
- A mistyped `vault_ref` does not fail loudly. Verification then runs
  against an empty secret and rejects the call (401). Check the key first.
