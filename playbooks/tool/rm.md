---
name: "rm"
slug: rm
domain: tool
description: "Playbook for the rm tool: hard delete versus recoverable soft-delete via write, no bulk delete, what is not deletable, and IAM deletes as cascading revocations with blast-radius checks."
when_to_use: "Permanently delete one identified resource. For a recoverable soft-delete, use write with status=deleted instead."
prefer_skills: []
related_tools: [rm, write, ls, cat]
examples: []
---

`rm` issues the backing DELETE, which is a **hard delete**: the row is gone,
not tombstoned. Vault is the exception. Its DELETE only sets `status=deleted`:
the secret drops out of lists, but a read by UUID still returns it. If the user might want the
resource back, do not use `rm`; use `write {"status": "deleted"}`.

## Rules

- Identified UUID paths only, one resource per call. Containers and computed
  views (e.g. `/config/llm/profiles/<uuid>/resolved`) are not deletable.
  There is no bulk delete; loop deliberately, confirming each delete.
- Not deletable at all:
  - cb-jobs: `rm` is not a cancel.
  - Exam attempts and certificates.
  - `/mnt`: read-only.
  - IAM principals.

  A backing 405 comes back as a `validation` error saying the record is
  immutable.
- A file's content and thumbnail cannot be deleted separately; `rm
  /files/<uuid>` removes the file.
- Expect a P2 pause: by default every `rm` asks the user to confirm before
  it executes.

## IAM: deletes are revocations

- Deleting a **group** cascades its memberships and policy bindings.
  Deleting a **policy** cascades its bindings. Every grant that ran through
  the deleted row disappears silently. Check the blast radius first:
  `ls /iam/groups` / `ls /iam/policies` carry
  `member_count`/`policy_count`/`holder_count` per row.
- To revoke *without* deleting anything, `rm` the narrowest edge: a
  membership (`/iam/members/<uuid>`) or a binding
  (`/iam/maps/group-policies/<uuid>`).
- Principals are IDP identities. To find what grants one,
  `cat /iam/principals/<principal_id>/policies`, then remove the membership
  or binding.

## Conflicts

A referenced row can be refused with `conflict` (409), e.g. a linked service
still used by datasets, or an owner still in use. An exam cannot be deleted
while its questions, assignments, attempts or certificates remain. Remove or
unlink the referrers first.
