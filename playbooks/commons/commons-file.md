---
name: commons-file
description: ds-file on Commons. Upload, version, tag, search, download and share files and documents, and read PDFs, images, audio and video with the media tools. Use when storing or reading any file, document or generated artifact on Commons.
when_to_use: ds-file on Commons. Upload, version, tag, search, download and share files and documents, and read PDFs, images, audio and video with the media tools. Use when storing or reading any file, document or generated artifact on Commons.
prefer_skills: []
related_tools: [ls, find, cat, info, grep, write, rm, inspect, extract, transcribe, frames, plot, generate_image]
---

# ds-file

`https://grasp-daas.com/api/file[-dev]/v2`. Metadata in Postgres, bytes in S3. Unique on
`(tenant, file_path, version)`. IAM: `file:<operationId>` on `crn:aic:*:file::file:<file_path>`
(path-addressed, so `reports/**` scoping works).

## Upload (two steps)

```bash
F=https://grasp-daas.com/api/file-dev/v2
ID=$(curl -s -X POST "$F/file/" -H "Authorization: Bearer $COMMONS_JWT" -H "Content-Type: application/json" \
  -d '{"file_path": "reports/2026/q3.pdf", "status": "active", "tags": {"kind": "report"}}' | jq -r .id)
curl -s -X PUT "$F/file/$ID/content/" -H "Authorization: Bearer $COMMONS_JWT" \
  -H "Content-Type: application/octet-stream" --data-binary @q3.pdf
```

Body limit 64 MB. Required on create: `file_path`, `status`. Optional: `description`, `tags`,
`metadata`, `acl`, `ttl_seconds`, `version`, `issuer`.

## Read, change, find

| Call | Use |
|---|---|
| `GET /file/?file_path=&file_path_prefix=&tag.<k>=&meta.<k>=&status=` | List / filter |
| `GET /file/{id}/` | Metadata (`content_type`, `content_sha256`, `etag`) |
| `GET /file/{id}/content/` | Download (`Range` supported) |
| `PATCH /file/{id}/` (+ `If-Match: <etag>`) | Update metadata safely |
| `PUT /file/{id}/` | Full replace of metadata |
| `POST /search/` `{query, filters, limit, snippets}` | Full-text over content and metadata |
| `DELETE /file/{id}/` | Delete |

Skip re-uploads when `content_sha256` already matches. Reserved prefixes: `playbook/`, `courses/`,
`book/`. `issuer: "public"` (platform tenant only) makes a file readable by every tenant.

## Tools

`ls /files`, `find /files {tag: {kind: "report"}, mtime: "-7d"}`, `cat /files/<id>` (metadata),
`cat /files/<id>/content` (paged by `offset`), `grep {path: "/files", query}`. Media:
`extract` (PDF text), `inspect` (vision Q&A), `transcribe` (audio/video), `frames` (video stills).
`plot`, `generate_image` and large `query` results land here as new files.

Reading content puts it in the model's context: with sensitive documents, prefer `info` and targeted
`grep` over full `cat` (`commons-safety`).
