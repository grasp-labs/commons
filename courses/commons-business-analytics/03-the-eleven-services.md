---
title: The Eleven Services
---
## The eleven services

Commons is eleven services, each with its own tenant-scoped REST surface, sharing one authorization model, one resource-naming scheme, and one search contract — learn one, and the rest feel familiar.

| # | Concern | Service |
| --- | --- | --- |
| 1 | Authorization | `ds.iam.v1` — groups, policies, grants |
| 2 | Configuration | `ds.config.v3` — the definitions everything runs on |
| 3 | Data lake | `ds.fetch.v1` — SQL over the tenant's bronze/silver/gold lake |
| 4 | Files | `ds.file.v2` — storage with first-class metadata |
| 5 | Secrets | `ds.vault.v1` — envelope-encrypted secrets |
| 6 | Memory | `ds.state.v1` — records plus the run ledger |
| 7 | Knowledge | `ds.knowledge-graph.v1` — typed nodes, edges, evidence |
| 8 | Inbound events | `ds.ingress.v1` — external events in |
| 9 | On-demand triggers | `ds.message.v1` — start a clone, workflow or pipeline run |
| 10 | AI entrance | `ds.ai-gateway.v1` — the governed model entrance |
| 11 | Agent plane | `ds.tools.v1` — the agent execution plane |

> **Rule of thumb:** the services hold and govern the data. The compute blocks move and deliver it.

<!-- ds-course-column:2 type=markdown -->

## What the services share — including the AI

Three things make eleven services feel like one platform:

- **Identity and authorization are separate.** Tokens carry who you are; IAM
  resolves what you may do.
- **Everything is named and searched the same way** — one resource-naming scheme
  and one search shape across Knowledge Graph, State, and Files.
- **Tenancy comes from your token, never the payload** — data outside your tenant
  is invisible, not just filtered.

**And the most important part for AI:** the AI uses the *same* surface you do.

- **DS-Tools (`ds.tools.v1`)** exposes the lake, Knowledge Graph, State, Files,
  Config, Vault and IAM through one filesystem-shaped interface — the same verbs
  (`ls`, `preview`, `query`, `text_to_sql`, `plot` …) a person or an agent uses to act.
- **AI Gateway (`ds.ai-gateway.v1`)** is the governed entrance to the models, so
  every prompt and tool call inherits the same identity, policy, and audit.

> **Rule of thumb:** the AI doesn't get a back door. It reaches your data through
> your identity, your permissions, and the same audit trail — which is exactly why
> you can point it at governed data safely.
