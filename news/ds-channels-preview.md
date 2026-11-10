---
slug: ds-channels-preview
title: "Preview: verified outbound channels"
summary: "AI Commons is adding governed delivery to verified email, SMS, Slack and Teams channels, with delivery events and no raw recipient addresses in send requests."
status: active
release_stage: preview
published_at: "2026-11-07"
audiences: [users, developers, administrators]
services: [ds-channels, ds-iam, ds-file, ds-vault]
owner: ds-channels
cta:
  label: "Read the service guide"
  url: "https://github.com/grasp-labs/commons/blob/main/book/ai-commons.pdf"
---

# Verified outbound channels are entering preview

AI Commons is adding outbound delivery for email, SMS, Slack, and Teams.
Applications send to registered, verified channels rather than passing raw
recipient addresses on every request.

Delivery state is observable through sent, delivered, and failed events.
Identity, templates, and provider credentials remain governed by the existing
IAM, File, and Vault boundaries.

This is a preview. Channel availability and interfaces may change while we
complete provider and operational validation.
