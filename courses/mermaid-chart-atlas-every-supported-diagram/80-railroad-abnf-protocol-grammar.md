---
title: 'Railroad ABNF: protocol grammar'
---
## Railroad ABNF: protocol grammar

**Atlas example 39 of 44**

Use the ABNF variant for internet protocols and specifications that use Augmented BNF notation.

### Core Mermaid elements
- railroad-abnf-beta selects ABNF.
- = defines a rule; / separates alternatives.
- 1* means one or more repetitions.
- %xHH encodes a hexadecimal character value; rule names may reference standard tokens.

### Build it well
1. Preserve the protocol’s canonical rule names.
2. Define local terminals and reused separators.
3. Check repetition bounds carefully.
4. Keep the diagram focused on one production at a time.

> ABNF is precise enough for protocols; do not simplify away meaningful constraints.

<!-- ds-course-column:2 type=markdown -->

## Working example

```mermaid
railroad-abnf-beta
  title HTTP request grammar
  request-line = method SP request-target SP HTTP-version CRLF;
  method = "GET" / "POST" / "PUT" / "DELETE";
  request-target = 1*( unreserved / "/" );
  HTTP-version = "HTTP/1.1";
  SP = %x20;
  CRLF = %x0D.0A;
  unreserved = %x41-5A / %x61-7A / %x30-39 / "-" / ".";
```

Use the chart controls to zoom, fit, open fullscreen, or inspect the exact source.
