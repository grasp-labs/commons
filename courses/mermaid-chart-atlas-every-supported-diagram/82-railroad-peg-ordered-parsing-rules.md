---
title: 'Railroad PEG: ordered parsing rules'
---
## Railroad PEG: ordered parsing rules

**Atlas example 40 of 44**

Use the PEG variant when grammar choices are ordered and the first matching alternative wins.

### Core Mermaid elements
- railroad-peg-beta selects PEG syntax.
- <- defines a parsing rule.
- / separates ordered alternatives.
- *, +, and ? express repetition and optionality; quoted text is literal.

### Build it well
1. Order alternatives from specific to general.
2. Make whitespace rules explicit.
3. Extract options and values into named rules.
4. Test ambiguous prefixes because PEG does not backtrack like context-free alternatives.

> In PEG, choice order changes behavior.

<!-- ds-course-column:2 type=markdown -->

## Working example

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

Use the chart controls to zoom, fit, open fullscreen, or inspect the exact source.
