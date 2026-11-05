---
name: commons-prism-datalakehouse
description: Build a governed datalakehouse with a Prism in AI Commons. Use when creating a source dataset, Facet, runtime profiles and pipeline from the UI or API, or explaining the bronze, silver and gold model.
when_to_use: Build a governed datalakehouse with a Prism in AI Commons. Use when creating a source dataset, Facet, runtime profiles and pipeline from the UI or API, or explaining the bronze, silver and gold model.
prefer_skills: []
related_tools: [status, preview, query]
---

# Build a datalakehouse with Prism

A **Prism** is the UI name for a ds-config pipeline. It reads a regular source
dataset (`bronze_id`), applies restricted Silver SQL, and publishes into a
**Facet**, the Gold dataset (`gold_id`).

```text
source → dataset → Prism: bronze → silver → Facet: gold → DS-Fetch
```

## Decide the data contract first

Confirm the source object, stable primary key, monotonically increasing ordering
field, required history (`scd2` or `none`), and low-cardinality partition keys.
The primary key and history mode cannot change after Gold contains data.

## Build in dev

1. Create the source linked service with vault references—never literal secrets.
2. Create the regular source dataset.
3. Create a Facet (`ds.resource.dataset.aic-gold`) and its column schema.
4. Create or select snapshot and incremental runtime profiles.
5. Create the Prism with `owner_id`, `bronze_id`, `gold_id`,
   `snapshot_profile_id`, `incremental_profile_id`, Silver transform and
   retention policy.
6. Run it through its system-owned topic using `commons-message`. Pipelines are
   REST/config resources; the MCP `run` tool does not run them.
7. Follow `/state/jobs/<job-id>` and `/cb-stage/`.
8. Verify the Facet with `preview {rows: 0}`, then an aggregate `query`.
9. Attach a managed schedule or webhook only after the manual run is correct.

Silver SQL is one `SELECT ... FROM bronze`: no joins, aggregates, subqueries,
`*`, `ORDER BY` or `LIMIT`. Alias every output with `AS`; primary-key outputs
must be listed in `non_null_columns`.

## Done means

- Bronze retains the source evidence for the configured period.
- Silver types and names every published field.
- Facet counts and keys reconcile with the source.
- Incremental reruns are idempotent and late records follow ordering policy.
- IAM grants DS-Fetch access only to the intended Facet and Prism runs.
- The reviewed configuration can be promoted without embedded credentials.
