---
title: How it fits your Power BI + SQL stack
---
## How it fits your Power BI + SQL stack

Nothing here replaces Power BI or your SQL databases. Commons sits in front of them:

- **Data Pipelines** keep an always-valid copy of your system data on the Commons lake — your certified source of truth.
- **DS Clone** copies from the lake out to where reporting lives — Power BI (Azure Blob) or a reporting database (SQL). Manual copies stop being manual.
- **Workflow** works on lake data — analyse, enrich, model — or fetches and pushes data Pipelines don't cover.
- **Governance** means access rules travel with the data, not with each report.

> **Rule of thumb:** you keep your dashboards. Commons makes the data behind them trusted, current, and governed.

<!-- ds-course-column:2 type=markdown -->

### The breakdown: source to dashboard

| Layer | What happens | Commons piece |
| --- | --- | --- |
| **Source** | Systems, catalog datasets | Config (linked services, datasets) |
| **Land** | Keep an always-valid copy on the lake | Data Pipelines |
| **Shape** | Analyse, enrich, model on lake data | Workflow |
| **Deliver** | Copy lake → Power BI (Blob) or SQL | DS Clone |
| **Consume** | Reports & models | **Power BI**, SQL |
| **Govern** | Identity, policy, audit — all layers | IAM, Config, Vault |

Every arrow into Power BI starts from a **certified** dataset on the lake and carries the same permissions all the way down.

> **Rule of thumb:** you read the last row. Commons makes the five above it trustworthy.
