---
name: "write"
slug: "write"
domain: "tools"
description: "Playbook for the write tool: path decides create vs update, merge vs replace semantics, the no-upsert-by-name rule, one-call file writes, vault and config credential handling, soft-delete, and IAM grants as writes to a group."
when_to_use: "Create or update a resource. Never deletes (rm) and never bulk-writes (loop); most paths pause for user confirmation before executing."
prefer_skills: []
related_tools: [write, schema, ls, cat, rm, run]
examples: []
---

The path decides the operation:

- A container path (`/kg/nodes`, `/state`, `/files`, `/vault`,
  `/config/<type>`, `/iam/<type>`) **creates** a resource with a
  server-assigned UUID.
- An identified path (`…/<uuid>`) **updates** one.

The default update is a merge: unmentioned fields stay untouched.
`replace=true` is a full PUT that **clears** unmentioned fields, so use it
deliberately. KG nodes have no `replace`: their PUT already merges.

## Procedure

1. Call `schema(path)` if the body shape is not already in context.
2. To update by name (a state key, a file path, a vault name), discover the
   UUID first (`ls` prefix / filter), then write at `…/<uuid>`. **There is
   no upsert-by-name.** A write to a container always creates; it never
   finds and updates an existing resource with the same name.
3. Expect a pause. By default, writes to `/state`, `/kg`, `/files`,
   `/config` and `/vault` are P2: the user confirms a preview before the
   write executes. `/config/billing/**` and `/config/llm/**` are P3 (asynchronous sign-off).
   Batch your intent into fewer,
   well-formed writes.

## Rules

- Files take one call. `write /files` (create) or `write /files/<uuid>`
  (update) carries metadata plus the bytes inline: `content` for UTF-8
  text, `content_base64` for binary, never both. The limit is 10 MiB
  decoded per call. `file_path` is relative (no leading slash).
  - Metadata and content are two backing calls and the pair is not atomic.
    If the upload fails, retry only `write /files/<uuid>/content`.
  - Without bytes, the create response tells you to upload at
    `/files/<uuid>/content`.
- Config, KG edge and KG evidence merges are emulated as GET, merge, PUT.
  Concurrent edits to the same row can overwrite each other.
- Vault never echoes `value`, neither in the write response nor in any
  later read. To rotate a secret, write `value` at `/vault/<uuid>`.
- Config credential fields take vault references
  (`@{get_secret, /ds/vault/…}`), never plaintext. The schema marks them
  with a reference pattern, and the gateway rejects plaintext on gated
  writes.
- Soft-delete is a write: `{"status": "deleted"}` leaves a tombstone, which
  you can list with `ls … status=deleted` where supported. Hard delete is
  `rm`.
- Jobs are not written: `run`/`ingest` create them, so provenance stays
  honest.
- KG node names are unique per tenant. A duplicate create is a `conflict`
  that carries the existing node's id. The fix is usually to update that
  node, not to rename.
- IAM: granting access is always a write to a group, either adding a member
  (`/iam/members`) or binding a policy (`/iam/maps/group-policies`).
  Principals are never written. Bindings and exam assignments are
  create-only; to change one, `rm` it and create the pair you want.
- Read-only paths: `/mnt`, `/config/llm/profiles/<uuid>/resolved`,
  `/config/exams/attempts|certificates|principals`.
