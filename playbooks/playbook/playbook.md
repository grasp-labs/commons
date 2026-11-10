---
name: "Playbook"
slug: "playbook"
domain: "playbook"
description: "Author, validate, and publish AI Commons playbooks: format, limits, storage, discovery, and review rules."
when_to_use: "Use when creating, reviewing, publishing, or retiring a playbook, or auditing one against the authoring standard."
prefer_skills: []
related_tools: [write]
examples: []
---

# Authoring playbooks

A playbook is human-written guidance on how to approach a domain: trigger
conditions, sequencing, conventions, decisions, and pitfalls. A skill says what
to run and is auto-captured from a successful trajectory; a playbook says how to
think about it, is loaded into the model's context, and works on a fresh tenant
before any skill exists.

## Source of truth

Public playbooks are maintained from version-controlled source by the platform
team and published as a reviewed plan. Never edit a published public copy: the
next publication reverts it, and playbook files without a source are retired.
Tenant playbooks are written by the tenant itself (see "What gets published").

## File format

YAML front matter, then a Markdown body. Exactly these keys, all required, no
others:

| Key | Rule |
| --- | --- |
| `name` | Display name returned on load. |
| `slug` | Equals the file name stem; `^[a-z0-9]+([_-][a-z0-9]+)*$`; unique across all domains. |
| `domain` | Same pattern; groups the remote path. |
| `description` | One sentence. Becomes the ds-file description and the KG node `rag_summary`, the snippet discovery ranks and shows. |
| `when_to_use` | Concrete triggers, returned on load so the model can confirm fit. |
| `prefer_skills` | `llm_skill` slugs, resolved to load tokens on load. Unknown or unavailable slugs return a "not available to this tenant" note, so list only skills that exist. |
| `related_tools` | Declared AI Commons tool ids only (`ls`, `cat`, `write`, ...). |
| `examples` | Paths `playbook/<domain>/examples/<file>` in the playbook's own domain; each file must exist and its name be unique across playbooks. |

The body after the closing `---` must be non-empty and at most 4800 characters.
The AI Gateway clamps a loaded body at about 1200 tokens and appends a
truncation footer; validation rejects anything longer so guidance is never
silently cut.

## What gets published

A playbook is two records with the same issuer (`tenant` or `public`):

- ds-file `playbook/<domain>/<slug>.md`, tags `kind=playbook` and `domain`.
  Each example is a ds-file `playbook/<domain>/examples/<file>`, tag
  `kind=playbook-example`.
- KG node `playbook:<slug>`, type `unknown`, status `active`, `uri`
  `dsfile://<file-id>`, `external_id` the file id, `rag_summary` the
  description, and the same issuer.

The node is what makes a playbook discoverable. The KG has no `playbook` node
type; the `playbook:` name prefix is the discriminator.

## How the gateway serves it

- `discover_tools` searches the KG, keeps `playbook:`-named hits, and returns
  summaries only, never the body.
- `expand_tool` resolves the node, reads the body from ds-file under the
  caller's token, and returns `name`, `when_to_use`, `prefer_skills` (as
  tokens), `related_tools`, `examples`, and the clamped body. Other front
  matter keys are ignored on load.
- Examples are linked, never inlined; the model loads one with `cat` only when
  it needs the artifact.
- Visibility is enforced by ds-file and KG for the caller: `tenant` is private,
  `public` is platform-tenant published to every tenant.

## Writing the body

- Lead with when and why; the description and `when_to_use` decide whether
  it is found and loaded.
- Cover sequencing, decisions, conventions, and pitfalls. Do not restate API
  reference; name the endpoint, field, or command and let tools fetch details.
- Move large payloads, fixtures, and reference artifacts into `examples`.
- Every concrete claim (path, route, field, enum, limit, error code, version)
  must match current source code. Code beats docs. Drop what you cannot verify.
- Terse prose, no marketing, no duplication of another playbook.

## Review checklist

1. Front matter has exactly the eight keys.
2. `slug` matches the file name and is unique.
3. `prefer_skills` slugs exist; `related_tools` are real tool ids.
4. Examples exist and are referenced by their domain path.
5. Body is at most 4800 characters and states only verified facts.
6. Retire by removing both the file and the `playbook:<slug>` node.
