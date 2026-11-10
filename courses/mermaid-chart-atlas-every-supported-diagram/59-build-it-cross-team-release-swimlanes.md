---
title: 'Build it: cross-team release swimlanes'
---
## Mermaid source

```text
swimlane-beta LR
  subgraph Product
    Discover[Discover need]
    Accept{Accept release?}
  end
  subgraph Engineering
    Design[Design solution]
    Build[Build increment]
    Fix[Resolve findings]
  end
  subgraph Operations
    Validate[Validate readiness]
    Deploy([Deploy])
  end
  Discover --> Design --> Build --> Validate --> Accept
  Accept -->|Yes| Deploy
  Accept -->|No| Fix --> Build
```

Change one line at a time, then compare the rendered result on the right.

<!-- ds-course-column:2 type=markdown -->

## Rendered result

```mermaid
swimlane-beta LR
  subgraph Product
    Discover[Discover need]
    Accept{Accept release?}
  end
  subgraph Engineering
    Design[Design solution]
    Build[Build increment]
    Fix[Resolve findings]
  end
  subgraph Operations
    Validate[Validate readiness]
    Deploy([Deploy])
  end
  Discover --> Design --> Build --> Validate --> Accept
  Accept -->|Yes| Deploy
  Accept -->|No| Fix --> Build
```

Use zoom, fit, fullscreen, and source controls when the diagram is dense.
