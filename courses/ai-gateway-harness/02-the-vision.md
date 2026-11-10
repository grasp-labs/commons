---
title: The vision
---
# Lesson 1 — The vision

## The problem

A language model can only use a tool it has been told about. "Telling it" means
putting the tool's name, description and input schema into the prompt, on every
turn.

Our platform has hundreds of capabilities: files, datasets, SQL, schedules,
workflows, the knowledge graph, and now every tenant's own systems through MCP
(Tripletex, GitHub, ...). Send all of them every turn and three things go wrong:

1. **Cost.** A few hundred tool schemas is 20–50k tokens before the user has
   said anything. Every turn pays it again.
2. **Accuracy.** Models choose worse from 300 options than from 8. More choice
   means more wrong choices.
3. **Growth.** Adding the 301st tool makes every conversation of every tenant
   slightly more expensive and slightly worse.

## The bet

The harness makes four bets.

**1. The model asks for what it needs.** Instead of seeing every tool, the model
sees three small "meta-tools" and uses them to search:

```
discover_tools("list invoices for a customer")   -> 5 short candidates
expand_tool(<token of the best one>)             -> that one tool, fully loaded
```

The cost of a turn now depends on what the conversation uses, not on how big the
catalogue is. The 1,000th tool costs nothing until someone needs it.

**2. Work that succeeded is the asset.** Every tool call is recorded with its
outcome. Over time the system knows which tools work for which intents, and which
sequences of calls solve whole tasks.

**3. Proven sequences become skills.** If many users at Acme run the same three
steps to build a monthly invoice report, that sequence becomes a *skill*. Next
time the model calls one tool, `skill_invoke_monthly_invoice_report`, and the
gateway runs the three steps itself. Three model turns become one.

**4. It gets better without anyone tuning it.** Outcomes feed rankings, rankings
decide what the model sees, what it sees decides outcomes. Lesson 6 covers this
loop.

## What the harness is, and is not

The harness sits inside the gateway, between the chat surfaces (OpenAI- and
Anthropic-compatible APIs) and the model and tool backends.

It **does**: discovery, narrowing what the model sees, running skills, gating
every tool call, recording outcomes, and remembering past sessions.

It **does not**: run tools itself (ds-tools and MCP servers do), own the database
schema (ds-config does), or store chat history (the client sends it each time).

## The principles, in plain words

These come from `harness_design.md` §2. Each one shows up again later.

| Principle | In plain words |
|---|---|
| The catalogue is never in context | The model never sees "all tools". |
| Stable prefix, volatile suffix | Put what never changes first in the prompt, so the provider can cache it. |
| At most 8 options at a time | Discovery returns ≤ 8 by default; the working set holds ≤ 8 tools. |
| Discovery is one verb | Tools, skills and playbooks are all found through `discover_tools`. |
| Outcomes are the asset | Rankings come from what worked, not only from descriptions. |
| Lexical first, vectors later | Keyword search (BM25) is enough today; embeddings come when justified. |
| Modes are knobs, not pipelines | `fast`, `adaptive` and `auto` configure one loop; they are not three codebases. |

## A before-and-after

Kari asks for the Globex invoices.

**Without the harness**, the prompt carries ~300 tool schemas. The model reads
them all, picks `search_invoices`, and the next turn carries all 300 again.

**With the harness**, turn one carries three meta-tools and whatever Acme's policy
pre-loaded. The model calls `discover_tools("search invoices by customer")`, gets
a short list where `mcp_tripletex__search_invoices` is first, loads it with
`expand_tool`, and calls it. Turn two carries the meta-tools plus that one tool.

If Acme has done this many times before, the first discovery may already offer a
skill that does "search invoices, summarise, save" in one call.

## Check yourself

1. Why does sending every tool every turn hurt accuracy as well as cost?
2. What is the difference between a tool and a skill?
3. Name two things the harness deliberately does *not* own.

<details><summary>Answers</summary>

1. Models pick worse from many options than from a few; more choice gives more
   wrong choices.
2. A tool is one capability executed by ds-tools or an MCP server. A skill is a
   saved sequence of tool calls the gateway runs for the model in one call.
3. Any two of: tool execution (ds-tools, MCP servers), the database schema
   (ds-config), chat history (the client).

</details>

Next: Lesson 2 — One request, end to end
