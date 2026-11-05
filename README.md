# Commons

Official AI Commons material for people and coding agents.

## Claude Code

```bash
claude plugin marketplace add grasp-labs/commons
claude plugin install commons@commons
```

The Claude plugin includes the Commons skills, MCP connection, authentication
helper and safety hook.

## Cursor and Codex

Clone this repository, then install the portable skills:

```bash
python3 install.py cursor
python3 install.py codex
```

Use `--project <path>` to install into one project instead of your user profile.

## Learning material

- `book/` — The AI Commons Book
- `courses/` — Course sources and course manifests
- `playbooks/` — Skills rendered as Commons gateway playbooks

Examples and helpers target production unless they explicitly select another
environment. Writes still require valid credentials, IAM permission, and
explicit approval.

This repository is generated from private Grasp Labs sources. Pull requests are
not merged here; report content issues to the platform team. Report security
issues as described in `SECURITY.md`.

Copyright © 2026 Grasp Labs. Proprietary; see `LICENSE`.
