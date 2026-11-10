---
title: The building blocks
---
# The building blocks

| Group | Services |
|---|---|
| **Who** | identity-server (login), ds-iam (permissions) |
| **What** | ds-config (the source of truth), ds-vault (secrets) |
| **When** | ds-message (now), ds-ingress (webhook), schedules (cron) |
| **Data** | ds-fetch (SQL on the datalake), ds-file, ds-state, ds-knowledge-graph |
| **AI** | ds-ai-gateway (models + policy + MCP), ds-tools (the 20 tools) |
| **Out** | ds-channels (email, SMS, Slack, Teams to verified channels; emerging) |

**Three compute blocks** do the work:

- **clone**: copy a dataset from A to B
- **workflow**: a DAG of tasks (read, transform, write, notify)
- **pipeline**: bronze → silver → gold, for the datalake
