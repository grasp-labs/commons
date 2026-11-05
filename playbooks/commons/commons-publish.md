---
name: commons-publish
description: Publish content to Commons. Playbooks (ds-file plus KG node), courses (BFF /web-api/courses) and books (ds-file book/ prefix), privately or public via safe aic content plan/apply. Use when writing, uploading, updating or making public a playbook, course or book.
when_to_use: Publish content to Commons. Playbooks (ds-file plus KG node), courses (BFF /web-api/courses) and books (ds-file book/ prefix), privately or public via safe aic content plan/apply. Use when writing, uploading, updating or making public a playbook, course or book.
prefer_skills: []
related_tools: [write]
---

# Publish to Commons

File `https://grasp-daas.com/api/file[-dev]/v2`, KG `https://grasp-daas.com/api/knowledge-graph[-dev]/v1`,
app `https://dev.aic-project.com` | `https://aic-project.com`.

## Playbook (AI-discoverable guidance)

1. Markdown with frontmatter `name`, `description`, `when_to_use`, `prefer_skills: []`,
   `related_tools: [...]`; short body, link to the book for depth.
2. `POST /file/` `{"file_path": "playbook/<domain>/<slug>.md", "status": "active", "tags": {"kind": "playbook", "domain": "<domain>"}}`
   → `id`; then `PUT /file/<id>/content/` (`text/plain`).
3. `POST /node/` (required for discovery):
   `{"name": "playbook:<slug>", "type": "unknown", "status": "active", "rag_summary": "<description>", "content_type": "text/markdown", "uri": "dsfile://<id>", "external_id": "<id>", "tags": {"kind": "playbook", "domain": "<domain>"}}`.

Gateway models find it via `discover_tools` → `expand_tool`. Playbooks are ranked by outcome.

## Course

`POST {app}/web-api/courses` (Bearer), body `CourseSaveContract`: `name`, `slug`, `description`, `theme`, `status`,
`is_public`, `acl {owners: [≥1], viewers}`, `steps[{id, title, content_loaded: true, removed_column_ids: [],
columns: [{id, type: "markdown", content, width: 100, vertical_align: "top", image_alt: ""}]}]`,
`step_order`, `removed_step_ids`, `remove_cover: false`, `remove_background: false`.
Update with `PUT {app}/web-api/courses/{public_|tenant_}<slug>`; stored at `courses/<prefixed slug>/`.

## Book

One file per chapter: `book/<book>/<NN>-<chapter>.md`, tags `kind=book`, `book=<book>`.

## Public

`issuer: "public"` (file, node) and `is_public: true` (course) make content visible to **every
tenant**, and only a platform-tenant token may set them. Publish to your own tenant first
(`ISSUER=tenant`), review, then publish public. Never put tenant data in public content.

## Official Commons material

The generated `grasp-labs/commons` repository distributes the public plugin,
skills, book, courses and playbooks. Do not edit generated release files to
change platform content; update the managed source and publish a new version.
