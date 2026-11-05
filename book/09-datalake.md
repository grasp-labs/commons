# 9. Building a datalake

Every tenant has a datalake: Parquet on S3 in bucket `ds-<tenant_uuid>-<env>`,
organised as a **medallion**. The `pipeline` compute block fills it; `ds-fetch`
reads it.

| Layer | Holds | Written by | Path |
|---|---|---|---|
| **Bronze** | Raw rows from the source, per run | `ds-pipeline-bronze-service` | `datalake/bronze/{pipeline_id}/{job_id}/` |
| **Silver** | Typed, cleaned rows (your SQL), per run | `ds-pipeline-silver-service` | `datalake/silver/{pipeline_id}/{job_id}/` |
| **Gold** | Published table, merged across runs (SCD2 or snapshot) | `ds-pipeline-gold-service` | `datalake/gold/{dataset_id}/` + `_manifest.parquet` |

Format is plain Parquet with a manifest and bloom index, not Delta or Iceberg.

In the Commons UI, a **Prism** is a pipeline and a **Facet** is its Gold
dataset. The product flow is therefore dataset → Prism → Facet; the API names
remain `dataset` and `pipeline`.

## What you configure

```text
linked_service ──► bronze dataset ─┐
                                   ├─► pipeline (transform = silver SQL) ─► schedule / event / manual
linked_service ──► gold dataset  ──┘
```

### 0. Tenant prerequisites

Done automatically by `ds-data-partition-provision` when a tenant is verified:
bucket, SQS notifications for the fetch indexer, default `HTTP` and `AIC-AWS`
linked services, vault secrets, tenant IAM user. For on-prem sources, add a
VPN: `POST /vpn-connection/` (`docs/vpn_connection/INFO.md`).

### 1. Linked service — how to reach the source

Credentials are vault references, never literals. Typed providers take a vault
path (`/ds/vault/<name>/<tenant_id>/<secret_id>/<env>`); generic fields take
`@{get_secret, <key>}`.

```json
POST /linked-service/
{
  "name": "tripletex-acme",
  "status": "active",
  "type": "ds.resource.linked-service.tripletex",
  "settings": {
    "consumer_token": "/ds/vault/tripletex-consumer/<tenant_id>/<secret_id>/dev",
    "employee_token": "/ds/vault/tripletex-employee/<tenant_id>/<secret_id>/dev"
  }
}
```

Types: `aws`, `aic-aws`, `azure-storage-account`, `graphql`, `http`, `microsoft-sql`,
`postgresql`, `sftp`, `soap`, `xledger`, `simployer`, `powerofficego`, `unimicro`,
`tripletex`. Settings per type: `api/openapi/components/schemas/linked_service/settings/`.
Examples: `docs/examples/linked-service.json`.

### 2. Bronze dataset — what to read

```json
POST /dataset/
{
  "name": "tripletex-employee",
  "status": "active",
  "type": "ds.resource.dataset.tripletex",
  "linked_service_id": "<tripletex linked service>",
  "settings": { "product_name": "employee" }
}
```

Source types: `tripletex`, `xledger`, `unimicro`, `powerofficego`, `simployer`,
`http`, `graphql`, `soap`, `sftp`, `postgresql`, `microsoft-sql`, `azure-blob`,
`azure-table`, `aic-file`, `grasp-file` (all `ds.resource.dataset.<type>`).
Provider logic lives in `ds-provider-*-py-lib`.

### 3. Gold dataset — what to publish

```json
POST /dataset/
{
  "name": "employee",
  "status": "active",
  "type": "ds.resource.dataset.aic-gold",
  "linked_service_id": "<AIC-AWS linked service>",
  "settings": {
    "primary_key_fields": ["employee_id"],
    "ordering_field": "version",
    "history_mode": "scd2",
    "partition_keys": []
  }
}
```

| Setting | Meaning |
|---|---|
| `primary_key_fields` | Row identity. Cannot change once data exists. |
| `ordering_field` | Highest value wins; older arrivals are dropped as late. |
| `history_mode` | `scd2` keeps history (`_valid_from`, `_valid_to`); `none` overwrites. Cannot change once data exists. |
| `partition_keys` | Hive partitions. Choose early; changes are validated against existing data. |
| `delete_field` | Optional soft-delete flag column. |

### 4. Pipeline — tie it together

```json
POST /pipeline/
{
  "name": "tripletex-employee",
  "status": "active",
  "bronze_id": "<bronze dataset>",
  "gold_id": "<gold dataset>",
  "transform": {
    "sql_query": "SELECT CAST(id AS BIGINT) AS employee_id, firstName AS first_name, lastName AS last_name, CAST(version AS BIGINT) AS version FROM bronze",
    "non_null_columns": ["employee_id"]
  },
  "snapshot_profile_id": "<runtime profile>",
  "incremental_profile_id": "<runtime profile>",
  "settings": {
    "strategy_policy": { "defaults": { "load_mode": "incremental" } },
    "artifact_policy": { "bronze_retention_days": "14d", "silver_retention_days": "90d" }
  }
}
```

- **Silver SQL** is a restricted DuckDB `SELECT … FROM bronze [WHERE …]`: one row
  in, at most one row out. No `*`, joins, aggregates or subqueries. Full grammar:
  `silver-sql.md`.
- **Runtime profiles** (`/runtime-profile/`) choose executor, memory and network. `cpu` must
  match `memory_mb`: Lambda goes up to 10240 MB, Fargate from 2048 to 61440 MB.
- **Load mode**: `snapshot` (full read) or `incremental` (checkpointed).

### 5. Trigger it

Manual, schedule or webhook (chapter 6). Manual:

```bash
curl -X POST "$MESSAGE/message/ds.pipeline..job.requested.v2/" \
  -H "Authorization: Bearer $JWT" -H "Content-Type: application/json" \
  -d '{"id":"<pipeline_id>"}'
```

`ds-pipeline-router` runs bronze → silver → gold (webhook mode: silver → gold).
Watch stages in ds-state `/cb-stage/`.

### 6. Query it

```bash
curl -s "$FETCH/dataset/" -H "Authorization: Bearer $JWT"     # find table names
curl -s -X POST "$FETCH/query/" -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{"sql":"SELECT * FROM gold.\"<table>\" WHERE _valid_to IS NULL LIMIT 10"}'
```

Or from chat / MCP:

1. `preview {rows: 0}` grounds the question in the real schema and returns the
   table's `sql_ref`.
2. `text_to_sql` drafts one read-only query; it does not execute.
3. Review tables, columns, grain, filters, units and sensitive fields.
4. `query` executes against the same dataset paths; `plot` is optional.

The answer should name its dataset, filters and time range. Aggregate first and
ask before returning identifiable rows. See `commons-talk-to-data`.

## Design checklist

- [ ] Primary key is truly unique and stable in the source.
- [ ] `ordering_field` increases on every change.
- [ ] `non_null_columns` covers the primary key.
- [ ] `history_mode` chosen deliberately (`scd2` for audit, `none` for snapshots).
- [ ] Partitions only on low-cardinality, query-relevant columns.
- [ ] All credentials are `@{get_secret, …}`.
- [ ] Dev run succeeded and gold row count is plausible before prod.

Reference: `ds-pipeline-router/README.md`, `ds-pipeline-{bronze,silver,gold}-service/README.md`,
`internal/dto/pipeline/data/*.json` (tested examples).
