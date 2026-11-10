---
title: Talk to governed data
image: assets/talk-to-data.png
image_alt: A natural-language question is grounded with preview, drafted as SQL, reviewed, executed with query and returned with provenance.
---
# Natural language, reviewed SQL

The tools deliberately separate understanding, drafting and execution:

1. `preview {rows: 0}` supplies the real columns, history mode and SQL reference.
2. The agent drafts one read-only query; `text_to_sql` does this only for
   callers with no model of their own and never runs it.
3. The agent checks tables, columns, grain, filters, units and sensitive fields.
4. `query` executes the reviewed SQL against the same dataset paths.
5. The answer names its dataset, filters and time range.

Aggregate first. Ask before returning identifiable rows. An empty result means
“no matching data,” not “the tool failed.”
