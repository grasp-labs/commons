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

| Topic | File |
|---|---|
| Architecture | `aic-cli/ARCHITECTURE.md` |
| Auth deep dive | `identity-server/docs/training/IDP-Security-Deep-Dive.md` |
| SSO | `identity-server/docs/training/How-To-Setup-SSO.md` |
| IAM contract | `ds-iam/docs/contract.md` |
| Middleware | `ds-go-echo-middleware/docs/middleware-guide.md` |
| Schedules | `ds-config/docs/schedule/info.md` |
| Silver SQL | `ds-config/silver-sql.md` |
| Gateway contract | `ds-config/docs/llm/config-ai-gateway-contract.md` |
| Skills | `ds-config/docs/llm/skill-contract.md` |
| Playbooks | `ds-ai-gateway/docs/playbooks/playbook.md` |
| MCP | `ds-ai-gateway/docs/walkthroughs/MCP/claude-mcp-tools.md` |
| KG | `ds-knowledge-graph/docs/USER_GUIDE.md` |
| Public resources | `ds-knowledge-graph/docs/PLATFORM_PUBLIC_RESOURCES.md` |
| Workflow executor | `ds-workflow-manager/docs/contract.md` |
| Billing | `ds-config/docs/billing/how-it-works.md` |
