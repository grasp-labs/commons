---
name: Microsoft SQL Server provider
slug: microsoft
domain: provider
description: Configure SQL Server linked services and single-table datasets with ds-provider-microsoft-py-lib.
when_to_use: Configuring, reading, loading, deleting, purging or listing a microsoft-sql dataset, or diagnosing its errors. Not for other Microsoft products (Graph, Dynamics, Fabric, Azure storage) or Postgres.
prefer_skills: []
related_tools: []
examples:
  - playbook/provider/examples/microsoft-dataset.json
---

# Microsoft SQL Server provider

`ds-provider-microsoft-py-lib` covers only SQL Server. Example config: `playbook/provider/examples/microsoft-dataset.json`.

| Config `type` | Class |
| --- | --- |
| `ds.resource.linked-service.microsoft-sql` | `MsSqlLinkedService` |
| `ds.resource.dataset.microsoft-sql` | `MsSqlTable` |

Config resolves through `resource.yaml`, which uses the hyphen (`linked-service`) since 0.1.1. The class `type` property still returns `ds.resource.linked_service.microsoft-sql`; do not copy that string into config.

## Linked service

Required: `server` (host only; port goes in `port`), `database`, `username`, `password` (masked; use `@{get_secret, <ref>}`). Defaults: `port` 1433, `driver` `ODBC Driver 18 for SQL Server` (must exist in the runtime image), `encrypt` true, `trust_server_certificate` false (true only for dev/self-signed), `connection_timeout` 30.

`connect()` is idempotent and runs `SELECT 1` before storing the engine, so bad credentials fail at connect: `AuthenticationError` when the driver message mentions "login failed"/"authentication", otherwise `ConnectionError`. `test_connection()` returns `(bool, reason)` and never raises.

## Dataset model: one table, no SQL

`table` and `schema` are both required; there is no `dbo` default. `read`, `delete` and row-purge reflect the table, so it must exist. Only `create` builds one.

| Op | Behaviour |
| --- | --- |
| `read` | SELECT built from `columns`, `filters`, `order_by`, `limit` |
| `create` | Append-only INSERT; creates table from dtypes if absent |
| `delete` | DELETE matching every input column |
| `purge` | Delete all rows, or `DROP TABLE IF EXISTS` when `purge.drop_table` |
| `list` | Tables then views in `schema` |
| `update`/`upsert`/`rename` | `NotSupportedError` |

No raw query, joins, OR, ranges or offset. Put that logic in a view and target the view. `supports_checkpoint` is false (base default), so incremental windows must come from a view or workflow logic.

## Read

- `filters`: equality only, AND-combined.
- `limit` must be > 0 (`ReadError` 400).
- `order_by` from JSON config: use plain column names (ascending). A `["col","desc"]` pair deserializes as a list, not a tuple, and fails as `ReadError` 500 ("unhashable type: 'list'"). Descending order needs a view.
- Unknown names in `columns`/`filters`/`order_by` give `ReadError` 400 with `missing_columns` and `available_columns` in details; use it for discovery with `list()`.
- Missing table: `ReadError` 404.

## Create

- Append-only: no replace or upsert. To reload: `purge` then `create`. Reruns duplicate rows.
- `create.index` true resets the DataFrame index into a column.
- `primary_key`/`primary_key_columns` apply only when the table is created. Missing or absent PK columns give `CreateError` 400.
- Dtype mapping: int itemsize <=2 -> `Integer`, larger ints -> `BigInteger`, float -> `Float`, bool -> `Boolean`, datetime -> `DATETIME2`, everything else -> `NVARCHAR` (renders `NVARCHAR(max)`). `NVARCHAR(max)` can't be an index key, so a string PK will fail. When physical schema matters, create the table with your own DDL first.
- NaN/NaT become NULL. Lists/dicts in cells are passed through and fail at the driver; flatten upstream.
- If input includes an IDENTITY column, `IDENTITY_INSERT` is toggled ON/OFF around the insert.
- `output` is a copy of `input`, not read back from the server.
- Error messages are capped at 800 chars with the `[SQL: ...]` part stripped.

## Delete

No key setting: every column in `input` becomes `col = :p` in the WHERE clause. Trim the frame to key columns first. A float or datetime mismatch deletes nothing, without an error. Empty input is a no-op. Identifiers containing `; " ' [ ]` are rejected. `output` is a copy of `input`.

## Purge

`drop_table` false deletes all rows (no-op if the table is missing). True drops the table. Both are irreversible, and the flag is set on the dataset, not per call. Keep drop datasets separate from row-cleanup datasets.

## Failures

| Symptom | Cause |
| --- | --- |
| `ConnectionError` "Connection not established. Call connect() first." | Not connected |
| `ConnectionError` "Failed to create database engine" / "Failed to connect" | Bad host/port, missing ODBC driver, `encrypt` against a self-signed cert |
| `ReadError` 400 "Invalid order_by direction" | Direction other than asc/desc (Python tuples only) |
| `CreateError` "Missing primary key columns for create()" | `primary_key` without columns |
| `PurgeError` | Often permissions (DROP needs more rights) |
| Config type not found | Used `linked_service` underscore form |

The repo's `examples/mssql` docstrings mention a removed `delete_table` flag; use `purge.drop_table`.
