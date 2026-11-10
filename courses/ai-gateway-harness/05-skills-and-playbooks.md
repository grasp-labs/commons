---
title: Skills and playbooks
---
# Lesson 4 — Skills and playbooks

Lesson 3 showed how the model finds one tool. This lesson shows how the system
reuses whole solutions: **skills** say *what to run*, **playbooks** say *how to
think about it*.

## Skills

### What a skill is

A skill is a saved recipe: a sequence of tool calls with blanks to fill in. It
is stored in ds-config (`llm_skill`), owned by a tenant.

Acme's month-end invoice report might be:

```json
{ "name": "Monthly invoice summary",
  "parameters": [
    { "name": "customer", "type": "string", "required": true },
    { "name": "month",    "type": "string", "required": true } ],
  "steps": [
    { "id": "find", "tool_id": "mcp_tripletex__search_invoices",
      "inputs": { "customer": "{{customer}}", "month": "{{month}}" },
      "bind_output_to": "invoices" },
    { "id": "save", "tool_id": "write",
      "inputs": { "path": "/reports/{{customer}}-{{month}}.md",
                  "content": "{{invoices}}" } } ] }
```

The placeholders:

- `{{customer}}` — a parameter the model fills in.
- `{{invoices}}` — the output of an earlier step (`bind_output_to`);
  `{{invoices.<field>}}` reaches a field inside it.
- Steps may have a small `conditional`, for example "only if `validation_sql`
  was given". Anything more complex should be a separate skill.

### How the model uses it

1. `discover_tools` returns the skill with its parameters, so the model can
   judge the fit before loading it.
2. `expand_tool` makes it callable as `skill_invoke_<skill_id>`, with the
   skill's parameters as its input schema.
3. The model calls it once:

   ```json
   skill_invoke_3f6c...({ "customer": "Globex", "month": "2026-09" })
   ```

4. The gateway runs every step itself. The model sees one result, not the steps.

That is the payoff: what took the model four turns to assemble the first time
now takes one call.

### Each step is still governed

Running a skill is not a back door. Every step goes through the same gates as a
tool the model called directly: the allowlist, plan posture, governance tiers,
rate limits, and recording (lesson 7). If a step fails, the skill stops and
returns one error.

If any step needs a P2 confirmation, the gateway asks **once, up front**, and
lists every governed step. The approval is tied to that exact skill *revision*,
so an edited skill needs a fresh approval.

### Only runnable skills are offered

A skill enters discovery only if **every** tool its steps use is in the catalogue
for this tenant. A skill that would rank well and then fail is worse than no
skill. When one is dropped for a missing tool, the gateway logs it.

### Lifecycle

```
draft -> candidate -> active -> deprecated
               \
                -> rejected
```

| State | Meaning | Discoverable? |
|---|---|---|
| `draft` | A skeleton, or a plan the model proposed (lesson 7) | No |
| `candidate` | Auto-captured, waiting for an admin | No |
| `active` | Promoted by an admin | **Yes** |
| `deprecated` | Superseded; old calls still work | No |
| `rejected` | An admin said no; never proposed again | No |

A skill gets its `origin` from how it was born: `admin`, `auto_captured` (by
ds-skill-autocapture, lesson 6) or `model_proposed`.

### Who can see a skill

Visibility uses the platform's standard pair: `tenant_id` and `issuer`. A skill
belongs to its tenant. Only the platform tenant can set `issuer = "public"`,
which makes it visible to every tenant. Acme's skills are never shown to
another tenant.

### Seeding: offering a skill before anyone asks

Discovery only helps if the model searches. Often it starts with tools already
loaded from the policy and does not search at all. So on the **first turn** of a
session, the gateway may pre-load up to **two** skills, matched against the
user's own words.

A skill is seeded only if it passes two tests:

1. **It is the best answer.** Its score beats every catalogue tool for this
   intent. Seeding costs tokens without being asked, so "somewhat relevant" is
   not enough.
2. **Its record helps.** Its score beats what the same skill would score with no
   history at all. A skill that has never run, or mostly fails, does not qualify.

Both tests reuse the ranker's own numbers (lesson 3), so there is no extra
threshold to tune.

Example: Kari writes "monthly invoice summary for Globex". The skill above has a
92% success rate over 40 runs and out-scores `query` and `search_invoices`. It is
seeded. Kari's first turn already contains `skill_invoke_3f6c...`, and the model
can solve the task in one call.

Seeding happens on the first turn only. Doing it every turn would keep refreshing
the skill's recency so it could never age out.

## Playbooks

### What a playbook is

A playbook is written by a person. It explains how to approach a domain: the
order of things, the conventions, the pitfalls, which skills and tools to prefer.

| | Skill | Playbook |
|---|---|---|
| Written by | captured from successful runs | a person |
| Says | what to run | how to approach |
| Runs how | the gateway executes the steps | the model reads it, then acts |
| Useful on day one | no, nothing captured yet | yes |

Playbooks solve the cold-start problem. A new tenant has no captured skills; a
playbook steers the model from day one. Those good runs are then captured as
skills (lesson 6).

### Where playbooks live

The text lives in ds-file under `/files/playbook/<domain>/<name>.md`, with a
short header:

```yaml
---
name: Month-end close in Tripletex
description: Steps to close a month for a client.
when_to_use: User asks to close, reconcile or report on a month.
prefer_skills: [monthly-invoice-summary]
related_tools: [mcp_tripletex__search_invoices, write]
examples: [examples/close-2026-08.json]
---
1. Check all invoices for the month are registered ...
```

The knowledge graph indexes it as a node named `playbook:<slug>`. `discover_tools`
asks the knowledge graph alongside the local search and merges the
results into one list. If the knowledge graph is slow or down, discovery still
returns tools and skills.

### Loading a playbook

`expand_tool` on a playbook token returns:

- the header, always complete;
- the body, cut to a size budget if needed, with a pointer to the full file;
- for each `prefer_skills` entry, a ready token, so the model can go straight
  from the playbook to `expand_tool` on the skill without searching again;
- example *paths*, never their content. The model opens one only if it needs it.

## Check yourself

1. A skill's second step needs the file id the first step creates. How does the
   skill express that?
2. Can a model use a skill to run a `write` that Acme's policy requires Kari to
   confirm, without asking her?
3. A candidate skill has a 100% success rate. Will discovery offer it?
4. Why does a new tenant benefit from playbooks more than from skills?

<details><summary>Answers</summary>

1. The first step sets `bind_output_to` (say `created`), and the second step
   uses `{{created.<field>}}`.
2. No. Every step goes through the normal gates. The P2 confirmation is asked
   once at the start of the skill and lists every governed step.
3. No. Only `active` skills are discoverable; an admin must promote it first.
4. A new tenant has no history, so nothing has been captured yet. A playbook is
   written by a person and works from day one.

</details>

Next: Lesson 5 — Memory
