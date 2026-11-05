# Security

Report vulnerabilities privately through
[GitHub private vulnerability reporting](https://github.com/grasp-labs/commons/security/advisories/new).
Do not open public issues for security reports.

If a Commons token, client secret or vault secret was exposed, rotate it now:
vault secrets with `PUT /secret/{id}/`, OAuth client secrets through the
platform team. Tokens expire within one hour; client secrets do not.

The plugin's guard hook is a safeguard, not a security boundary. IAM and the
tenant AI profile enforce access.
