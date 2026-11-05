---
name: commons-knowledge-graph
description: ds-knowledge-graph on Commons. Typed nodes, edges and evidence, hybrid keyword and vector search, RAG retrieval with hop expansion, and how playbooks are indexed. Use when modelling entities, searching knowledge, adding citations or retrieving context for an answer.
when_to_use: ds-knowledge-graph on Commons. Typed nodes, edges and evidence, hybrid keyword and vector search, RAG retrieval with hop expansion, and how playbooks are indexed. Use when modelling entities, searching knowledge, adding citations or retrieving context for an answer.
prefer_skills: []
related_tools: [ls, cat, info, grep, write]
---

# ds-knowledge-graph

`https://grasp-daas.com/api/knowledge-graph[-dev]/v1`. IAM: `knowledge-graph:<operationId>`
(`getNode`, `listNodes`, `searchNodes`, `graphRetrieve`, …).

## Model

| | Required | Types / fields |
|---|---|---|
| Node `/node/` | `name`, `type` | `asset`, `company`, `document`, `event`, `fact`, `location`, `person`, `root`, `unknown`; `body`, `content_type`, `uri`, `external_id`, `rag_summary`, `props`, `tags`, `status`, `issuer` (`tenant`\|`public`) |
| Edge `/edge/` | `source_id`, `target_id`, `type` | `owns`, `is_subsidiary_of`, `derived_from`, `is_basis_for`, `identical_to`, `alias_of`, `issued_by`, `unknown` |
| Evidence `/node/{id}/evidence/` | | Citations backing a node |

`GET /node/{id}/neighbour/` walks the graph. `GET /node/?name=&type=` lists.

## Find and retrieve

| Call | Use |
|---|---|
| `POST /search/` `{query, limit, hops, snippets, filters, min_similarity}` | Search nodes |
| `POST /graph/retrieve/` `{query, k, expand_hops, filters, min_similarity}` | RAG context with citations |
| `POST /graph/analytics/query/` | Graph analytics |

Tools: `grep {query, path: "/kg", hops, where: {types, trust_levels, issuers}, snippets: false}` to
scan cheaply, then `cat /kg/nodes/<id>`; `ls /kg/nodes`, `info` for neighbours.

## Write well

- One real-world thing = one node; reuse by `external_id` instead of duplicating.
- `rag_summary`: one or two plain sentences; it drives retrieval.
- `uri` points at the source (`dsfile://<file id>`, URL); add evidence for facts.
- Link with edges instead of repeating facts in text.
- `issuer: "public"` is visible to every tenant (platform tenant only).

## Playbooks

A playbook is a ds-file `playbook/<domain>/<slug>.md` plus a node `playbook:<slug>`
(`type: unknown`, `uri: dsfile://<id>`, `external_id: <id>`, `rag_summary`). The gateway finds it via
`discover_tools`. Publishing: `commons-publish`.
