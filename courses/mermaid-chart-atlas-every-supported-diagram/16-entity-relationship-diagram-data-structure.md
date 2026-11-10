---
title: 'Entity relationship diagram: data structure'
---
## Entity relationship diagram: data structure

**Atlas example 7 of 44**

Use an ER diagram to show entities, important attributes, and the cardinality of persisted relationships.

### Core Mermaid elements
- erDiagram starts the schema.
- ENTITY { type attribute PK } lists fields and key markers such as PK and FK.
- || means exactly one, o{ zero or many, and |{ one or many.
- ENTITY_A ||--o{ ENTITY_B : label describes the relationship.

### Build it well
1. Begin with the business entities and their identifiers.
2. Add only attributes needed to understand the relationship.
3. Verify both sides of every cardinality.
4. Use relationship labels as clear verbs.

> ER diagrams model stored relationships; sequence diagrams model runtime calls.

<!-- ds-course-column:2 type=markdown -->

## Working example

```mermaid
erDiagram
  TENANT ||--o{ WORKFLOW : owns
  WORKFLOW ||--o{ WORKFLOW_RUN : executes
  WORKFLOW_RUN ||--|{ TASK_RUN : contains
  USER ||--o{ WORKFLOW_RUN : starts
  TENANT {
    uuid id PK
    string name
  }
  WORKFLOW {
    uuid id PK
    uuid tenant_id FK
    string name
    string status
  }
  WORKFLOW_RUN {
    uuid id PK
    uuid workflow_id FK
    datetime started_at
  }
  TASK_RUN {
    uuid id PK
    uuid run_id FK
    string status
  }
  USER {
    uuid id PK
    string email
  }
```

Use the chart controls to zoom, fit, open fullscreen, or inspect the exact source.
