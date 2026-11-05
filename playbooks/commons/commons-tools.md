---
name: commons-tools
description: The 20 Commons tools (ls, find, cat, info, grep, schema, write, rm, run, status, preview, query, text_to_sql, plot, inspect, extract, transcribe, frames, generate_image, websearch) with their inputs, path model and proven call sequences. Use whenever calling Commons MCP tools or choosing between a tool and a REST call.
when_to_use: The 20 Commons tools (ls, find, cat, info, grep, schema, write, rm, run, status, preview, query, text_to_sql, plot, inspect, extract, transcribe, frames, generate_image, websearch) with their inputs, path model and proven call sequences. Use whenever calling Commons MCP tools or choosing between a tool and a REST call.
prefer_skills: []
related_tools: [ls, find, cat, info, grep, schema, write, rm, run, status, preview, query, text_to_sql, plot, inspect, extract, transcribe, frames, generate_image, websearch]
---

# Commons tools

Implemented in `ds-tools`, served by the gateway (MCP and chat), granted per tenant
(`allowed_tools`), executed with the caller's token so IAM applies end to end. In Claude Code they
are `mcp__plugin_commons_commons__<tool>`. Prefer a tool over raw REST: same result, governed,
audited, output budgeted.

## Path model

| Root | Backing | Children (leaf = `<uuid>`) |
|---|---|---|
| `/config` | ds-config | `workflows` (`/<id>/tasks/<id>`), `clones`, `datasets`, `linked-services`, `schedules`, `events`, `schemas`, `records`, `owners`, `tenants`, `vpn-connections`, `maps/{clone,workflow}-{events,schedules}`, `maps/workflow-task-dependencies`, `llm/{profiles,models,providers,tools,mounts,policy-tiers,rate-limit-tiers}` |
| `/datasets` | ds-fetch | `gold/<dataset-id>`, `silver/<pipeline-id>/<job-id>`, `bronze/<pipeline-id>/<job-id>` |
| `/files` | ds-file | `<id>`, `<id>/content`, `<id>/thumbnail` |
| `/state` | ds-state | `<id>` (key/value), `jobs/<id>` (runs) |
| `/kg` | knowledge graph | `nodes/<id>`, `nodes/<id>/evidence/<id>`, `edges/<id>` |
| `/vault` | ds-vault | `<id>` — metadata only, `value` is never returned |
| `/iam` | ds-iam | `actions`, `groups`, `members`, `policies`, `maps/group-policies`, `principals/<sub>/policies` |
| `/mnt` | external mounts | read-only (e.g. GitHub) |

Leaves are addressed by **UUID**, never by name: find ids with `ls`/`find` first.
Pipelines, pipeline maps, runtime profiles, `/llm/skill` and `/llm/mcp-server` have no tool path:
use REST (`commons-config`).
All tools accept `format: yaml|json` (default yaml, cheaper).

## Navigate

| Tool | Required | Useful options |
|---|---|---|
| `ls` | `path` | `filter`, `limit` (≤500, 50), `offset`, `order_by` (`-modified_at`), `status`, `long` |
| `find` | `path` | `name`, `type`, `status`, `owner`, `mtime`/`ctime` (`-7d`, `>2026-01-01`), `tag{}`, `where{}`, `limit`, `order_by` |
| `cat` | `path` | `offset` for `/files/<id>/content` paging (`_meta.next_offset` until `_meta.eof`) |
| `info` | `path` | Resource plus context (neighbours, recent jobs) |
| `grep` | `query` | `path` (`/kg` default, `/state`, `/files`), `limit` (≤50), `snippets`, `where{}`, `hops` (KG, ≤2) |

## Change (approval required)

| Tool | Required | Notes |
|---|---|---|
| `schema` | `path` | `operation` (`create`/`update`/`replace`), `type` for workflow task types. **Call before every `write`.** |
| `write` | `path`, `body` | Container path creates, `<uuid>` path updates (merge); `replace: true` = full PUT. `/mnt` read-only. |
| `rm` | `path` | One identified resource; containers cannot be removed. |

## Compute

| Tool | Required | Notes |
|---|---|---|
| `run` | `path` | `/config/{workflows,clones}/<uuid>`; optional `payload` (any JSON). Returns the job. For pipelines use REST (`commons-message`): the tool sends `pipeline_id`, which ds-message rejects. |
| `status` | `path` | `/state/jobs/<uuid>`; statuses `new`, `requested`, `dispatched`, `queued`, `running`, `completed`, `failed`, `cancelled`. |

## Data

| Tool | Required | Notes |
|---|---|---|
| `preview` | `path` | `/datasets/gold/<id>` or `/datasets/<silver\|bronze>/<pipeline>/<job>`. Shape, counts, `sql_ref`; `rows` 0–5 (use 0 by default). |
| `query` | `paths[]`, `sql` | One `SELECT`/`WITH` in DuckDB; reference tables by `sql_ref` (`gold."<uuid>"`); all paths share one root. `max_rows` (100, ≤1000), `fresh`. Full result stored as a file. |
| `text_to_sql` | `question` | `datasets[]`. Drafts SQL, does not execute. |
| `plot` | `x` | `sql`+`paths` or inline `data`; `y`, `t` (animate), `z` (`count(*)`, `sum(net)`…), `resolution`, `sort`, `normalize`, `tz`. Writes a chart file. |

## Media (files in `/files/<uuid>`)

| Tool | Required | Notes |
|---|---|---|
| `extract` | `path` | Text from PDF |
| `inspect` | `path` | `question` (≤1024 chars) to a vision model; also plot cells `/files/<id>/cells/<x.y.z>` |
| `transcribe` | `path` | Audio/video → text; `language` (BCP-47) |
| `frames` | `path` | `count` or `timestamps[]`; stores stills as new files |
| `generate_image` | `prompt` | `path` (`/files`), `aspect_ratio`, `seed`; stores a PNG |

## Web

| Tool | Required | Notes |
|---|---|---|
| `websearch` | `query` | `max_results` (≤10, 5), `search_depth` (`basic`\|`advanced`). Public web only. |

## Sequences that work

| Goal | Calls |
|---|---|
| Orient | `ls /` → `ls /config/workflows` → `info /config/workflows/<id>` |
| Find by meaning | `grep {query, path: "/kg", snippets: false}` → `cat` the hit |
| Create config | `schema {path, operation: "create"}` → `write` → `cat` to verify |
| Change config | `cat` → `schema {operation: "update"}` → `write` (merge) |
| Run and follow | `run` → `status /state/jobs/<job_id>` until `completed`/`failed` → `find /state/jobs {owner: <config id>}` for history |
| Answer a data question | `ls /datasets/gold` → `preview {rows: 0}` → `text_to_sql` → `query` (aggregate) → `plot` |
| Read a long document | `extract` (PDF) or `cat /files/<id>/content` with `offset` paging |

## Errors

`-32602 Unknown tool` = not granted to the tenant. `isError: true` = tool ran, but IAM or input
rejected it (message names the cause). `422` lists valid keys or columns. Output is truncated at the
tool's token budget; page or narrow instead of retrying.

Data safety rules for these tools: `commons-safety`.
