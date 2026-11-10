---
name: "ds-iam: access management"
slug: ds-iam
domain: service
description: Author IAM policies, grant access, and enforce it in services with Decide and Constrain on AI Commons.
when_to_use: Writing or reviewing a policy document or CRN pattern; granting or revoking access through the IAM API; wiring ds-go-iam-middleware into a service; debugging an unexpected 401, 403, 404, 409, 422, or 503.
prefer_skills: []
related_tools: []
examples: []
---

# IAM authorization

## Who owns what

The service builds the CRN and request context. ds-iam owns the records.
`ds-go-iam-middleware` fetches, caches, and compiles the policy set;
`ds-go-policy` matches locally, in memory.

## Actions

`{service}:{operationId}`, the OpenAPI operation id verbatim (`file:getFile`,
`iam:createPolicy`). Wildcards only as `{service}:*` or `*`. List the catalog
with `GET /action/`; catalog mutations require the platform tenant. Scope the
resource to narrow access; never invent actions.

## CRN

`crn:{tenant}:{scope}:{service}:{region}:{type}:{resource}`, always seven
fields, patterns included: `crn:<t>:*:*:*:*:**` is the whole tenant, while
`crn:<t>:*` does not parse and is a 422 on write.

- Tenant is a UUID or `aic`, never `*`. `aic` (patterns only) means the
  requesting tenant, which is how one public policy serves every tenant that
  binds it. A concrete UUID of another tenant matches nothing for this caller.
- `*` matches one field or path segment, including empty. `**` matches zero
  or more path segments and is valid only in the resource.
- Only the resource may contain `:`; no leading or trailing `/`. Build
  concrete CRNs with `crn.Build`, never string concatenation.

## Policy document

```json
{
  "name": "FileReadOnly",
  "status": "active",
  "statements": [
    {"sid": "read", "effect": "allow",
     "actions": ["file:getFile", "file:listFiles"],
     "resources": ["crn:aic:*:file:*:file:**"]},
    {"sid": "protect-secrets", "effect": "deny", "actions": ["*"],
     "resources": ["crn:aic:*:file:*:file:projectx/secrets/**"]}
  ]
}
```

`name` (unique per tenant), a valid `status`, and at least one statement are
required; each statement needs `effect` `allow|deny`, actions, and resources.
Serialized statements max 6144 characters. IAM compiles the document on write,
so anything the engine would reject is a 422. Deny wins, default deny,
statement order is irrelevant.

### Conditions

`{operator: {key: [values]}}`. Operators AND, keys AND, a key's values OR.
Operators: `String[Not]Equals[IgnoreCase]`, `String[Not]Like`, `Bool`,
`Numeric*`, `Date*` (RFC 3339), `[Not]IpAddress`, `Null`, each with an
optional `IfExists` suffix. Unknown operator is a 422.

Keys come from the context the service passes. An absent key fails positive
operators, passes `Not*` operators, and is skipped with `IfExists`.
`resource.path[N]` is the Nth (0-based) resource path segment, read from the
resource itself so it cannot be spoofed; use it to pin a partition.

## Granting access

```text
POST /group/             {name, status: "active"}
POST /member/            {principal_id: <token sub>, group_id, status: "active"}
POST /policy/            {name, status: "active", statements: [...]}
POST /map/group-policy/  {group_id, policy_id}
```

Only active members, groups, and policies contribute; bindings have no status.
Set `status: "suspended"` to revoke reversibly. Deleting a group cascades its
members and bindings; deleting a policy cascades its bindings.

- Tenant comes from the token, never the payload. Rows of another tenant
  answer 404, not 403.
- ds-iam enforces its own `iam:{operationId}` actions, so a missing grant is 403.
- `issuer: "public"` is allowed only for the platform tenant.
- 409: quotas (5000 groups per tenant, 10 groups per principal, 20 policies
  per group) and duplicates (group or policy name per tenant, member
  `(principal_id, group_id)`, binding `(group_id, policy_id)`).

## Enforcing in a service

`e.Use(authz.Handler())` after auth middleware; policies load on the first
check.

- Point check: `iam.Decide(ctx, iam.Request{Action, Resource, Context})`.
  It never returns an error value; check `d.Err` before `d.Allowed`. Set
  `ResourcePublished` from the stored row only.
- List check: `iam.Constrain(ctx, action, attrs)` then `sqlfilter.Where` or
  `pathfilter.Prefixes`. On error, do not run the query. `Prefixes` returns
  allow and deny globs; subtract the deny side yourself. Never loop `Decide`
  over rows.
- `iam.Guard.Require` returns `ErrAccessDenied` for a denial.

Map errors: `ErrNoPrincipal`, `ErrTokenRejected` 401; `ErrNoMiddleware`,
`ErrPrincipalRejected` 500; any other error 503; denied 403. 403 means "you
may not", 503 "we could not tell"; never collapse them. `d.Reason` is the
matched sid, `explicit deny`, or `implicit deny`.

## Operational facts

- Data plane: `GET /principal/{principal_id}/policies/`; no grants is a 200
  with `policies: []`.
- Cache `TTL` 60s; on outage a cached set is served up to `MaxStale` 30m.
  Fetch timeout 3s. `iam.New` fails unless `CacheLifeWindow >= MaxStale >= TTL`.
  `Evict(tenant, principal)` drops a cached set after writes you own.
- One document that fails to compile fails the whole set (503); dropping it
  could drop a deny.
