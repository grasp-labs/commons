---
name: SOAP protocol
slug: protocol-soap
domain: protocol
description: Configure SOAP linked services and datasets (ds-protocol-soap-py-lib, zeep) to call WSDL operations in workflows.
when_to_use: Use when a vendor exposes a WSDL (legacy ASMX/.NET services, e.g. Xledger file upload, 24SevenOffice), or when debugging auth or call failures on a .soap resource.
prefer_skills: []
related_tools: []
examples: [playbook/protocol/examples/protocol-soap.json]
---
# SOAP protocol

`ds.resource.linked-service.soap` loads a WSDL and authenticates; `ds.resource.dataset.soap` calls exactly one operation on it. REST/JSON: see **protocol-http**. Shapes: `playbook/protocol/examples/protocol-soap.json`.

Fetch the WSDL first: operation, parameter and type names are case-sensitive and cannot be guessed.

## Dataset

- `settings.method`: operation name as in the WSDL. `settings.kwargs`: business arguments only. Auth body params from the linked service are merged into every call; a duplicate key fails the call.
- `read` and `create` send the same call. Other operations raise `NotSupportedError`; express logical updates/deletes as named operations.
- Response → `zeep.helpers.serialize_object` → deserializer (default `semi-structured-json`). Set `deserializer.kwargs.record_path` to the repeating element (e.g. `["Records", "Record"]`), or the whole envelope is one row.
- `read`: `None`, `[]` or `{}` gives an empty DataFrame; failures raise `ReadError`. A null deserializer with a body raises `No deserializer configured for SOAP dataset`.
- `create`: no-op on empty `input`. `None` response or no deserializer → `output` is a copy of `input`; `[]`/`{}` → empty DataFrame.

## Linked service

`wsdl` (required), `auth_type` (case-sensitive) and exactly one block; leave others `null`.

| `auth_type` | Block: required (+optional) | Behaviour |
| --- | --- | --- |
| `Basic` | `basic`: `username`, `password` | HTTP Basic on transport |
| `BasicWithTokenExchange` | `basic_with_token_exchange`: `auth_wsdl`, `username`, `password`, `auth_method`, `credential_param_key` (+`auth_method_kwargs`) | Calls `auth_method(username, password, **auth_method_kwargs)` on `auth_wsdl` with Basic auth; injects `{credential_param_key: result}` into every call |
| `CookieSession` | `cookie_session`: `auth_wsdl`, `credentials` (+ options below, `auth_method_kwargs`, `session_check_method_kwargs`) | SOAP login on the data client's HTTP session; session cookie reused |
| `ParameterBased` | `parameter_based`: `auth_param_key1`, `auth_param_value1` (+ pairs 2, 3) | Pairs injected as body params; a pair needs both key and value or is dropped |

**Always set `auth_test_method`** (cheap, side-effect-free op; add `auth_test_method_params`). `connect()` calls it with the auth body params and raises `Connection test failed: …` on failure. If `null`, bad credentials surface only at the first data call.

### CookieSession

- `credential_type` (default `ns0:Credential`) goes to `zeep.get_type`; usually needs `{namespace}Type`, e.g. `{http://24sevenOffice.com/webservices}Credential`.
- `credentials` keys must match that type's fields (e.g. `ApplicationId`, `Username`, `Password`, `IdentityId`). `credential_param_name` defaults to `credential` (24SevenOffice: `requestCredential`). `auth_method` defaults to `Login`.
- Session id: the login result if it is a non-empty string, else cookie `cookie_name` (default `ASP.NET_SessionId`) from the auth host. It is then set for `cookie_domain` (default: `wsdl` host). Set `cookie_domain` when data and auth hosts differ.
- `session_check_method` (e.g. `HasSession`) returning `False` → `Cookie session validation failed`.

### Transport (zeep)

`timeout` 300 s, `operation_timeout` (falls back to `timeout`), `force_https` true (upgrades `http://` service addresses when the WSDL is on https), `forbid_entities`/`forbid_external` true, `forbid_dtd` false, `strict` true, `xml_huge_tree` false, `xsd_ignore_sequence_order` false, `extra_http_headers`. If a WSDL won't parse, relax `strict`, `xml_huge_tree` or `xsd_ignore_sequence_order`; keep HTTPS and entity guards on. No retry or rate limiting in the package; the create task's `retry`/`interval`/`backoff` retries failed batches.

## Secrets and runtime values

- Secrets: `@{get_secret, /ds/vault/...}`, substituted by ds-workflow-dispatcher inside any string.
- Create task: `$.column` in `kwargs` resolves from the first row of each batch (`batch_size`, 0 = whole input). One call per row: `batch_size: 1`. Read task: no `$.`; use task `settings.overrides` with `#/variables/<name>` (replaces the whole `kwargs`).

## Common failures

| Error | Cause |
| --- | --- |
| `Failed to reach the WSDL endpoint` | Wrong URL or blocked egress |
| `Failed to initialise SOAP client: …` | WSDL fetched but not parsed |
| `… auth settings are missing …` | Block for `auth_type` absent |
| `Credential exchange failed: …` | Wrong `auth_wsdl`/`auth_method`/credentials/kwargs |
| `Cookie session authentication failed: …` | Bad `credential_type`, `credentials` keys or `auth_method` |
| `SOAP call failed for method X: …` | Unknown `method`, kwargs mismatch, or key collision with auth params |
| Auth OK, calls fault | Wrong `credential_param_key`/`auth_param_key*` |
