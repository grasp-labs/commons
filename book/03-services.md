# 3. The services

The IdP and 12 platform services. HTTP API base URL pattern:
`https://grasp-daas.com/api/{service}[-dev]/{version}`.
All APIs require `Authorization: Bearer <JWT>` except `health-check/` and `version/`.
Each has OpenAPI docs at `<base>/docs/`.

| # | Service | Path | Purpose |
|---|---|---|---|
| — | identity-server | `auth[-dev].grasp-daas.com` | Login, tokens, SSO, SCIM |
| 1 | ds-iam | `iam/v1` | Groups, members, policies, actions |
| 2 | ds-vault | `vault/v1` | Secrets |
| 3 | ds-config | `config/v3` | Single source of truth |
| 4 | ds-message | `message/v1` | On-demand trigger |
| 5 | ds-ingress | `ingress/v1` | Webhook trigger |
| 6 | ds-fetch | `fetch/v1` | SQL over the datalake |
| 7 | ds-file | `file/v2` | Files and metadata |
| 8 | ds-state | `state/v1` | Key/value state, job status |
| 9 | ds-knowledge-graph | `knowledge-graph/v1` | Nodes, edges, evidence, retrieval |
| 10 | ds-tools | `tools/v1` | The 20 tools (internal) |
| 11 | ds-ai-gateway | `ai-gateway/v1` | LLM, MCP, policy, tool loop |
| 12 | ds-agent | emerging | Fenced agent compute block |

---

## identity-server — the IdP

Issues identity JWTs. See chapter 2.

| Endpoint | Use |
|---|---|
| `POST /oauth/token/` | Get a token |
| `GET /oidc/authorize` | SSO entry |
| `POST /auth/login/`, `POST /mfa/login/` | Password + MFA |
| `GET /auth/me/` | Who am I |
| `/scim/v2/Users`, `/scim/v2/Groups` | Provisioning |
| `/oauth/.well-known/jwks.json` | Signing keys |

## 1. ds-iam — authorization

Stores who may do what. Evaluation happens inside each service via `ds-go-iam-middleware`.

| Endpoint | Use |
|---|---|
| `/action/` | Global action catalog (`{service}:{operationId}`) |
| `/group/`, `/member/` | Groups and memberships |
| `/policy/`, `/map/group-policy/` | Policies and bindings |
| `/principal/{id}/policies/` | Effective policies for a principal |

## 2. ds-vault — secrets

Envelope-encrypted secrets with per-secret ACL (`owners`, `viewers`). Plaintext is never returned.

| Endpoint | Use |
|---|---|
| `/secret/` | Create / list secrets |
| `/secret/{id}/` | Read metadata, update, delete |
| `/store/` | Available backends (`ds_vault`, `aws_ssm`) |

Reference from config: `@{get_secret, <key>}`. Go SDK: `ds-vault-go-sdk`; Python: `ds-vault-py-sdk`.

## 3. ds-config — the source of truth

Everything a tenant *is* and *runs*. Changes are published on Kafka as `resource.changed`.

| Area | Endpoints |
|---|---|
| Tenancy | `/tenant/`, `/owner/`, `/contact/` |
| Data plane | `/linked-service/`, `/dataset/`, `/schema/`, `/record/`, `/vpn-connection/` |
| Compute blocks | `/clone/`, `/workflow/`, `/workflow/task/`, `/pipeline/`, `/runtime-profile/` |
| Triggers | `/schedule/`, `/event/`, `/map/{clone,workflow,pipeline}-{schedule,event}/`, `/map/workflow-task-dependency/` |
| Queue audit | `/enqueued-job/` |
| AI policy | `/llm/profile/`, `/llm/model/`, `/llm/provider/`, `/llm/tool/`, `/llm/skill/`, `/llm/mcp-server/`, `/llm/mount/`, `/llm/policy-tier/`, `/llm/rate-limit-tier/` |
| Billing | `/billing/*`, `/tenant/billing/*` |
| Learning | `/exam/*` |

## 4. ds-message — on-demand trigger

Publishes a compute-block run request to Kafka with a full config snapshot.

```http
POST /message/{topic}/
{"id": "<clone|workflow|pipeline uuid>", "payload": {...}}
```

`GET /topics/` lists topics. IAM: `message:createMessage` + read on the block.

## 5. ds-ingress — webhook trigger

Receives external webhooks, verifies the signature with the secret from vault,
and publishes to Kafka.

