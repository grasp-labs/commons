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

`INSTRUCTIONS.md` is the shared operating agreement for managers, key staff,
and engineers.

This repository is generated and released from the private Commons management
tooling in `grasp-labs/commons-control`. `aic distribution status` compares this
checkout with its source and `aic distribution sync` updates only the managed
paths. Neither command commits or pushes. Changes made directly here will be
replaced by the next sync.
