---
name: GraphQL protocol
slug: graphql
domain: provider
description: Configure generic GraphQL datasets with ds-protocol-graphql-py-lib on top of an HTTP linked service.
when_to_use: Configuring a ds.resource.dataset.graphql (query or mutation, variables, operation name), discovering a GraphQL schema with list(), or diagnosing ReadError/CreateError/DeleteError/ListError and unexpected DataFrame shapes. Use the xledger provider for Xledger.
prefer_skills: []
related_tools: []
examples:
  - playbook/provider/examples/graphql-dataset.json
---

# GraphQL protocol

`ds-protocol-graphql-py-lib` (0.1.0-alpha.1) ships only `ds.resource.dataset.graphql`. It has no linked service of its own. Bind a `ds.resource.linked-service.http` (`host`, `auth_type` plus a matching auth block, secrets as `@{get_secret, <ref>}`). Example config: `playbook/provider/examples/graphql-dataset.json`.

Runtime check: `ds-workflow-manager` does not currently depend on this package. Confirm the runtime has it installed before configuring one; an unregistered type fails to deserialize.

## Model

Every operation POSTs `{query, variables?, operationName?}` to `settings.url` through the HTTP linked service's `requests` session. The HTTP linked service handles auth headers and urllib3 retries. Its token-bucket rate limit, default timeout and 401/403 mapping do not apply here, because the dataset calls `session.post` directly. `settings.url` and the linked service `host` are independent and never cross-checked.

| Op | Behaviour |
| --- | --- |
| `read` | POSTs `read.query` (+ `variables`, `operation_name`) |
| `create` | Sends one mutation for all rows. Empty input is a no-op. |
| `delete` | Sends one mutation keyed on `identity_columns`. Empty input is a no-op. |
| `list` | Fixed introspection over `__schema.queryType.fields` |
| `update`/`upsert`/`purge`/`rename` | `NotSupportedError` |

`supports_checkpoint` is false, so every read is a full load. Drive windows and pages through `read.variables`. `close()` is a no-op.

## Settings

- `url` (required): full endpoint.
- `headers`: sent on every call. Keep credentials on the linked service.
- `primary_keys`: declared but never read.
- `read`: `query` (required), `variables`, `operation_name`.
- `create`: `mutation`, `input_field` (both required), `operation_name`. It has no static `variables`.
- `delete`: `mutation`, `identity_columns` (required), `variables`, `operation_name`.

## Sharp edges

- **Single vs many.** Create sends `{input_field: row}` for one row and `{input_field: [rows]}` for two or more. Delete sends scalar identity values for one row and lists for several. A mutation typed `$input: X!` or `$id: ID!` passes with one row and fails with two. Make the type accept the batch shape, or pin the batch size upstream.
- `delete.variables` is merged after identity values, so a static key with the same name overrides the identity value.
- A missing identity column gives `DeleteError` "Identity column 'X' not found in input" with `available_columns`.
- GraphQL errors arrive as HTTP 200. Any top-level `errors` key fails the whole call, even when `data` is present, so partial results are discarded.
- Create/delete `output` is the deserialized `data`. If that's empty or absent, it falls back to a copy of `input`. A non-empty output doesn't prove a write.

## Deserialization (`response["data"]`)

| Shape | Rows |
| --- | --- |
| list | one per element |
| one root key -> list | one per element |
| one root key -> dict with `edges` | one per `edge.node` (Relay) |
| one root key -> dict whose only non-null value is one list | one per element |
| other single-root dict | one row |
| top-level `edges` | Relay nodes |
| anything else | one row |

Query exactly one root field per dataset; two root fields produce one row with one column per field. A wrapper like `{data: [...], meta: {...}}` stays one row. Only one level is unwrapped, so nested objects remain dict/list cells. Don't null the deserializer: read/create/delete raise "Deserializer is not configured".

## list()

Returns `name`, `type` (always `"query"`), `description`, `arguments` (comma-joined or null), `arg_count`. It covers queries only and needs introspection enabled; many production APIs disable it, giving a `ListError`. Ask for the SDL instead.

## Failures

| Symptom | Cause |
| --- | --- |
| `ConnectionError` "Session is not initialized" | HTTP linked service not connected |
| `ReadError` "GraphQL read settings must be provided in settings.read" | No `read` block |
| `ReadError` "GraphQL query failed: <first error>" | `errors` in response (full list in details) |
| `ReadError` "Failed to read from GraphQL: ..." | HTTP error (incl. 401/403), bad JSON, network |
| `CreateError` "GraphQL create mutation failed" | `errors` in response; check single/many shape |
| `CreateError` "GraphQL mutation must be provided..." / "Input field name must be provided..." | Empty `mutation`/`input_field` |
| `ListError` "Failed to list GraphQL schema resources" | Introspection disabled or rejected |
