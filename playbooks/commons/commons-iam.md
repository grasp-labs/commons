---
name: commons-iam
description: ds-iam authorization on Commons. Policies, actions, CRNs, wildcards, the aic tenant placeholder, conditions, groups, members, bindings, managed policies, and debugging 403. Use when granting or checking access, writing a policy, or a call fails with 403.
when_to_use: ds-iam authorization on Commons. Policies, actions, CRNs, wildcards, the aic tenant placeholder, conditions, groups, members, bindings, managed policies, and debugging 403. Use when granting or checking access, writing a policy, or a call fails with 403.
prefer_skills: []
related_tools: [ls, cat, schema, write]
---

# ds-iam

`https://grasp-daas.com/api/iam[-dev]/v1`. The JWT says **who**; IAM says **what**. Every service
evaluates the caller's effective policies per request: **default deny, explicit deny wins**.
503 means IAM was unreachable (fail closed).

## Model

| Primitive | Endpoint | Body (required **bold**) |
|---|---|---|
| Group | `/group/` | **`name`**, **`status`**, `description`, `external_id` (SCIM) |
| Member | `/member/` | **`principal_id`** (token `sub`), **`status`**, `group_id` (one group per member) |
| Policy | `/policy/` | **`name`**, **`status`**, **`statements[]`**, `version` |
| Binding | `/map/group-policy/` | **`group_id`**, **`policy_id`** |
| Actions | `/action/` | Global catalog (platform-managed) |
| Effective | `GET /principal/{sub}/policies/` | What a principal holds |

Groups are tenant-private. SCIM-synced groups carry membership only: unbound = no permissions.
Detach a member: `PATCH /member/{id}/` `{"group_id": null}`.

## Statement

```json
{"sid": "ReadWorkflows", "effect": "allow",
 "actions": ["config:getWorkflow", "config:listWorkflow"],
 "resources": ["crn:aic:*:config::workflow:*"],
 "conditions": {"StringEquals": {"resource.path[0]": ["reports"]}}}
```

- **Action** = `{service}:{operationId}` verbatim from the OpenAPI spec (`file:getFileContent`,
  `config:createWorkflow`, `message:createMessage`, `fetch:query`). Wildcards: `file:*`, `*`.
- **Services**: `vault`, `file`, `state`, `message`, `ingress`, `inbound`, `config`, `fetch`,
  `knowledge-graph`, `iam`, `ai-gateway`, `tools`, `idp`.

## CRN

`crn:{tenant}:{scope}:{service}:{region}:{type}:{resource}` — exactly seven fields.

| Field | Value |
|---|---|
| tenant | Tenant UUID, or `aic` = the requesting tenant. **Never `*`.** |
| scope | Owner id; `*` = any owner; empty when unowned (IAM itself) |
| region | Empty (reserved) |
| type | API collection: `file`, `workflow`, `workflow/task`, `llm/model`, `mcp-tool` |
| resource | UUID or logical path (`reports/q3.csv`, `<id>/content`) |

`*` = exactly one segment; `**` = zero or more path segments (resource only).

| Pattern | Grants |
|---|---|
| `crn:aic:*:config::workflow:*` | every workflow |
| `crn:aic:*:config:*:*:**` | all of config |
| `crn:aic:*:file::file:reports/**` | files under `reports/` |
| `crn:aic:*:ai-gateway::mcp-tool:tripletex/get_invoice` | one external MCP tool |

## Grant access (least privilege)

1. Reuse a managed policy if one fits: `GET /policy/` returns yours plus public ones
   (`issuer` tells them apart; e.g. `FileReadOnlyAccess`, `KnowledgeGraphReadOnlyAccess`). Public
   policies are bindable, not editable.
2. Otherwise `POST /policy/` with only the actions needed, scoped resources, and explicit denies for
   what must never happen.
3. `POST /group/` → `POST /member/` → `POST /map/group-policy/`.
4. Verify: `GET /principal/{sub}/policies/`, then make the real call.

Tools: `ls /iam/policies`, `cat /iam/principals/<sub>/policies`, `schema /iam/policies` → `write`.
Every IAM write changes privileges: say what it grants before asking for approval.

## Debug a 403

1. Note the service and operationId of the failing call (OpenAPI `<base>/docs/`).
2. `GET /principal/{sub}/policies/`: is there an allow for that action **and** a resource pattern
   that matches the CRN? Is any deny matching? Is the tenant segment `aic` or your UUID?
3. Is the member `active` and in a group with the binding? Is the policy `active`?

Tenants get `IAMFullAccess` at bootstrap. Reference: `ds-iam/docs/policy/policies.md`,
`managed-policies.md`. Safety pattern for Claude's own client: `commons-safety`.
