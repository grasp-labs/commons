---
title: 'Requirement diagram: obligations and evidence'
---
## Requirement diagram: obligations and evidence

**Atlas example 20 of 44**

Use a requirement diagram to connect requirements, system elements, risk, and verification methods.

### Core Mermaid elements
- requirementDiagram starts the model.
- requirement, functionalRequirement, and performanceRequirement declare requirement types.
- id, text, risk, and verifymethod describe each requirement.
- element declares an implementation artifact; satisfies and contains express traceability.

### Build it well
1. Give every requirement a stable id.
2. Write testable requirement text.
3. Choose verification methods deliberately.
4. Connect each requirement to the elements that satisfy or contain it.

> A requirement without verification or ownership is only a wish.

<!-- ds-course-column:2 type=markdown -->

## Working example

```mermaid
requirementDiagram
  requirement secure_login {
    id: AUTH_01
    text: users must authenticate securely
    risk: high
    verifymethod: test
  }
  functionalRequirement auditability {
    id: GOV_04
    text: every workflow action is auditable
    risk: medium
    verifymethod: inspection
  }
  performanceRequirement response_time {
    id: PERF_02
    text: commands respond within two seconds
    risk: medium
    verifymethod: analysis
  }
  element web_client {
    type: application
    docref: Product experience specification
  }
  element workflow_engine {
    type: service
    docref: Runtime architecture
  }
  element audit_store {
    type: database
    docref: Governance architecture
  }
  web_client - satisfies -> secure_login
  workflow_engine - satisfies -> response_time
  workflow_engine - satisfies -> auditability
  audit_store - contains -> auditability
```

Use the chart controls to zoom, fit, open fullscreen, or inspect the exact source.
