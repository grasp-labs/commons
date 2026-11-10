---
name: "ds-knowledge-graph: the knowledge graph"
slug: ds-knowledge-graph
domain: service
description: "Playbook for the knowledge graph: nodes, edges and evidence, name/external_id/uri uniqueness, keyword search and hop expansion, tenant versus public scope, and the playbook node convention."
when_to_use: "Recording or looking up entities, documents, facts and their relations under /kg, attaching provenance, deduplicating nodes, searching the graph, or reasoning about why a public or playbook node is or is not visible."
prefer_skills: []
related_tools: [grep, find, ls, cat, info, write, rm]
examples: []
---

The KG stores **nodes** (things), **edges** (typed relations between two
nodes) and **evidence** (provenance attached to a node). Everything is
addressed by UUID: `/kg/nodes/<uuid>`, `/kg/edges/<uuid>`,
`/kg/nodes/<uuid>/evidence[/<uuid>]`, `/kg/nodes/<uuid>/neighbours`.

## Nodes

- Required: `name`, `type`. Types: `asset`, `company`, `document`,
  `event`, `fact`, `location`, `person`, `root`, `unknown`. There is no
  custom type; put the discriminator in `props.kind` and keep key names
  consistent per kind.
- `props` is free JSON (max 4 MiB). `metadata` and `tags` are flat string
  maps. `body` is primary content (default `text/markdown`, up to 1 Mi
  characters); `uri` is a resolvable address.
- `status` defaults to `active`; `issuer` to `tenant`.
- `trust_level` (`unknown`, `user`, `community`, `partner`, `official`,
  `peer_reviewed`, `internal`) and `confidence` (0-1) are yours to set.
  Adding evidence does not change them or `evidence_count`.

## Uniqueness and dedup

- Unique per tenant: `name` (exact, case-sensitive), `external_id`, and
  `uri`. A duplicate create is `409` and the error's `reference_id` is
  the existing node: reuse it instead of retrying with a new name.
- Before creating, check: `find /kg/nodes` with `name` (case-insensitive
  substring), or `where` with `external_id` / `uri` (exact).
- Use stable identifiers (registry number, URL, file id) as
  `external_id` so repeated ingestion converges on one node.
- Edges are unique per (source, target, type) and cannot be self-loops.
  Edge types: `owns`, `is_subsidiary_of`, `derived_from`, `is_basis_for`,
  `identical_to`, `alias_of`, `issued_by`, `unknown`. Record duplicates
  you cannot merge with `identical_to` or `alias_of`.

## Writing

- `write /kg/nodes` creates; `write /kg/nodes/<uuid>` merges (omitted
  fields stay; `props`, `tags`, `metadata` are replaced whole, not deep
  merged). There is no replace mode.
- Updating a node without resending `rag_summary` degrades its search
  text to the first line of the old summary. Resend it on every update.
- `write /kg/edges` with `source_id`, `target_id`, `type`.
- `write /kg/nodes/<uuid>/evidence` with `source_type` (`user_input`,
  `official_dataset`, `web`, `pdf`, `api`, `internal_etl`), `source_ref`
  (dataset id, URL, doc id), optional `quote`, `locator`, `score`. The
  subject is the node in the path.
- `rm /kg/nodes/<uuid>` is permanent and cascades to its edges and
  evidence. Prefer `status: closed` or `deleted` when history matters.

## Searching

- `grep path=/kg` is keyword full-text over name, type, uri,
  external_id, `rag_summary`, the first 4,096 characters of `body`,
  metadata, tags and props values. English stemming; every term must
  match, so use a few distinctive words. `limit` max 50.
- `where`: `types`, `trust_levels`, `issuers`, `status_active_only`.
  Without `status_active_only: true` closed and deleted nodes can match.
- `hops` (0-2) adds neighbours of each hit, marked `expansion` in
  `matched_via`.
- Vector search exists only when the caller supplies a 1536-dim
  embedding; the tools do not, so `grep` is keyword-only.
- `info /kg/nodes/<uuid>` returns the node with neighbours;
  `ls /kg/nodes/<uuid>/neighbours` pages them.

## Tenant and public scope

- Reads return your tenant's rows plus every row with `issuer: public`.
  Writes and deletes touch only your tenant's rows.
- Only the platform tenant can set `issuer: public` (`403` otherwise).
  Public content is platform-published; do not try to edit it.
- Name uniqueness is per tenant, so a tenant node may share a name with
  a public node. Check `issuer` on hits.
- An edge is visible if it is yours or both its ends are public nodes.

## Playbook nodes

A playbook is a node named `playbook:<slug>`, type `unknown`, `uri`
`dsfile://<file-id>`, `external_id` the file id, `rag_summary` its
description. The name prefix is the only discriminator. Gateway
discovery searches the KG and keeps `playbook:` hits; `skill:` and
`session:` are other load prefixes. Never create `playbook:` nodes by
hand; authoring and publishing are in the `playbook` playbook.

## Pitfalls

- `name` is not an address: `cat /kg/nodes/<name>` fails; find the UUID.
- `ls /kg/edges` has no name filter; use `find /kg/edges` with `where`.
- Deleting a hub node silently removes all its relations.
