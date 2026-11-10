---
title: 'Build it: delivery decisions Cynefin map'
---
## Mermaid source

```text
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

Change one line at a time, then compare the rendered result on the right.

<!-- ds-course-column:2 type=markdown -->

## Rendered result

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

Use zoom, fit, fullscreen, and source controls when the diagram is dense.