| Endpoint | Use |
|---|---|
| `POST /webhook/{event_id}/` | Signed webhook for a Config `event` |
| `POST /oauth/webhook/{event_id}/` | Webhook authenticated with OAuth |

New providers: add a verifier in `internal/service/webhook_verification.go`.

## 6. ds-fetch — the datalake gate

Read-only SQL over the tenant's bronze/silver/gold Parquet (DuckDB).
`ds-fetch-indexer` keeps the file index fresh (S3 → SQS → Valkey).

| Endpoint | Use |
|---|---|
| `POST /query/` | Run SQL `{"sql": "SELECT ... FROM gold.\"<dataset>\" LIMIT 100"}` |
| `POST /query/validate/` | Validate only |
| `GET /dataset/`, `/dataset/{name}/` | List / describe datasets |

Python: `ds-fetch-py-sdk` (includes the `aic-fetch` CLI).

## 7. ds-file — files

Metadata in Postgres, bytes in S3. Unique on `(tenant, file_path, version)`.

| Endpoint | Use |
|---|---|
| `POST /file/` | Create metadata (`file_path`, `status` required; `tags`, `metadata`, `issuer`) |
| `PUT /file/{id}/content/` | Upload bytes (`application/octet-stream` or `text/plain`) |
| `GET /file/{id}/content/` | Download (supports `Range`) |
| `GET /file/?file_path_prefix=&tag.k=v&meta.k=v` | List / filter |
| `POST /search/` | Full-text search |

Reserved prefixes: `playbook/`, `courses/`, `book/`.

## 8. ds-state — state and job status

Versioned key/value state and the status of every compute-block run.

| Endpoint | Use |
|---|---|
| `/cb-job/`, `/cb-job/latest/`, `/cb-job/statistics/` | Run status per block |
| `/cb-stage/` | Pipeline stage status (bronze/silver/gold) |
| `/state/` | Tenant key/value state |
| `/search/` | Search state |

## 9. ds-knowledge-graph — knowledge

Typed nodes, directed edges, evidence, and hybrid (keyword + vector) retrieval. Backs `grep` and playbook discovery.

| Endpoint | Use |
|---|---|
| `/node/`, `/node/{id}/` | Nodes (`type`, `name` required) |
| `/node/{id}/evidence/` | Citations for a node |
| `/node/{id}/neighbour/` | Graph neighbours |
| `/edge/` | Edges (`type`, `source_id`, `target_id`) |
| `POST /graph/retrieve/` | RAG retrieval with hop expansion and citations |
| `POST /search/` | Simple search |

## 10. ds-tools — the execution plane

Implements the 20 tools (chapter 4). **Not public**: only `ds-ai-gateway` can reach it.

| Endpoint | Use |
|---|---|
| `GET /tools/` | Catalogue |
| `GET /tools/{tool_id}/` | Schema |
| `POST /tools/{tool_id}/invoke/` | Invoke (JSON or SSE) |

Calls other services with the **caller's** bearer, so IAM applies end to end.

## 11. ds-ai-gateway — the AI control plane

One entry point for all AI. Loads tenant policy from Config (`/llm/profile/{id}/resolve/`),
enforces models, tools, rate limits and approvals, and runs the tool loop.

| Endpoint | Use |
|---|---|
| `POST /openai/v1/chat/completions` | OpenAI-compatible chat |
| `GET /openai/v1/models` | Models allowed for your tenant |
| `POST /anthropic/v1/messages` | Anthropic-compatible |
| `POST /mcp` | MCP server: governed tools for Cursor / Claude (chapter 7) |

---

## Supporting services (not in the 11)

| Service | Role |
|---|---|
| `ds-core-scheduler` | Publishes due `enqueued_job` rows to Kafka |
| `ds-clone-dispatcher`, `ds-workflow-dispatcher`, `ds-pipeline-router` | Dispatch compute blocks |
| `ds-workflow-manager` | Runs workflow DAGs |
| `ds-pipeline-{bronze,silver,gold}-service` | Medallion stages |
| `ds-data-partition-provision` | Creates bucket, queues, linked services for new tenants |
| `ds-scim-group-sync`, `idp-kafka-broker` | Identity events → IAM |
| `ds-skill-sink`, `ds-skill-autocapture` | Capture conversations and mine skills |
| `ds-core-billing-writer` | Usage events → billing |
| `ds-agent` | Agent compute on the gateway harness |
| `ds-client` | AIC front end + BFF (courses, playbooks UI) |
