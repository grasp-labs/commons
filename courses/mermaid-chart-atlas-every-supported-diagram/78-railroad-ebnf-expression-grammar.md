---
title: 'Railroad EBNF: expression grammar'
---
## Railroad EBNF: expression grammar

**Atlas example 38 of 44**

Use the EBNF variant when the source grammar is already written in Extended Backus–Naur Form.

### Core Mermaid elements
- railroad-ebnf-beta selects the EBNF parser.
- = defines a rule and ; terminates it.
- | means choice, comma means sequence, { } means repetition, and quoted text is literal.
- Parentheses group an expression.

### Build it well
1. Define referenced rules after the entry rule.
2. Separate precedence levels into expression, term, and factor.
3. Keep literals quoted.
4. Test recursive rules with simple valid and invalid examples.

> The grammar’s structure should make operator precedence explicit.

<!-- ds-course-column:2 type=markdown -->

## Working example

```mermaid
railroad-ebnf-beta
  title Expression grammar
  expression = term, { ("+" | "-"), term } ;
  term = factor, { ("*" | "/"), factor } ;
  factor = number | "(", expression, ")" ;
  number = digit, { digit } ;
  digit = "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" ;
```

Use the chart controls to zoom, fit, open fullscreen, or inspect the exact source.
