---
name: "plot"
slug: "plot"
domain: "tools"
description: "Playbook for the plot tool: turning a lakehouse statement or a held table into a stored visual, the x/y/t axis and z aggregate grammar, resolution and frames, normalisation, and reading the result."
when_to_use: "A user wants a chart, heat map, time series or animated view of lakehouse data, or of a table you hold. Explaining the visual afterwards is inspect's job."
prefer_skills: []
related_tools: [plot, query, preview, inspect, cat]
examples: []
---

`plot` turns a table into a grid of `x` × `y` cells, optionally animated
over `t`, each cell one aggregate `z` of its rows. The visual is stored as
a file; the result says where it is and what it shows. No model: same
table and arguments, same visual.

## Source: exactly one

- `sql` + `paths`: the same arguments as `query`, read by the same rules
  (one SELECT, `sql_ref` quoting, 1–10 `/datasets` paths). Preview first.
  `plot` runs it and reads the whole result; a result ds-fetch cut off at
  its ceiling (100,000 rows or 8 MiB) is refused, so aggregate or filter
  in the SQL. `sql` without `paths` is refused.
- `data`: `{columns: [{name, type}], rows: [[…]]}`, at most 100,000 rows,
  types `VARCHAR`, `BOOLEAN`, `TINYINT`, `SMALLINT`, `INTEGER`, `BIGINT`,
  `HUGEINT`, `FLOAT`, `DOUBLE`, `DECIMAL(p,s)`, `DATE`, `TIMESTAMP`,
  `TIMESTAMP WITH TIME ZONE`. Every cell is checked against its type.
  Only for a table you genuinely hold: **never copy rows from a `query`
  result**. Pass the statement instead; the result cache makes re-running
  it cheap.

Filtering is the SQL's job: `WHERE` before `plot`.

## Arguments

- `x` (required), `y`, `t`: a column name, or `unit(column)` on a date or
  timestamp: `hour`, `day`, `week`, `month`, `quarter`, `year` (calendar
  buckets in `tz`) or `hour_of_day`, `day_of_week`, `month_of_year`
  (cycles). A temporal column without a unit gets the finest unit that
  fits. The same column may appear twice
  (`x=hour_of_day(ts)`, `y=day_of_week(ts)`). Quote names with spaces:
  `"net amount"`.
- `z`: default `count(*)`. One of `sum`, `avg`, `median`, `min`, `max` of
  a numeric column (optionally `abs(col)` inside), `count(*)`,
  `count(col)`, `count(distinct col)`. A fixed grammar, not SQL.
- `resolution`: most cells per axis, 2–360, default 48. Categories past
  it keep the values with the most rows (with `sort: measure`, the
  largest `|z|`); the rest merge into `"other"` so totals stay complete. Numbers
  bin in 1-2-5 widths, often fewer cells; cast to `VARCHAR` in SQL for one
  cell per value.
- `sort`: `label` (default) or `measure`.
- `normalize`: `none` (default), `x`, `y` or `t`: each value becomes its
  share of its group. Only `sum`, `count(*)`, `count(col)`.
- `min_rows`: ≥ 2; cells from fewer rows show as no data.
- `tz`: IANA zone, default `UTC` (`Local` is rejected). Zoneless `DATE`
  and `TIMESTAMP` values are not shifted.

A visual holds at most 130,000 cell values (cells × frames) and 240
frames; an auto time unit coarsens to fit and `text` says when frames were
limited. A stored visual over 4 MB is refused: fewer cells, frames or
columns.

## Result

`{visual, text, resolved}`.

- `visual`: `/files/<id>` (also `artifact_file_id`), content type
  `application/vnd.grasp.visual+json`. `cat` returns the document
  (grid, columns, summary).
- `text`: a deterministic description of what the picture shows, in the
  request locale (`en`, `nb`, `da`, `sv`, `pl`). Quote figures from it,
  not from your reading of the grid.
- `resolved`: every axis/measure argument with defaults and automatic
  choices filled in. To change the chart, call `plot` again with the same
  source and `resolved` with one field edited.

To explain or answer questions about a visual, call `inspect` on its path.
Each call stores a new file.

## Caveats and failures

- The summary carries caveats: datasets that keep row history (apply
  `_valid_to IS NULL` in the SQL), DOUBLE measures as approximate,
  rounded decimal averages, limited frames, thin cells.
- Rows whose axis value cannot be placed or whose measure is null are
  skipped; `rows.total − rows.used` counts them.
- `validation` messages name the argument and the fix (e.g.
  `z: unknown aggregate "total"; use sum, avg, median, min, max or count`);
  fix the call in one step. `timeout` means the statement exceeded the
  engine's 25 s ceiling: narrow the SQL.
