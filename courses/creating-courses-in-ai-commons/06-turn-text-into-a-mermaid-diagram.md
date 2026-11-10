---
title: Turn text into a Mermaid diagram
---
## The pattern

Create a fenced code block, set its language to **mermaid**, and place the diagram source inside.

```text
flowchart LR
    Draft --> Review
    Review --> Publish
```

AIC detects the Mermaid block and renders it automatically in the editor, course player, and PDF export.

### Keep the source maintainable

- one statement per line;
- short, meaningful node labels;
- stable IDs for nodes you reconnect;
- indentation for readability.

<!-- ds-course-column:2 type=markdown -->

```mermaid
flowchart TB
    Idea[Course idea] --> Outcome[Define the outcome]
    Outcome --> Draft[Build a draft]
    Draft --> Preview[Preview every step]
    Preview --> Decision{Clear and correct?}
    Decision -->|No| Draft
    Decision -->|Yes| Publish[Publish]
```
