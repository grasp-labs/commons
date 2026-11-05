---
name: commons-talk-to-data
description: Answer natural-language questions over governed Commons datasets with preview, text_to_sql and query. Use when building a conversational data agent, validating generated SQL, or explaining how Commons lets users talk to data.
---

# Talk to data safely

The three tools have separate jobs:

- `preview` reveals shape, counts and the dataset's SQL reference.
- `text_to_sql` drafts SQL from a question; it never executes.
- `query` executes reviewed, read-only DuckDB SQL and stores the full result.

## Sequence

1. Resolve the intended dataset under `/datasets/gold`. Do not choose from a
   similar name without confirming.
2. Call `preview` with `rows: 0`. Use rows only when the question requires a
   sample and policy permits it.
3. Ask `text_to_sql` with the user's question and explicit dataset paths.
4. Review the draft:
   - one `SELECT` or `WITH`;
   - only returned `sql_ref` table names;
   - explicit columns and bounded detail;
   - no sensitive dimensions unless requested and allowed;
   - correct units, date range, grain and null handling.
5. Call `query` with the same paths, reviewed SQL and `max_rows: 100`.
6. Answer with the result, filters, time range and dataset provenance. Distinguish
   an empty result from a tool failure.

For broad questions, aggregate first. Ask before returning identifiable rows.
Use `plot` only when a visual materially improves the answer.

## Agent instruction

> Never send generated SQL directly to query. First preview the selected
> dataset, validate the SQL against its schema and state the interpretation.
> Query only allowed dataset paths. Report the source, filters and time range,
> and never infer values that were not returned.

## Common failures

- Unknown table: use the exact `sql_ref` returned by `preview`.
- Wrong dataset: list Gold datasets and confirm the Facet.
- Too many rows: aggregate or tighten filters; do not raise limits by default.
- Stale result: retry with `fresh: true` only when freshness matters.
- Forbidden: the user's IAM or tenant tool grant does not permit that dataset.
