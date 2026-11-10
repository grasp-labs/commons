---
title: 'Railroad DSL: visual grammar with combinators'
---
## Railroad DSL: visual grammar with combinators

**Atlas example 37 of 44**

Use the railroad DSL to explain a formal grammar as paths through terminals, choices, and repetition.

### Core Mermaid elements
- railroad-beta starts the grammar; title names it.
- rule = expression; defines a rule.
- terminal, nonterminal, and special create symbols.
- sequence, choice, optional, zeroOrMore, and oneOrMore compose the path.

### Build it well
1. Define the top-level rule first.
2. Extract repeated concepts into named rules.
3. Use terminals for literal text.
4. Keep combinator nesting readable with spacing and separate rules.

> Railroad diagrams make valid paths visible to readers who do not speak parser theory.

<!-- ds-course-column:2 type=markdown -->

## Working example

```mermaid
railroad-beta
  title API route grammar
  route = sequence(terminal("/"), nonterminal("resource"), optional(sequence(terminal("/"), nonterminal("identifier"))), zeroOrMore(sequence(terminal("?"), nonterminal("query"))));
  resource = choice(terminal("users"), terminal("orders"), terminal("workflows"));
  identifier = special("UUID");
```

Use the chart controls to zoom, fit, open fullscreen, or inspect the exact source.
