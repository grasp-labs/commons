---
title: Governance, briefly
---
## Governance, briefly

Commons is governed by default, which is what makes shared data safe to rely on:

- identity and permissions are consistent across every service and compute block;
- access policy lives in IAM, approval rules in Config, and secrets are envelope-encrypted in Vault;
- every action is **logged and audited** — you can always see what ran, by whom, and on whose behalf;
- some actions require explicit approval before they run — by design.

> **Rule of thumb:** approval steps and the audit trail are features. They are why BI can trust what comes out.
