---
name: "ds-vault: secrets"
slug: ds-vault
domain: service
description: "Store, reference, rotate and retire AI Commons secrets in /vault: metadata-only reads, the secret key, the @{get_secret, <key>} placeholder resolved at run time, rotation, ACL, and status-only delete."
when_to_use: "Use when a workflow, linked service, event or MCP server needs a credential, when rotating or retiring a secret, or when a run fails because a secret does not resolve."
prefer_skills: []
related_tools: [ls, find, cat, write, rm, schema]
examples: []
---
Vault keeps tenant secrets encrypted. Models never read secret values. You create a secret, reference it from config by its `key`, and the platform resolves it when work runs.

## Reading: metadata only

`ls /vault` lists secrets. The filter is a case-sensitive name prefix, and soft-deleted rows are hidden. `cat /vault/<uuid>` reads one.

Responses never contain `value`. You get `name`, `status`, `store`, `key`, `acl`, `tags`, `metadata`, `owner_id` and audit fields. You cannot check what a secret contains; to verify one, run the thing that uses it.

## Creating

`write /vault` with:

| Field | Rule |
| --- | --- |
| `name` | Letters (incl. æøå), digits and spaces only, so `Visma API key` works but `visma-api-key` is rejected. |
| `status` | One of `active`, `draft`, `suspended`, `closed`, `rejected`, `deleted`. The tool schema also offers `inactive`; the service rejects it. Use `active`. |
| `store` | `ds_vault` (default choice) or `aws_ssm`. Nothing else validates. |
| `value` | **Base64 of the secret bytes**. Plain text that is not valid base64 is rejected; encode it first. |

Optional fields: `description`, `tags`, `metadata`, `owner_id`, `version` (semver), `acl`.

Name is not unique and there is no upsert. Search with `ls /vault/<name prefix>` before creating, so you do not leave duplicates.

The response carries the server-generated `key`:

```
/ds/vault/<store>/<tenant_id>/<secret_id>/<dev|prod>
```

That key, not the name or UUID, is what config references.

## Referencing from config

- In string settings (linked-service and dataset credentials, headers, bodies), use `@{get_secret, <key>}`. Spaces around the comma are allowed, and the key itself cannot contain spaces or `}`. Substitution happens inside any string leaf, so `"Bearer @{get_secret, <key>}"` works.
- In fields that ask for a vault key (event `settings.vault_ref`, MCP server `credential_ref`), use the bare key with no placeholder. MCP refs must belong to your tenant.

Resolution happens at dispatch: the dispatcher looks the key up, decrypts it, and base64-decodes it, so the worker receives the original text. The resolved value reaches the worker, never the model. A key that does not exist fails the run. Nothing checks a placeholder when config is saved.

See `ds-config` for where credentials go.

## Rotating

Write the new base64 `value` to `/vault/<uuid>`. It is re-encrypted under the same data key, and `key` does not change, so every reference keeps working and picks up the new value on its next run. Metadata-only writes (omit `value`) leave the ciphertext untouched.

Do not create a new secret to rotate: that changes the key, and every reference would need editing.

## Access (ACL)

- `acl.owners` / `acl.viewers` are lists of user subjects. The creator is always added as an owner.
- Viewers and owners can see the metadata. Only owners can update or delete; anyone else gets `not_found`.
- Setting `acl` replaces both lists. Include everyone who should keep access.

## Deleting

There is no hard delete. `rm /vault/<uuid>` (owner only) sets `status=deleted` and returns the final metadata.

- The secret disappears from `ls`, but `cat /vault/<uuid>` still returns it.
- An owner can restore it with `write /vault/<uuid>` `{"status": "active"}`.
- **Run-time resolution does not check status.** A deleted (or suspended) secret still resolves for any config that references its key.

To actually cut off a credential, do all three:

1. Revoke it at the provider.
2. Remove or replace the references in config.
3. Optionally overwrite `value` with a dummy before deleting.

## Pitfalls

| Symptom | Cause |
| --- | --- |
| `invalid base64 encoding` | Raw secret sent as `value` |
| `name` invalid | Hyphen, underscore, dot or slash in the name |
| Placeholder sent literally to the API | Misspelled placeholder, or whitespace inside the key |
| Run fails `Secret <key> not found` | Name or UUID used instead of `key`, or wrong environment suffix |
