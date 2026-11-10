---
title: Tools and discovery
---
# Lesson 3 — Tools and discovery

How does the model find `search_invoices` among hundreds of tools without ever
seeing the list? This lesson covers the three layers, the two discovery verbs,
the working set, and ranking.

## Three layers

Think of a library.

| Layer | Library picture | What it is | Model sees it? |
|---|---|---|---|
| 0 | The catalogue desk | Three meta-tools: `discover_tools`, `expand_tool`, `recall` | Always |
| 1 | The books on your table | The *working set*: tools loaded for this conversation | Yes, once loaded |
| 2 | The stacks | The full catalogue: ds-tools plus the tenant's MCP tools | Never |

Layer 0 is identical for every tenant and every conversation, which is what makes
it cheap to cache (lesson 5). Layer 2 lives behind ds-tools; the gateway keeps a
local copy, synced every 5 minutes, so search never waits on the network.

## The two verbs

### `discover_tools` — search

The model describes what it wants to do, in its own words:

```json
{ "intent": "search invoices by customer and date range", "k": 5 }
```

and gets short results back:

```json
{ "results": [
    { "type": "tool",  "id": "mcp_tripletex__search_invoices",
      "summary": "Search invoices by customer and date range.",
      "tags": ["tripletex", "mcp"], "confidence": 0.91,
      "stats": { "success_rate": 0.97, "invocations": 412 }, "token": "tk_1f2a..." },
    { "type": "skill", "id": "skill_invoke_3f6c...",
      "summary": "Monthly invoice summary for one customer, saved to reports.",
      "parameters": [{ "name": "customer", "type": "string", "required": true },
                     { "name": "month", "type": "string", "required": true }],
      "confidence": 0.88, "token": "tk_77b0..." },
    { "type": "doc",   "id": "playbook:month-end-close",
      "summary": "How Acme closes a month in Tripletex.",
      "when_to_use": "User asks about month-end tasks.", "confidence": 0.52, "token": "tk_9e1c..." } ],
  "total_candidates": 6 }
```

Things worth noticing:

- **One search covers everything:** tools, skills and playbooks. There is no
  filter, because the model does not know which kind will solve its problem.
  That is what it is asking.
- **Results are cheap.** Summaries are cut to 160 characters. No schemas yet.
- **`k` is 8 by default, at most 12.**
- **`total_candidates`** tells the model whether a narrower intent might find
  more.
- **The `token`** is what the model hands to `expand_tool`. It is single-use,
  expires in 10 minutes, and only works in this session.

### `expand_tool` — load

```json
{ "token": "tk_1f2a..." }
```

For a tool, the answer is:

```json
{ "tool_id": "mcp_tripletex__search_invoices", "loaded": true,
  "working_set_size": 3,
  "working_set": ["query", "write", "mcp_tripletex__search_invoices"],
  "evicted": null }
```

From the next turn on, the model sees that tool's full schema and can call it.

For a skill, `expand_tool` registers a callable `skill_invoke_<id>` tool. For a
playbook, it returns the guidance text. Lesson 4 covers both.

Possible errors: `token_expired`, `tool_not_found` (it left the catalogue), and
`tool_too_large` (see the budget below).

## The working set

The working set is the "books on your table": what the model can call right now.
It has two limits.

**A count limit, per class:** 8 catalogue tools and 2 skills. They are counted
separately because a skill's schema is tiny (~60 tokens) while a tool's is often
300+. If they shared one cap of 8, two cheap skills could push out two tools the
tenant explicitly granted.

**A token limit:** the catalogue tools shown in one turn must fit in about
8,000 tokens (description + schema, estimated at 4 characters per token). This
matters for MCP tools. A curated ds-tools schema is small; an MCP tool may carry
up to 2 KiB of description and 8 KiB of schema. Eight of those would put ~20k
tokens in every turn.

**When a class is full,** the *least recently used* member of that class is
dropped. Recency starts when a tool is loaded and is refreshed each time it is
actually called. So a tool loaded long ago and never called is the first to go.

**When the token budget is full,** the model sees the most recently used tools
that fit. An older tool that does not fit is *hidden*, not dropped, and leaves
by count later. The `working_set` field in the `expand_tool` answer always shows
exactly what the model will see.

**A tool too big for the whole budget on its own** is refused (`tool_too_large`)
and never seeded. One giant tool cannot push out everything else.

### Example: the budget at work

