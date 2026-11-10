---
title: 'Swimlane diagram: ownership across teams'
---
## Swimlane diagram: ownership across teams

**Atlas example 28 of 44**

Use swimlanes to show one process crossing organizational or responsibility boundaries.

### Core Mermaid elements
- swimlane-beta LR starts a lane-oriented graph.
- Each subgraph becomes a lane and its label names the owner.
- Normal flowchart nodes, decisions, and arrows define the process.
- Cross-lane edges expose hand-offs.

### Build it well
1. Create one lane per accountable group.
2. Keep the process moving in one direction.
3. Label rejection and rework paths.
4. Look for repeated crossings that signal coordination cost.

> The lanes should explain ownership, not merely decorate a flowchart.

<!-- ds-course-column:2 type=markdown -->

## Working example

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

Use the chart controls to zoom, fit, open fullscreen, or inspect the exact source.
