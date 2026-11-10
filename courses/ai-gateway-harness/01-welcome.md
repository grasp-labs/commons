---
title: Welcome
---
# Course: the ds-ai-gateway harness

A plain-English course on what the AI Gateway harness is for, how it works, and
why it is built the way it is. Read the lessons in order; each builds on the one
before and ends with questions to check yourself.

| # | Lesson | You will understand |
|---|---|---|
| 1 | The vision | the problem, the bet, the principles |
| 2 | One request, end to end | what happens between "send" and the answer |
| 3 | Tools and discovery | how the model finds tools without seeing them all |
| 4 | Skills and playbooks | how proven work is reused |
| 5 | Memory | the ledger, session recall, and prompt caching |
| 6 | The self-improving loop | how the system gets better on its own |
| 7 | Governance and safety | what stops the model doing harm |
| 8 | External MCP servers | how tenant tools like Tripletex plug in |
| 9 | Ownership and failure | who owns what, and what breaks when |

## The running example

Every lesson follows the same people:

- **Acme AS** is a Norwegian accounting firm, a tenant on the platform.
- **Kari Nordmann** (`kari.nordmann@acme.no`) is an accountant at Acme.
- **Ola** is Acme's admin.
- Acme has connected **Tripletex**, its ERP, as an external MCP server.

Kari opens the chat in ds-client and types:

> "Find the September invoices for Globex in Tripletex and save a summary to our
> reports folder."

By the end of the course you will know everything that happens to that sentence.

## Where the detail lives

This course explains; it does not define. When you need the exact rule:

- `harness_design.md` — the authoritative design.
- `mcp_server_contract.md` — external MCP servers.
- ds-config `skill-contract.md` — the skill loop across services.
- `tool_service.md` — the ds-tools contract.
- `glossary.md` — short definitions.