Acme's working set holds `query` (400 tokens), `write` (300) and three
Tripletex tools of 2,500 tokens each. From oldest to newest use:
`register_hours`, `query`, `write`, `search_invoices`, `list_projects`.

```
budget 8,000, walked newest first      running total
  list_projects     2,500   shown        2,500
  search_invoices   2,500   shown        5,000
  write               300   shown        5,300
  query               400   shown        5,700
  register_hours    2,500   hidden       8,200 > 8,000
```

The walk goes from newest to oldest and stops at the first tool that does not
fit, so an older tool never jumps ahead of a newer one. If Kari calls
`register_hours` again, it becomes the newest and comes back into view, and the
oldest of the others is hidden instead.

### Where the working set lives

In Valkey (Redis), shared by all gateway replicas, keyed by tenant and session.
It expires on its own after the conversation goes idle. Adding a tool and
evicting the oldest is one atomic Lua script, so two turns racing on the same
session cannot let the count drift above the cap.

## Ranking: who comes first

Search has two stages.

### 1. Keyword match (BM25)

BM25 is a classic search score. A query word that is **rare** across the
catalogue counts for more than a common one, and a word in the tool's **name**
counts for more than one in its **tags**, which counts for more than one in its
**description** (boosts 3, 2, 1).

Tools and the tenant's skills are indexed together, as one corpus. That matters:
a skills-only index of a dozen rows makes every word look equally rare, and the
scores become meaningless.

A candidate must pass a minimum keyword score. A popular tool is never offered
for an unrelated intent just because it is popular.

### 2. The blend

Candidates that pass are scored on four signals, each between 0 and 1:

| Signal | Default weight | Meaning |
|---|---|---|
| Lexical | 0.35 | How well the words match. Picks candidates; does not decide among them. |
| Success | 0.40 | How often it worked for this tenant, leaning on all tenants' record while this tenant has few runs. The biggest weight. |
| Recency | 0.05 | How recently it was used. Small, so new skills are not punished for being new. |
| Priority | 0.20 | An admin boost. The neutral setting (0) scores 0.5. |

`score = (0.35·lexical + 0.40·success + 0.05·recency + 0.20·priority) / sum of weights`

Dividing by the weight sum keeps every score between 0 and 1, so tools, skills
and playbooks can be sorted in one list. The weights live in ds-config
(`llm_ranker_config`) and reload within a minute, so tuning is an operational
change, not a release.

**Cold start.** A tool or skill with no history at any tenant gets a success score of 0.7. High
enough that new things stay competitive until they have their own record.

### Example: two tools, one intent

Kari's intent: "monthly invoice report for a customer".

| | `query` (generic SQL) | `skill_invoke_monthly_invoice_report` |
|---|---|---|
| Lexical | 0.40 | 0.85 |
| Success | 0.95 | 0.92 |
| Recency | 1.0 | 0.6 |
| Priority | 0.5 (neutral) | 0.5 (neutral) |
| Score | (0.14 + 0.38 + 0.05 + 0.10) / 1.0 = **0.67** | (0.30 + 0.37 + 0.03 + 0.10) / 1.0 = **0.80** |

The skill wins: it matches the words better and has a proven record.

## Languages

Descriptions are stored per language (`{"en": ..., "no": ...}`). Today search
reads the English text (or any language present when English is missing);
choosing the caller's language is not wired yet. Keyword search handles short
Norwegian and English queries well without needing a multilingual embedding
model; vectors may come later as an extra signal.

## Check yourself

1. Why are tools and skills capped separately in the working set?
2. A tool was loaded 5 turns ago but never called. A ninth tool is loaded. Which
   is evicted?
3. An MCP tool estimates at 9,000 tokens. What happens when the model tries to
   load it?
4. Why must a candidate pass a keyword minimum even if its success rate is 99%?

<details><summary>Answers</summary>

1. Skills cost ~60 tokens and tools ~300+. One shared cap would let cheap skills
   push out tools the tenant granted.
2. That one, unless another tool was loaded or last called even earlier:
   eviction is by last use, which is the load or the latest call.
3. `expand_tool` answers `{"loaded": false, "error": "tool_too_large"}`. It
   alone exceeds the ~8k budget, so it is never loaded or seeded.
4. So a heavily used tool is not dredged up for an unrelated intent. Relevance
   first, then quality.

</details>

Next: Lesson 4 — Skills and playbooks
