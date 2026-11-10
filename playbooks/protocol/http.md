---
name: HTTP protocol
slug: http
domain: protocol
description: Configure HTTP linked services and datasets (ds-protocol-http-py-lib) for REST/JSON endpoints in workflows.
when_to_use: Use when a workflow must call a REST/JSON endpoint with no provider package, or when debugging auth, URL, pagination or parsing on a .http resource.
prefer_skills: []
related_tools: []
examples: [playbook/protocol/examples/http-examples.json]
---
# HTTP protocol

`ds.resource.linked-service.http` authenticates to a host; `ds.resource.dataset.http` makes the request and references it by `linked_service_id`. You supply URL, method and response shape; prefer a provider playbook when one exists. Shapes: `playbook/protocol/examples/http-examples.json`.

## Linked service

`host` (required), `schema` (`https`), `port`, `headers`, `auth_type` plus exactly one matching block:

| `auth_type` | Block fields | Behaviour |
| --- | --- | --- |
| `NoAuth` | — | nothing |
| `APIKey` | `api_key`: `name`, `value` | header `name: value` |
| `Basic` | `basic`: `username`, `password` | `Authorization: Basic …`; never pre-encode |
| `Bearer` | `bearer`: `token_endpoint`, `username`, `password`, `username_key_name` (`email`), `password_key_name` (`password`) | POSTs a JSON login body with those keys |
| `OAuth2` | `oauth2`: `token_endpoint`, `client_id`, `client_secret`, `scope`?, `data`? | form POST, `grant_type=client_credentials`; `data` adds form fields |
| `Custom` | `custom`: `token_endpoint`, `data` | POSTs `data` as JSON, form-encoded if linked-service `Content-Type` is non-JSON |

- Token flows run once per `connect()` (no refresh), take the first `access_token`/`accessToken`/`token` key anywhere in the JSON response, and set `Authorization: Bearer <token>`.
- Already hold a token: `APIKey` with `name: Authorization`. `Bearer` is a login.
- Linked-service `headers` apply to every request, token call included.
- Secrets: `@{get_secret, /ds/vault/...}`. ds-workflow-dispatcher substitutes it inside any string, so `"Bearer @{get_secret, …}"` works.
- `port` rewrites `base_uri` to `host:port` without scheme; only `test_connection` uses it, `read`/`create` use the dataset `url`.
- Fixed transport: 60 s timeout, 3 retries (backoff 0.2) on 429/500/502/503/504 for all methods incl. POST, `Retry-After` honoured, 10 req/s. 401 → `AuthenticationError`, 403 → `AuthorizationError`, other 4xx/5xx → `ReadError`/`CreateError` with the status.

## Dataset

`url` (absolute, `{name}` placeholders), `method` (`GET` default, `POST`, `PUT`, `PATCH`, `DELETE`), `params`, `headers`, `json`, `data`, `files` (multipart), `path_params`, `read`.

- Every placeholder needs a `path_params` key, else `Failed to resolve URL: missing path parameter`.
- Only `read` and `create` exist (one request each); others raise `NotSupportedError`. `output` is the deserialized body, or an empty DataFrame for an empty body.
- Deserializer default `json` (`pandas.read_json`) suits flat arrays; it fails on an all-scalar object. Otherwise use `semi-structured-json` (`pandas.json_normalize`) with `kwargs.record_path`, a string or list: `["data", "orders"]`. Without it an object becomes one row. Inspect a real response first.

## Pagination (`settings.read.pagination`, read only)

`strategy` (`offset` | `page_number` | `cursor`) plus the same-named nest, `items_path` (default `data`; `$` = root array), `max_pages`.

- `offset`: `offset_param` (`offset`), `limit_param` (`limit`), `page_size` (100), `total_path`.
- `page_number`: `page_param` (`page`), `page_size_param` (`per_page`), `start_page` (1), `total_pages_path`.
- `cursor`: `cursor_path` (required), `cursor_source` `body`|`header`, `cursor_param` (`cursor`).
- Values go to `query` by default (`inject_location`/`cursor_location`: `query`|`header`|`body`).
- Stops on empty page, short page (unless the total path resolves) or missing cursor. `items_path` only drives paging; each page still goes through the deserializer, so keep `record_path`.
- `read.incremental` (`param`, `watermark_path`, `location`) stores its watermark in `dataset.checkpoint`; ds-workflow-manager does not persist it, so it does not carry across runs.

## Runtime values (ds-workflow-manager)

- `ds.workflow.task.io.create.dataset` needs an input DataFrame; empty input sends nothing. Input is split by task `batch_size` (0 = one batch); each batch is one request. `$.column` strings in dataset settings or task `overrides` take the batch's first row. Per-row requests: `batch_size: 1`.
- `ds.workflow.task.io.read.dataset` has no input, so `$.` is not resolved. Pass runtime values through task `settings.overrides` with `#/variables/<name>`; overrides replace whole top-level settings keys (e.g. all of `path_params`).

## Common failures

| Symptom | Cause |
| --- | --- |
| 401 on data call | Wrong `api_key.name`, or missing `Bearer ` prefix in value |
| `Token is missing in the response…` | No `access_token`/`accessToken`/`token` key |
| `Bearer` login rejected | Key names differ from the API's login body |
| Same request repeated | `batch_size: 1` with a static body, or POST retried on 5xx |
| Runtime value sent literally | `$.` used in a read; use `overrides` + `#/variables/` |
