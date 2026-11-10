---
name: "cat"
slug: "cat"
domain: "tools"
description: "Playbook for the cat tool: reading one identified resource verbatim, UUID addressing, file metadata vs paged content vs thumbnail, vault metadata-only reads, and the non-UUID routes."
when_to_use: "Read one identified resource verbatim, with no related context. Use info for the resource plus its context."
prefer_skills: []
related_tools: [cat, ls, find, grep, info, inspect, transcribe]
examples: []
---

`cat` reads a single resource at `/<service>/<type>/<id>`. One path in, one
envelope out: `{path, resolved_path, data | content | content_base64, _meta}`.

## Rules

- **Discover the UUID first.** KG nodes/edges, State records and jobs,
  Files, Vault and IAM rows are addressed by UUID; `cat` does not resolve
  names. Use `ls` with a filter/prefix, `find`, or `grep`, then `cat` the
  entry's `path`. A State `key` is a name, not an address.
- Files have three reads:
  - `/files/<uuid>` is the metadata record.
  - `/files/<uuid>/content` is the bytes, paged. Valid UTF-8 comes back in
    `content`, anything else base64 in `content_base64`. A page is bounded
    by the output budget (~15 KB). When `_meta.truncated` is set, call
    again with `offset` = `_meta.next_offset` until `_meta.eof`. The true
    MIME type and hash are in `_meta.content_type` / `_meta.content_sha256`.
  - `/files/<uuid>/thumbnail` is the preview image, always base64.
- Do not `cat` binary media expecting to understand it: use `inspect` for
  images, `transcribe` for audio/video.
- Vault returns metadata only; `value` is stripped from every response.
  Secret values are resolved at compute time, not read by models.
- A missing resource is `not_found`. Check the UUID came from a listing
  before concluding it is gone.
- `/config/llm/profiles/<uuid>/resolved` is the full resolved policy
  bundle, a separate resource from the raw profile at
  `/config/llm/profiles/<uuid>`.

## Non-UUID routes

- `/iam/principals/<principal_id>/policies`: the effective policy set for an
  IDP identity (e.g. `user:alice@example.com`), resolved server-side.
- `/state/jobs/statistics[/clone|pipeline|workflow]`: last-24h job counts.
- `/config/billing/tenant/<plan|account|credit/balance|credit/allocation>`:
  the caller tenant's single billing records.
- `/config/llm/catalogue|tool-stats/<tool_id>` and
  `/config/llm/skill-stats/<skill_id>`: keyed by id string, not UUID.
- `/mnt/<domain>/<path>`: a file on a trusted external mount (only when the
  tenant has mounted domains; `ls /mnt` lists them).

Default `format=yaml` costs fewer tokens; keep it unless a consumer needs JSON.
