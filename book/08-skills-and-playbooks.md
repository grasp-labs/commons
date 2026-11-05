# 8. Skills and playbooks

Three different things share the word "skill". Know which one you mean.

| | Platform skill | Playbook | IDE skill (Cursor / Claude) |
|---|---|---|---|
| What | Saved, parameterised tool trajectory | Markdown guidance for a task | Instructions for your local coding agent |
| Lives in | ds-config `/llm/skill/` | ds-file `playbook/<domain>/<slug>.md` + KG node | A portable `<name>/SKILL.md` package |
| Used by | Gateway models, as `skill_invoke_<id>` | Gateway models, via `discover_tools` → `expand_tool` | Cursor / Claude Code |
| Shared via | `issuer: "public"` | `issuer: "public"` on file and node | The `commons` Claude Code plugin |

## Platform skills

A skill is a recorded sequence of tool calls with parameters. The model calls it
once; the gateway expands the steps server-side.

```json
{
  "slug": "createfile",
  "name": "Createfile",
  "descriptions": {"en": "Upload a file: metadata to /files/, then bytes to /files/{id}/content/."},
  "parameters": [
    {"name": "file_path", "type": "string", "required": true},
    {"name": "encoding",  "type": "string", "required": true}
  ],
  "trajectory": {"steps": [
    {"id": "meta", "tool_id": "write",
     "inputs": {"path": "/files/", "body": {"file_path": "{{file_path}}", "status": "active"}},
     "bind_output_to": "meta"},
    {"id": "content", "tool_id": "write",
     "inputs": {"path": "/files/{{meta.data.id}}/content/", "body": {"content": "{{encoding}}"}}}
  ]},
  "required_tool_ids": ["write"],
  "lifecycle": "active"
}
```

Lifecycle: `draft` → `candidate` → `active` → `deprecated` / `rejected`. Only
`active` skills are discoverable; promotion needs `config:promoteSkill`.

Where skills come from: `admin` (hand-written), `model_proposed`, and
`auto_captured`. Conversations flow through `ds-skill-sink`, and
`ds-skill-autocapture` turns repeated read-only trajectories (used by at least
two users) into `candidate` skills for review.

Full example: `ds-ai-gateway/docs/examples/skill_upload_file.json`. Contract:
`ds-config/docs/llm/skill-contract.md`.

## Playbooks

A playbook tells a model **how to approach** a task: when to use it, which
skills and tools to prefer, and the steps. Format is SKILL.md-compatible:

```markdown
---
name: Build a datalake
description: Land a source system into bronze, transform to silver, publish gold.
when_to_use: User wants recurring, queryable data from an external system.
prefer_skills: []
related_tools: [schema, write, run, status, preview, query]
---
## Steps
...
```

Publishing takes two writes, and the second one is what makes it discoverable:

1. **File** in ds-file at `playbook/<domain>/<slug>.md`, tags `kind=playbook`,
   `domain=<domain>`.
2. **KG node** named `playbook:<slug>`, `type: unknown`, `status: active`,
   `uri: dsfile://<file_id>`, `external_id: <file_id>`, `rag_summary: <description>`.

For Commons-wide playbooks, set `issuer: "public"` on both, using a
platform-tenant token. The AIC Management UI does both steps for you;
`onboarding/publish.sh` does it from the command line.

Writing tips: lead with `when_to_use`, set `prefer_skills`, keep the body short
and link to the book for depth. Playbooks are ranked by outcome; one that does
not help sessions succeed will sink.

## The `commons` plugin for Claude Code

`onboarding/plugin/` is a Claude Code plugin. It is the single source for the
IDE skills, and `publish.sh` publishes the same skills as public playbooks, so Claude
users and gateway models learn from identical guidance.

| Part | What it does |
|---|---|
| Skills | `commons` entry point, safety and tool references, service guides, and task playbooks including Copilot, Prism, conversational data, datalakes, workflows and publishing |
| MCP server | Connects the Commons MCP endpoint; `scripts/auth.sh` mints and caches tokens from the keychain |
| Guard hook | Asks before `write`/`rm`/`run`, blocks secret writes and credential reads, and limits tenant data in Claude's context per `data_access` |

Install (Claude Code, once per machine):

```bash
claude plugin marketplace add grasp-labs/commons
claude plugin install commons@commons
```

Then store your OAuth client in the keychain and pick the environment and
`data_access` in `/plugin` (the `commons` skill walks through it). Requires `jq` and `curl`.

Cursor and Codex read the same skills. Clone `grasp-labs/commons`, then run:

```bash
python3 install.py cursor
python3 install.py codex
```

Use `--project <path>` to commit skills with a project. Cursor
uses `.cursor/skills/`; Codex uses `.codex/skills/`. The Commons MCP server is
configured separately as in chapter 7.

Read `commons-safety` before pointing Claude at tenant data. The skill tells the
agent *what* to do; MCP lets it *do* it; IAM and the guard bound *what it can see*.
