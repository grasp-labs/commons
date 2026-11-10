---
slug: ds-share-preview
title: "Preview: secure one-time sharing"
summary: "AI Commons is adding short-lived, one-time capability links for sharing DS File artifacts without exposing storage URLs or creator credentials."
status: active
release_stage: preview
published_at: "2026-11-07"
audiences: [users, developers, administrators]
services: [ds-share, ds-file, ds-iam]
owner: ds-share
cta:
  label: "Read the service guide"
  url: "https://github.com/grasp-labs/commons/blob/main/book/ai-commons.pdf"
---

# Secure one-time sharing is entering preview

AI Commons is adding a controlled way to share a DS File artifact with someone
who does not have a platform account. A share grants one download, expires
quickly, and can be revoked before use.

The service stores only token hashes. DS File remains authoritative for the
artifact, and storage URLs and creator credentials are never exposed to the
recipient.

This is a preview. Interfaces and availability may change while we complete
operational and security validation.
