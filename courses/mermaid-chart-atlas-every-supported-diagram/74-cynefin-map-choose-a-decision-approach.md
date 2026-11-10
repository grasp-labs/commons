---
title: 'Cynefin map: choose a decision approach'
---
## Cynefin map: choose a decision approach

**Atlas example 36 of 44**

Use a Cynefin map to classify situations by how cause and effect can be understood, then choose an appropriate response.

### Core Mermaid elements
- cynefin-beta starts the map; title adds context.
- complex, complicated, clear, chaotic, and confusion open domains.
- Quoted indented labels add examples to a domain.
- domain --> domain : "label" defines a transition.

### Build it well
1. Classify the situation, not the team.
2. Use concrete examples.
3. Describe what changes when an item moves domains.
4. Avoid treating one domain as universally better.

> Cynefin guides how to act under uncertainty; it does not rank project importance.

<!-- ds-course-column:2 type=markdown -->

## Working example

```mermaid
cynefin-beta
  title Delivery decision model
  complex
    "New product discovery"
    "AI-assisted workflow design"
  complicated
    "Capacity modelling"
    "Security architecture"
  clear
    "Standard deployment"
    "Routine access request"
  chaotic
    "Active production outage"
  confusion
    "Unclassified customer impact"
  complex --> complicated : "Pattern understood"
  complicated --> clear : "Practice standardized"
  chaotic --> complex : "Service stabilized"
```

Use the chart controls to zoom, fit, open fullscreen, or inspect the exact source.
