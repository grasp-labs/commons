# 12. Reference

## URLs

| | dev | prod |
|---|---|---|
| IdP | `https://auth-dev.grasp-daas.com` | `https://auth.grasp-daas.com` |
| APIs | `https://grasp-daas.com/api/{svc}-dev/{v}` | `https://grasp-daas.com/api/{svc}/{v}` |
| MCP | `…/ai-gateway-dev/v1/mcp` | `…/ai-gateway/v1/mcp` |
| AIC app | `https://dev.aic-project.com` | `https://aic-project.com` |

Versions: `config/v3`, `file/v2`, all others `v1`.

## Kafka topics

| Topic | Meaning |
|---|---|
| `ds.clone..job.requested.v1` | Run a clone |
| `ds.workflow.pipeline.job.requested.v2` | Run a workflow |
| `ds.pipeline..job.requested.v2` | Run a pipeline |
| `ds.<block>…job.{completed,failed}.v<N>` | Run outcome |
| `resource.changed` | Config row changed |
| `idp.identity..group.{created,updated,deleted,members.updated}.v1` | SCIM group events |
| `ds.consumption.ai-gateway.message.created.v1` | AI conversation messages |

## Status codes

| Code | Meaning |
|---|---|
| 401 | Token missing, expired, wrong issuer |
| 403 | IAM denied |
| 409 | Conflict (e.g. gold schema drift) |
| 422 | Validation failed |
| 503 | IAM or a dependency unreachable — not a deny |

## Glossary

| Term | Meaning |
|---|---|
| **Commons / AIC** | The platform and its shared public content |
| **Tenant** | Isolation boundary; `rsc` claim |
| **Platform tenant** | The tenant that may publish `issuer: "public"` |
| **Compute block** | `clone`, `workflow` or `pipeline` |
| **Linked service** | Connection + credential refs to a system |
| **Dataset** | A readable/writable thing behind a linked service |
| **Medallion** | Bronze (raw) → silver (clean) → gold (published) |
| **SCD2** | Gold history mode with `_valid_from` / `_valid_to` |
| **cb-job** | Run record in ds-state |
| **Profile** | Tenant AI policy: models, tools, limits |
| **Platform skill** | Saved tool trajectory, `skill_invoke_<id>` |
| **Playbook** | Markdown guidance + KG node `playbook:<slug>` |
| **CRN** | Resource name used in IAM policies |

## Where to read more

| Topic | Where |
|---|---|
| API reference | `https://grasp-daas.com/api/{service}[-dev]/{version}/docs/` |
| OpenID discovery | `{IdP}/.well-known/openid-configuration` |
| Agent skills | `skills/` in `grasp-labs/commons` |
| Courses | *Welcome to Commons*, *Build with Commons* |
