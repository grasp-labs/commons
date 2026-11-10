---
title: Data and compute
---
# Data and compute

**Every run follows one path**

trigger → Kafka → dispatcher → worker → result in **ds-state**

**Triggers**: manual (ds-message), schedule (cron or rate), webhook (ds-ingress). A workflow
runs at most `max_concurrent_jobs` at once (default 1) and a pipeline one job at a time;
extra fires wait as `queued`.

**A datalake** is a pipeline:

1. **Linked service**: how to reach the source (credentials in vault)
2. **Bronze dataset**: what to read
3. **Silver SQL**: clean and type the rows
4. **Gold dataset**: the published table, with optional history (`scd2`)
5. **Trigger** it, then **query** it with SQL

**A workflow** is tasks plus dependencies. Run it with a payload, then watch its status.
