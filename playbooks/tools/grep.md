---
name: "grep"
slug: "grep"
domain: "tools"
description: "Playbook for the grep tool: content search across the three indexed roots, root-only scoping with where filters, KG hop expansion, verifying a hit before cat, cheap wide scans, and reading an empty result correctly."
when_to_use: "Content search: find resources by what they contain, not what they are named."
prefer_skills: []
related_tools: [grep, find, ls, cat, info]
examples: []
---

`grep` searches content across exactly three roots: `/kg` (default),
`/state` and `/files`. It returns scored matches with snippets so you can
verify a hit before paying for a `cat`.

## Rules

- Search the service **root** only. Sub-paths are a `validation` error.
  Narrow the search with `where` instead:
  - KG: `types`, `trust_levels`, `issuers`.
  - State: `key_prefix`, `tags`, `status`.
  - Files: `content_type`, `file_path_prefix`, `tags`, `status`.

  The backing service validates `where`.
- Config, Vault, IAM and `/mnt` have no content index (`validation` error).
  Use `find` on metadata there.
- Matching is keyword full-text, with vector ranking where the service
  provides it (KG). Keyword terms match best. Each match's `matched_via`
  names the methods that fired.
- Verify before drilling in: read the snippet and score, then `cat` the
  match's `path` (a UUID path, ready to use).
- KG only: `hops` (0 to 2) expands each hit along graph edges. Expanded
  matches carry `hop` and `via_path` and list `expansion` in
  `matched_via`.
- Cheap wide scan: `snippets=false` returns only path, name and score. Use
  it to map a topic (`limit` maximum 50, default 10) before a focused pass
  with snippets. `_meta.has_next` says whether more results scored.
- Empty `matches` means nothing scored. It does not show the data is absent
  under different wording or outside a filter you set. Rephrase or loosen
  `where` before concluding something is absent.

## Cost

Cost 3 (ls 1, find 2). Prefer `ls`/`find` when a name or metadata field
already identifies the target.
