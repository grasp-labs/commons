---
name: commons-copilot-agent
description: Build a Microsoft Copilot Studio agent that uses the governed AI Commons MCP server to query DS-Fetch data, upload and inspect images, or extract exact text from PDFs. Use when designing, connecting, granting or testing a Copilot agent against Commons.
---

# Build a Copilot Studio agent for Commons

Copilot Studio sees the whole Commons MCP server as one `InvokeServer`
capability. The generative orchestrator chooses the underlying tool, so put the
required sequence and safety limits in the agent instructions.

## Connect

1. Start in **dev**. Add tool → Model Context Protocol → custom connector.
2. Server URL:
   `https://grasp-daas.com/api/ai-gateway-dev/v1/mcp`.
3. Prefer the existing, administrator-approved **AI Commons MCP** connector.
   Creating a connector may require solution registration and a DLP exception.
4. If a new connection is required, use manual OAuth 2.0 with a registered
   `authorization_code` client:
   - authorize: `https://auth-dev.grasp-daas.com/oauth/authorize/`
   - token/refresh: `https://auth-dev.grasp-daas.com/oauth/token/`
   - resource: `https://grasp-daas.com/api/ai-gateway-dev/v1`
5. Grant only the tools and paths the agent needs. The user must belong to
   `service.ai-gateway.user`; an empty `tools/list` means the tenant profile has
   no allowed tools.

Dynamic OAuth discovery is environment-dependent. Use it only after verifying
the full discovery, registration, tenant and audience flow; manual OAuth is the
reliable fallback.

## Recipe: answer questions from DS-Fetch

Grant `ls`, `preview`, `text_to_sql` and `query` on the required Gold datasets.
Put this sequence in the agent instructions:

1. Find the allowed dataset under `/datasets/gold`.
2. Call `preview` with `rows: 0` to obtain columns and `sql_ref`.
3. Call `text_to_sql` with the question and dataset path. It drafts SQL only.
4. Check that the SQL is one read-only `SELECT` or `WITH`, then call `query`
   with the dataset path and `max_rows: 100`.
5. Explain the result and name the dataset. Never invent missing rows.

## Recipe: upload and inspect an image

Grant `schema`, `write` and `inspect` on a narrow file prefix.

1. Call `schema` for `/files`.
2. Call `write` on `/files` with a relative `file_path`, `status: active`,
   `content_base64` containing the raw image bytes, and its content type.
3. Take the returned UUID and call `inspect` on `/files/<uuid>` with a precise
   question.

Copilot attachments are not automatically Commons files. If their bytes are
not available to the connector, upload through the Commons app or File API
first and pass the resulting file UUID.

## Recipe: get PDF text

Upload the PDF as above, then call `extract /files/<uuid>`. `extract` returns
the exact text layer without model interpretation. If the PDF is scanned and
has no text layer, call `inspect` instead. Long output is stored as a text file;
use the returned reference rather than repeating extraction.

## Acceptance test

- `tools/list` contains only the intended tools.
- A permitted dataset/file succeeds; another tenant or path is denied.
- The agent says which tool and source produced its answer.
- Writes require approval and no credential appears in prompts or transcripts.
