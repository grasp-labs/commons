---
title: 'Build it: API route railroad DSL'
---
## Mermaid source

```text
railroad-beta
  title API route grammar
  route = sequence(terminal("/"), nonterminal("resource"), optional(sequence(terminal("/"), nonterminal("identifier"))), zeroOrMore(sequence(terminal("?"), nonterminal("query"))));
  resource = choice(terminal("users"), terminal("orders"), terminal("workflows"));
  identifier = special("UUID");
```

Change one line at a time, then compare the rendered result on the right.

<!-- ds-course-column:2 type=markdown -->

## Rendered result

```mermaid
railroad-beta
  title API route grammar
  route = sequence(terminal("/"), nonterminal("resource"), optional(sequence(terminal("/"), nonterminal("identifier"))), zeroOrMore(sequence(terminal("?"), nonterminal("query"))));
  resource = choice(terminal("users"), terminal("orders"), terminal("workflows"));
  identifier = special("UUID");
```

Use zoom, fit, fullscreen, and source controls when the diagram is dense.
