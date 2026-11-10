---
title: 'Sankey diagram: weighted flows'
---
## Sankey diagram: weighted flows

**Atlas example 14 of 44**

Use a Sankey diagram to show how volume moves from sources through transformations to destinations.

### Core Mermaid elements
- sankey-beta starts the chart.
- Each CSV row is source,target,value.
- Repeated names become the same node automatically.
- The numeric value controls the width of the flow.

### Build it well
1. Use consistent units for every row.
2. Ensure outgoing and incoming values make sense.
3. Keep node names stable across rows.
4. Reduce minor flows when they obscure the dominant story.

> A Sankey answers where volume goes and how much, not merely what connects.

<!-- ds-course-column:2 type=markdown -->

## Working example

```mermaid
sankey-beta
Web application,API gateway,180
Web application,Cache,45
API gateway,Workflow engine,105
API gateway,Data catalogue,55
API gateway,Identity service,20
Workflow engine,Event stream,72
Workflow engine,Platform store,33
Event stream,Warehouse,58
Event stream,Observability,14
Cache,Static response,36
Identity service,Audit stream,20
Platform store,Warehouse,26
```

Use the chart controls to zoom, fit, open fullscreen, or inspect the exact source.
