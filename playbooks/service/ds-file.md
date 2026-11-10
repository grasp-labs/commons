---
name: "ds-file: files"
slug: ds-file
domain: service
description: "Store, organise, find and share AI Commons files in /files: metadata record vs content, path rules, uniqueness, tags, paging, platform path conventions, and ACL and issuer visibility."
when_to_use: "Use when uploading, organising, tagging, finding, sharing or deleting files, or when a /files write fails with validation, conflict, forbidden or not_found."
prefer_skills: []
related_tools: [ls, find, grep, cat, info, write, rm, inspect, transcribe, extract]
examples: []
---
A file is two things:

- a **metadata record** (`/files/<uuid>`: `file_path`, `status`, `version`, `tags`, `metadata`, `acl`, `issuer`, `content_type`, `content_sha256`, `etag`)
- **content** bytes (`/files/<uuid>/content`), plus an optional `/files/<uuid>/thumbnail`

A record can exist without content. Reading content before any upload is `not_found`.

## Writing

`write /files` creates the record and uploads the bytes in one call; `write /files/<uuid>` updates. See `write` for inline `content`/`content_base64` and the per-call size limit. The record and the upload are separate steps: if the upload fails, retry only the content.

- `file_path` is relative, like `reports/2026/q3.pdf`:
  - no leading or trailing `/`, no `//`, no `..`, no backslash
  - each segment at most 255 characters, from `A-Za-z0-9 ! - _ . * ' ( )` and spaces, not starting or ending with a space
- `(file_path, version)` is unique per tenant. A second create on the same path and version is a `conflict`. To replace a file, `ls` its path, then write to that UUID. To keep history, set a new `version` (semver, e.g. `v1.1.0`).
- The stored `content_type` comes from the path's extension, checked against the bytes; the upload header is ignored. Use the right extension, because it decides whether text is indexed for `grep` and how `inspect`, `transcribe` and `extract` treat the file.
- Before re-uploading, compare `content_sha256` with your bytes' SHA-256 and skip the upload if they match.
- `status` defaults to `active`. Allowed values: `active`, `draft`, `suspended`, `closed`, `rejected`, `deleted`.
- `ttl_seconds` (0 to 5 529 600, i.e. 64 days) is stored, but the file service does not act on it. Do not rely on it to expire anything.

## Finding

| Need | Use |
| --- | --- |
| Paths under a prefix | `ls /files/<prefix>`. The path is a prefix match, so `ls /files/reports/` lists everything below. The backing page default is 500 rows. |
| Exact tag or metadata values | `find /files` with `tag: {<key>: <value>}` (AND-combined) or `where.meta.<key>`. Tags and metadata are flat string-to-string maps, matched exactly. |
| Words in names, descriptions, tags or indexed text | `grep /files` |
| One record | `cat /files/<uuid>` |
| Bytes | `cat /files/<uuid>/content`, paged; see `cat` |

Use tags for facts you will filter on later: `kind`, `source`, `customer`, `period`. Write them at creation time, not afterwards.

Listings include `status=deleted` rows unless you filter on status. Add `status=active` when you want only live files.

## Visibility: tenant, ACL, issuer

- `acl.owners` / `acl.viewers` are user subjects. The creator is always kept as an owner.
- Reading needs owner or viewer; changing or deleting needs owner. `"*"` in viewers lets the whole tenant read; `"*"` in owners lets the whole tenant modify. Use it deliberately.
- Setting `acl` replaces both lists (the caller is re-added as owner). Include everyone who should keep access.
- `issuer` is stamped with the tenant's name and cannot be changed. Only the platform tenant can set `public`, which forces viewers to `"*"` and makes the file readable by every tenant.
- Other tenants can read public files but never modify them. A write or `rm` on one is `not_found`.
- IAM policies can also restrict by file path, so a create or rename into a path you lack rights to is `forbidden` even if the ACL would allow it.

## Platform path conventions

- `playbook/<domain>/` holds playbooks and their examples, tagged `kind=playbook` / `kind=playbook-example`.
- `book/` holds published platform documentation.

Nothing blocks writing there, but files under these paths take part in playbook and book publishing. Keep unrelated files out, and follow the `playbook` playbook when you do write a playbook.

## Deleting

- **Recoverable:** `write /files/<uuid>` `{"status": "deleted"}`. The record and bytes stay, and the file still appears in unfiltered listings.
- **Permanent:** `rm /files/<uuid>` removes the content, the thumbnail and the record. There is no undo, and content or a thumbnail cannot be deleted on their own.

## Pitfalls

| Symptom | Cause |
| --- | --- |
| `path must be relative` | Leading `/` in `file_path` |
| `invalid characters in segment` | Character outside the allowed set (e.g. `#`, `&`, `æ`), or a trailing space |
| `conflict` on create | Same path and version already exists; update that UUID instead |
| `not_found` on content | Record created but bytes never uploaded |
| Text file not found by `grep` | Extension is not a text type, or the bytes look binary |
