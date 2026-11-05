---
name: commons-datalake
description: Build a medallion datalake on Commons. Linked service, bronze dataset, aic-gold dataset, pipeline with silver SQL, runtime profiles, triggers, and querying gold. Use when ingesting a source (Tripletex, Xledger, Unimicro, HTTP, SQL, files) into queryable tables or changing a pipeline.
---

# Build a Commons datalake

Config `https://grasp-daas.com/api/config[-dev]/v3`. Lake: Parquet in `s3://ds-<tenant>-<env>/datalake/`
(manifest + bloom index, not Delta/Iceberg). Pipelines are REST only (no tool path).

```text
linked_service ─► bronze dataset ─┐
                                  ├─► pipeline (silver SQL) ─► trigger ─► bronze → silver → gold ─► ds-fetch
linked_service ─► gold dataset ───┘
```

## Confirm with the user first

Source object, primary key, a field that grows on every change, whether history is needed, and the
partition column (if any). **Primary key and `history_mode` cannot change once gold has data.**

## Steps (dev first)

1. **Linked service** `POST /linked-service/` — `type: ds.resource.linked-service.<source>`, settings
   per the `schema` tool for that type, credentials as vault references only (`commons-vault`).
2. **Bronze dataset** `POST /dataset/` — `type: ds.resource.dataset.<source>`, `linked_service_id`,
   provider settings (e.g. Tripletex `{"product_name": "employee"}`). Sources: `tripletex`, `xledger`,
   `unimicro`, `powerofficego`, `simployer`, `http`, `graphql`, `soap`, `sftp`, `postgresql`,
   `microsoft-sql`, `azure-blob`, `azure-table`, `aic-file`, `grasp-file`.
3. **Gold dataset** `POST /dataset/`:

   ```json
   {"name": "employee", "status": "active", "type": "ds.resource.dataset.aic-gold",
    "linked_service_id": "<AIC-AWS linked service>",
    "settings": {"primary_key_fields": ["employee_id"], "ordering_field": "version",
                 "history_mode": "scd2", "partition_keys": []}}
   ```

   `ordering_field`: highest wins, late arrivals dropped. `history_mode`: `scd2` (adds `_valid_from`,
   `_valid_to`) or `none`. Optional `delete_field` for soft deletes.
4. **Pipeline** `POST /pipeline/`:

   ```json
   {"name": "tripletex-employee", "status": "active", "bronze_id": "<bronze>", "gold_id": "<gold>",
    "transform": {"sql_query": "SELECT CAST(id AS BIGINT) AS employee_id, firstName AS first_name, CAST(version AS BIGINT) AS version FROM bronze",
                  "non_null_columns": ["employee_id"]},
    "snapshot_profile_id": "<runtime profile>", "incremental_profile_id": "<runtime profile>",
    "settings": {"strategy_policy": {"defaults": {"load_mode": "incremental"}},
                 "artifact_policy": {"bronze_retention_days": "14d", "silver_retention_days": "90d"}}}
   ```

5. **Run** once: `commons-message` (pipeline topic, `{"id": "<pipeline>"}`).
6. **Watch**: `status /state/jobs/<job_id>`, stages in ds-state `/cb-stage/`.
7. **Verify**: `preview {path: "/datasets/gold/<gold id>", rows: 0}` → row count plausible →
   `query` an aggregate (`commons-fetch`).
8. **Schedule** or webhook (`commons-config`, `commons-ingress`). Promote to prod from reviewed JSON.

## Silver SQL rules

`SELECT <expr> AS <name>, … FROM bronze [WHERE …]`: one row in, at most one row out. No `*`, joins,
subqueries, aggregates, `ORDER BY` or `LIMIT`; aliases need `AS`; outputs may not be `_valid_from` /
`_valid_to`; `non_null_columns` must name outputs and cover the primary key. Full grammar:
`ds-config/silver-sql.md`.

## Checklist

- [ ] Primary key unique and stable in the source; covered by `non_null_columns`.
- [ ] `ordering_field` increases on every change.
- [ ] `history_mode` chosen deliberately; partitions only on low-cardinality query columns.
- [ ] No literal credentials anywhere.
- [ ] Dev run completed and gold counts match the source before prod.

Webhook-triggered pipelines skip bronze.
