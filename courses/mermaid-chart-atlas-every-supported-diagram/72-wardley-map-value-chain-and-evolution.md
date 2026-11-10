---
title: 'Wardley map: value chain and evolution'
---
## Wardley map: value chain and evolution

**Atlas example 35 of 44**

Use a Wardley map to connect user value, dependencies, and the evolution of capabilities from novel to commodity.

### Core Mermaid elements
- wardley-beta starts the map; title names the strategic question.
- anchor and component place nodes at [visibility, evolution] coordinates.
- A -> B defines dependency; (build), (buy), or (market) records strategy.
- evolve moves a component target; note adds an annotation at coordinates.

### Build it well
1. Begin with the user need at high visibility.
2. Trace dependencies downward.
3. Position evolution honestly.
4. Use strategy markers and notes to surface choices.

> A Wardley map is a strategic conversation tool, not an architecture diagram.

<!-- ds-course-column:2 type=markdown -->

## Working example

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

Use the chart controls to zoom, fit, open fullscreen, or inspect the exact source.
