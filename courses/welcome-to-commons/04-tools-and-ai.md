---
title: Tools and AI
---
# Tools and AI

All AI goes through the **gateway**. It picks allowed models and tools for your
tenant and calls them **with your identity**.

**The 20 tools**, grouped:

- **Files**: `ls` `cat` `find` `grep` `write` `rm`
- **Data**: `query` `text_to_sql` `schema` `preview` `info`
- **Compute**: `run` `status`
- **Media**: `inspect` `extract` `transcribe` `frames` `plot` `generate_image`
- **Web**: `websearch`

Only `write`, `rm`, `run`, `frames` and `generate_image` change anything.

**Use them from Cursor or Claude** by adding Commons as an MCP server:
`{{API}}/ai-gateway{{ENV}}/v1/mcp`.

**Playbooks** and **skills** teach the AI how to do platform tasks well.
