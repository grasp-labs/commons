---
title: 'Build it: HTTP request railroad ABNF'
---
## Mermaid source

```text
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

Change one line at a time, then compare the rendered result on the right.

<!-- ds-course-column:2 type=markdown -->

## Rendered result

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

Use zoom, fit, fullscreen, and source controls when the diagram is dense.
