---
title: 'Build it: command railroad PEG'
---
## Mermaid source

```text
railroad-peg-beta
  title Command grammar
  Command <- Action WS Target (WS Option)*;
  Action <- "create" / "update" / "delete";
  Target <- "workflow" / "dataset" / "service";
  Option <- "--force" / "--dry-run" / ("--region=" Region);
  Region <- "eu" / "us" / "apac";
  WS <- " "+;
```

Change one line at a time, then compare the rendered result on the right.

<!-- ds-course-column:2 type=markdown -->

## Rendered result

```mermaid
railroad-peg-beta
  title Command grammar
  Command <- Action WS Target (WS Option)*;
  Action <- "create" / "update" / "delete";
  Target <- "workflow" / "dataset" / "service";
  Option <- "--force" / "--dry-run" / ("--region=" Region);
  Region <- "eu" / "us" / "apac";
  WS <- " "+;
```

Use zoom, fit, fullscreen, and source controls when the diagram is dense.
