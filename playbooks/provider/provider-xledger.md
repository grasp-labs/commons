---
name: Xledger provider
slug: provider-xledger
domain: provider
description: Configure Xledger GraphQL datasets via packaged entrypoints in ds-provider-xledger-py-lib.
when_to_use: Configuring an Xledger dataset or linked service, picking an entrypoint and operation, setting up incremental reads, or diagnosing unsupported-entrypoint and DS_XLEDGER_* errors.
prefer_skills: []
related_tools: []
examples:
  - playbook/provider/examples/provider-xledger.json
---

# Xledger provider

`ds-provider-xledger-py-lib` (0.2.5) reaches Xledger's GraphQL API. Types: `ds.resource.linked-service.xledger` and `ds.resource.dataset.xledger`. Example config: `playbook/provider/examples/provider-xledger.json`.

## Linked service

`host` defaults to `https://demo.xledger.net/graphql`. Set it explicitly for production (for example `https://www.xledger.net/graphql`). `token` is the raw API token (masked; `@{get_secret, <ref>}`). `connect()` sends it as `Authorization: token <token>`, so don't include the `token ` prefix. Optional: `headers`, `timeout` (60). Retries and a 10 rps token bucket are built in.

## Entrypoints are packaged, not configurable

`settings.entrypoint` must match a packaged folder `assets/<entrypoint>/<operation>/` (`metadata.json` + `query.graphql`); exact name, then lowercase. Workflow config, the KG and tenant config cannot add one. A new entrypoint means new assets plus a library release.

An unknown entrypoint fails at dataset construction: `DeserializationError` "Entrypoint '<name>' is not supported by this provider." For a known entrypoint without that operation's assets, the call fails with "Metadata operation '<op>' is unavailable for entrypoint ... Available operations: ...".

Unknown settings keys are ignored without an error, including `query`, `year` and `pagination`. There is no raw-query escape hatch on this dataset.

Write-capable entrypoints (all others, 61 in total, are read-only):

| Entrypoint | Ops |
| --- | --- |
| bankAccounts | read, create, update, delete |
| companies, contacts, customers, employees, glImportItems, invoiceBaseItems, objectValues, products, projects, salesOrderDetailsItems, suppliers, timesheets, xglDimensions | read, create, update |
| eInvoices | read, update |
| salesOrderItems | create, update (no read) |

Never infer `<parent>Items`; check `assets/`. `upsert`, `purge`, `rename` and `list` always raise `NotSupportedError`.

## Read settings

- `columns`: field names. Nested fields use `_` (`country_code` -> `country { code }`). Omitted means fields with `default: true` in metadata. Names aren't validated locally; a bad name comes back as `DS_XLEDGER_INVALID_QUERY_ERROR`.
- `filter`: dict rendered as GraphQL literals (for example `{"modifiedAt_gte": "2024-01-01T00:00:00Z"}`). Supports `AND`/`OR` lists.
- `first`: page size. Defaults to metadata `pagination.first` (1000; 5000-10000 for some entrypoints). `after`/`before`/`last` are cursor controls.
- `limit`: total row cap across pages. A value <= 0 returns empty without a request.
- `owner_set`: `CURRENT|UPPER|LOWER|MINE|ALL`. `object_status`: `ALL|OPEN|CLOSED`.

Pagination follows `pageInfo.hasNextPage` and the last edge's `cursor`. A repeated cursor stops the loop.

## Incremental (checkpoint)

`supports_checkpoint` is true. Most read entrypoints declare `incremental` with `kind: time_field` on `modifiedAt` (filter `modifiedAt_gte`); `fromDate` is used once. These have none: accountBalances, apTransactions, arTransactions, assets, budgetBalances, countries, currencies, eInvoices, employeeBalances, expenseCodes, glImportItemErrors, transactions.

Once a checkpoint watermark exists, the provider removes your own clause on that filter field and ANDs in the watermark. The watermark advances only when the read exhausts all pages. A run cut short by `limit` keeps the cursor and resumes from it.

## Writes

- Input columns not in the operation's metadata fields are dropped. Nested inputs use `_`. NaN/None values are omitted.
- Rows from `update` need `dbId`; metadata marks it required, but this isn't enforced locally. `delete` sends the input `dbId` column as `dbIds`.
- `return_columns` selects the fields returned for create/update.
- Empty input is a no-op.

## Errors

GraphQL errors arrive as HTTP 200 with `errors` and are mapped to:

| Code | Meaning |
| --- | --- |
| `DS_XLEDGER_INVALID_QUERY_ERROR` (400) | Bad field/filter |
| `DS_XLEDGER_INVALID_MUTATION_ERROR` (400) | Bad mutation argument |
| `DS_XLEDGER_OUT_OF_CREDIT_ERROR` | No API credits |
| `DS_XLEDGER_CONCURRENT_REQUEST_ERROR` / `_BURST_REQUEST_ERROR` (429) | Reduce parallelism, back off |
| `DS_XLEDGER_TIMEOUT_ERROR` (408) | Narrow the filter or page size |
| `DS_XLEDGER_INCREMENTAL_FIELD_MISSING` (502) | Incremental field absent from nodes |
| `DS_XLEDGER_UNHANDLED_ERROR` | Anything unmapped |

## Fallback: plain HTTP dataset

For an entrypoint or mutation the package doesn't ship, use `ds.resource.dataset.http` with `method: POST`, `url: https://www.xledger.net/graphql`, and `json: {"query": ..., "variables": ...}`. HTTP linked service: `auth_type: APIKey`, `api_key: {name: Authorization, value: "token @{get_secret, <ref>}"}`. Secret refs are substituted inside strings. You own pagination and incremental logic.
