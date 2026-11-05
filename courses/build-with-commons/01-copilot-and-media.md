---
title: Copilot, files and media
image: assets/copilot-media-flow.png
image_alt: Microsoft Copilot connects through Commons MCP to query data, upload files, inspect images and extract PDF text.
---
# Give Copilot governed Commons capabilities

Copilot Studio connects to the Commons gateway as one MCP capability. IAM and
the tenant tool profile decide what its users can access.

**Data answers**

`preview {rows: 0}` → `text_to_sql` → review → `query`

**Image understanding**

`schema /files` → `write /files {content_base64}` → `inspect /files/<id>`

**Exact PDF text**

Upload the PDF, then `extract /files/<id>`. Use `inspect` instead when a scanned
PDF has no text layer.

Start in dev, prefer the approved AI Commons MCP connector, and grant only the
tools and paths required by the agent.
