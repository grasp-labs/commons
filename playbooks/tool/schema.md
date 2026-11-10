---
name: "schema"
slug: schema
domain: tool
description: "Playbook for the schema tool: fetching the exact write contract before authoring a body, create vs update vs replace defaults by path, typed task, dataset and linked-service schemas, and secret and vault-reference markers."
when_to_use: "Before any write whose body shape you are not certain of. Returns the JSONSchema and a minimal example for a write operation."
prefer_skills: []
related_tools: [schema, write]
examples: []
---

`schema(path)` returns the request-body contract for `write` at that path.
The catalogue is compiled into the binary, so the call makes no network
request (Cost 1). Call it once per resource type per session and keep the
answer.

## Rules

- Use the same path convention as `write`, with plural config segments
  (`/config/workflows`, `/config/llm/models`, `/iam/groups`).
- The default operation follows the path:
  - Container paths (`/kg/nodes`, `/state`, `/files`, `/vault`,
    `/config/...`, `/iam/...`) default to `create`.
  - Identified paths (`…/<uuid>`) default to `update`.

  `update` has PATCH semantics (all fields optional). `replace` has PUT
  semantics (required fields enforced). KG nodes have no replace because
  their PUT already merges.
- Typed detail has two levels. For `/config/workflows/<uuid>/tasks`,
  `/config/datasets` and `/config/linked-services`:
  - Without `type`, you get the generic envelope (opaque `settings` + the
    type enum).
  - With `type` (short name like `io:read:dataset` / `postgresql`, or the
    dotted const like `ds.workflow.task.io.read.dataset`), you get that
    type's full settings contract, required fields and defaults.

  Always fetch the typed schema before authoring a task, dataset or linked
  service.
- Secret markers are part of the schema and are binding:
  - `format: "password"` marks raw secret material (vault `value`). Never
    echo it.
  - A `pattern` of `@{get_secret, …}` on a config credential field means the
    value must be a `@{get_secret, /ds/vault/…}` reference, never plaintext.
- File content is `{content}` for UTF-8 text or `{content_base64}` for
  binary, never both. `/files/<uuid>/content` and `/files/<uuid>/thumbnail`
  support only `operation=replace`. Thumbnails take `content_base64` +
  `content_type`.
- Create-only resources (IAM group-policy bindings, exam assignments) have
  no update schema. To change one, `rm` it and re-create it.

The failure this tool prevents: guessing a body, getting a 422, and burning
turns on retries. One `schema` call first is always cheaper.
