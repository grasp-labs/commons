# 4. The tools

20 tools, implemented in `ds-tools`, governed by `ds-ai-gateway`, granted per tenant
in Config (`/llm/profile/` → `allowed_tools`). You use them through an AI chat in
Commons, or through MCP in Cursor / Claude (chapter 7).

## The path model

Most tools operate on one virtual filesystem across services:

| Path | Backing service |
|---|---|
| `/config/...` | ds-config (datasets, workflows, pipelines, schedules ...) |
| `/files/...` | ds-file |
| `/state/...`, `/state/jobs/<uuid>` | ds-state |
| `/kg/...` | ds-knowledge-graph |
| `/datasets/...` | ds-fetch (lakehouse) |
| `/mnt/<mount>/...` | External mounts (e.g. GitHub) via `/llm/mount/` |

## The 20 tools

| Group | Tool | What it does |
|---|---|---|
| **Navigate** | `ls` | List children at a path |
| | `find` | `ls` with filters (`where`, tags, time) |
| | `cat` | Read one resource |
| | `info` | Resource + context (neighbours, jobs, previews) |
| | `grep` | Hybrid keyword + vector search over `/kg`, `/state`, `/files` |
| **Change** | `schema` | JSON Schema + example for a path — call before `write` |
| | `write` | Create or update at a path (approval required on many paths) |
| | `rm` | Delete at a path (approval required) |
| **Compute** | `run` | Fire a clone, workflow or pipeline (via ds-message) |
| | `status` | Poll a run (`/state/jobs/<uuid>`) |
| **Data** | `preview` | Dataset shape + up to 5 sample rows |
| | `query` | Run SQL on `/datasets/**` (ds-fetch) |
| | `text_to_sql` | Natural language → SQL (does not execute) |
| | `plot` | SQL or table → chart file in ds-file |
| **Media** | `inspect` | Ask a vision model about a file |
| | `extract` | Text from PDF (`pdftotext`) |
| | `transcribe` | Speech-to-text from audio/video |
| | `frames` | Video → still frames |
| | `generate_image` | Prompt → image in ds-file |
| **Web** | `websearch` | Public web search |

## Patterns that work

| Goal | Sequence |
|---|---|
| Understand something | `ls` → `info` → `cat` |
| Find something | `grep "<words>"` → `cat` |
| Create config | `schema` → `write` → `cat` to verify |
| Run and watch | `run` → `status` until `completed` / `failed` |
| Answer a data question | `preview` → `text_to_sql` → `query` → `plot` |
| Read a document | `extract` (PDF) or `inspect` (image) |

## Gateway meta-tools

When chatting through the gateway harness, the model also sees:

| Tool | Purpose |
|---|---|
| `discover_tools` | Find tools, active skills and playbooks |
| `expand_tool` | Load a tool schema, skill, or playbook body |
| `recall` | Recall earlier sessions of the same user |
| `skill_invoke_<id>` | Run a saved platform skill in one call |
| `mcp_<slug>__<tool>` | Tool from a tenant-registered external MCP server |

## Governance

- A tool is callable only if the tenant profile grants it **and** IAM allows the
  underlying service action with **your** token.
- `write`, `rm` and `run` ask for confirmation on sensitive paths.
- Every call emits a usage event for billing and skill mining.

Specs per tool: `ds-tools/docks/tools/<tool>.md`. Wire contract: `ds-go-tools-client`.
