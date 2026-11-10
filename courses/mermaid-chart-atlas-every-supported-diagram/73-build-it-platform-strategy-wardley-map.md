---
title: 'Build it: platform strategy Wardley map'
---
## Mermaid source

```text
wardley-beta
  title Platform strategy
  anchor Customer [0.92, 0.88]
  component Developer Portal [0.82, 0.72] (build)
  component Workflow Engine [0.68, 0.50] (build)
  component Identity [0.62, 0.78] (buy)
  component Event Backbone [0.48, 0.64] (buy)
  component Cloud Runtime [0.28, 0.93] (market)
  Customer -> Developer Portal
  Developer Portal -> Workflow Engine
  Developer Portal -> Identity
  Workflow Engine -> Event Backbone
  Event Backbone -> Cloud Runtime
  evolve Workflow Engine 0.72
  note "Differentiate through governed workflows" [0.72, 0.42]
```

Change one line at a time, then compare the rendered result on the right.

<!-- ds-course-column:2 type=markdown -->

## Rendered result

```mermaid
wardley-beta
  title Platform strategy
  anchor Customer [0.92, 0.88]
  component Developer Portal [0.82, 0.72] (build)
  component Workflow Engine [0.68, 0.50] (build)
  component Identity [0.62, 0.78] (buy)
  component Event Backbone [0.48, 0.64] (buy)
  component Cloud Runtime [0.28, 0.93] (market)
  Customer -> Developer Portal
  Developer Portal -> Workflow Engine
  Developer Portal -> Identity
  Workflow Engine -> Event Backbone
  Event Backbone -> Cloud Runtime
  evolve Workflow Engine 0.72
  note "Differentiate through governed workflows" [0.72, 0.42]
```

Use zoom, fit, fullscreen, and source controls when the diagram is dense.
