---
name: "ds-share: one-time sharing"
slug: ds-share
domain: service
description: "Playbook for sharing a file with someone outside the platform: one-time links are not available yet, and how to share inside the tenant with file access lists instead."
when_to_use: "A user asks for a download link, a public or one-time link, or to send a file to someone who has no AI Commons account."
prefer_skills: []
related_tools: [info, cat, write]
examples: []
---

## Status

ds-share is designed, not live. There is no `/share` tool path, no share
endpoint and no link to hand out. Do not improvise one: never paste file
content, storage URLs or a bearer token into a message as a substitute for a
link.

The planned contract: an authenticated user who can read a ds-file resource
creates a grant; the service returns one opaque URL that an unauthenticated
recipient can redeem until its time-to-live or use limit runs out, and the
creator can revoke it before use. Version 1 covers ds-file resources only.

## What to do today

1. **Recipient has an account in the same tenant:** share through the file's
   access list. `info /files/<uuid>` shows `acl`; `write /files/<uuid>` with
   `acl.viewers` grants read access. Setting `acl` replaces both lists, so
   include everyone who should keep access. See the `ds-file` playbook.
2. **Recipient is outside the tenant or has no account:** say plainly that
   external sharing is not available yet; the user has to send the file
   through their own channel.
3. Never set `"*"` in viewers to "share" with one person: it opens the file
   to the whole tenant.
