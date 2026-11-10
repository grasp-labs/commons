---
title: 'C4 dynamic: one runtime scenario'
---
## C4 dynamic: one runtime scenario

**Atlas example 43 of 44**

Use a C4 dynamic diagram to overlay an ordered interaction on recognizable C4 elements.

### Core Mermaid elements
- C4Dynamic selects the dynamic view.
- Person, Container, and ContainerDb declare participants.
- Rel statements describe runtime interactions.
- Numbered relationship labels make execution order explicit.

### Build it well
1. Choose one scenario.
2. Number every interaction consistently.
3. Keep static structure minimal.
4. Finish with the visible business outcome.

> Dynamic C4 is a sequence story grounded in architectural boundaries.

<!-- ds-course-column:2 type=markdown -->

## Working example

```mermaid
C4Dynamic
  title Dynamic order processing
  Person(user, "Business user")
  Container(web, "Web application", "React")
  Container(api, "API gateway", "TypeScript")
  Container(workflow, "Workflow engine", "Service")
  ContainerDb(store, "Platform store", "PostgreSQL")
  Rel(user, web, "1. Submits order")
  Rel(web, api, "2. Sends command")
  Rel(api, workflow, "3. Starts workflow")
  Rel(workflow, store, "4. Persists state")
  Rel(workflow, web, "5. Publishes result")
```

Use the chart controls to zoom, fit, open fullscreen, or inspect the exact source.
