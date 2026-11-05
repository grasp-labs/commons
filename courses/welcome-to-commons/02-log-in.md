---
title: Log in safely
---
# Log in safely

- **People** sign in with **SSO** (work email → Entra ID) and **MFA**.
- **Scripts and agents** use an OAuth client and get a one-hour token from
  `{{IDP}}/oauth/token/`.
- Your token says **who you are** and **which tenant** you belong to.
  **What you may do** is decided by IAM on every request.

**Three rules**

1. Never share tokens or secrets. Secrets live in **ds-vault**.
2. Experiment in **dev**. Prod changes need a reason and a reviewer.
3. Ask for the IAM access you need, and nothing broader.
