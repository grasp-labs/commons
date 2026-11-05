---
title: Tools and AI
---
# Tools and AI

All AI goes through the **gateway**. It picks allowed models and tools for your
tenant and calls them **with your identity**.

**The 20 tools**, grouped:

- **Navigate**: `ls` `find` `cat` `info` `grep`
- **Change**: `schema` `write` `rm`
- **Compute**: `run` `status`
- **Data**: `preview` `query` `text_to_sql` `plot`
- **Media**: `inspect` `extract` `transcribe` `frames` `generate_image`
- **Web**: `websearch`

**Use them from Cursor or Claude** by adding Commons as an MCP server:
`{{API}}/ai-gateway{{ENV}}/v1/mcp`.

**Playbooks** and **skills** teach the AI how to do platform tasks well.
