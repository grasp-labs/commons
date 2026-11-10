---
title: 'Kanban board: work by status'
---
## Kanban board: work by status

**Atlas example 19 of 44**

Use a Kanban diagram to show work items grouped by workflow state at one moment in time.

### Core Mermaid elements
- kanban starts the board.
- columnId[Label] creates a column.
- Indented taskId[Label] creates a card in that column.
- The source order controls column and card order.

### Build it well
1. Use real workflow states.
2. Keep card labels actionable and short.
3. Limit work in the active column.
4. Treat the chart as a snapshot, not a live board.

> Kanban shows where work is now; Gantt shows when work is planned.

<!-- ds-course-column:2 type=markdown -->

## Working example

```mermaid
kanban
  discovery[Discovery]
    task1[Interview platform teams]
    task2[Map current dependencies]
    task3[Agree success metrics]
  ready[Ready]
    task4[Design shared contracts]
    task5[Prepare rollout plan]
    task6[Review threat model]
  active[In progress]
    task7[Build shared components]
    task8[Verify both themes]
    task9[Exercise failure paths]
  completed[Done]
    task10[Accessibility review]
    task11[Performance baseline]
    task12[Operations handover]
```

Use the chart controls to zoom, fit, open fullscreen, or inspect the exact source.
