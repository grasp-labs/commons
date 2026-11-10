---
title: 'Build it: expression railroad EBNF'
---
## Mermaid source

```text
railroad-ebnf-beta
  title Expression grammar
  expression = term, { ("+" | "-"), term } ;
  term = factor, { ("*" | "/"), factor } ;
  factor = number | "(", expression, ")" ;
  number = digit, { digit } ;
  digit = "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" ;
```

Change one line at a time, then compare the rendered result on the right.

<!-- ds-course-column:2 type=markdown -->

## Rendered result

```mermaid
railroad-ebnf-beta
  title Expression grammar
  expression = term, { ("+" | "-"), term } ;
  term = factor, { ("*" | "/"), factor } ;
  factor = number | "(", expression, ")" ;
  number = digit, { digit } ;
  digit = "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" ;
```

Use zoom, fit, fullscreen, and source controls when the diagram is dense.
