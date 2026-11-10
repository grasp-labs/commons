---
name: "ds-channels: outbound messaging"
slug: ds-channels
domain: service
description: "Playbook for outbound messaging (email, SMS, Slack, Teams): what can be sent today, the planned ds-channels model of verified channels with idempotent delivery, and how to answer notification requests without overpromising."
when_to_use: "A user asks to be notified, emailed, texted or pinged in Slack or Teams, wants alerts when a job succeeds or fails, or asks whether AI Commons can send messages on their behalf."
prefer_skills: []
related_tools: [cat, write, info]
examples: []
---

## What exists today

- **No send tool.** No AI Commons tool sends an email, SMS, Slack or
  Teams message. Do not improvise one through `run`, a workflow you
  build ad hoc, or a raw HTTP call to a provider: there is no platform
  sender, recipient verification or opt-out behind that path.
- **ds-channels is not live.** The service is designed, not built. There
  is no `/channels` path, no channel records and no delivery status to
  check.
- **The email activity** is the one working sender: an email task inside a
  workflow sends through the platform's Microsoft Graph mailbox (see the
  `workflow-functional` playbook). Wire it on the success or failure channel
  of the task whose outcome matters, then confirm with one real run.
- **Workflow `settings.notify` reports are broken today.** Config stores the
  recipients under `email`, the workflow runtime reads `emails`, so no
  report is sent. Do not promise them.
- **Pipeline `settings.notify`** (`email`, `on_success`, `on_failure`)
  is accepted and stored by Config, but no pipeline service sends
  anything from it today. Do not promise pipeline alerts.
- Inside a user's own Microsoft 365 tenant, sending mail is a provider
  integration question; see the `provider-microsoft` playbook.

## Answering a notification request

1. Say plainly what is and is not possible: email from a workflow task yes;
   ad-hoc messages, SMS, Slack and Teams no.
2. For job outcomes on a workflow, offer an email task and name the
   recipients and the trigger back to the user before writing.
3. For anything else, suggest the user watches the job (`status`,
   `info`; see the `ds-state` playbook) or checks results in the app.
4. Never claim a message was delivered. An email task is
   fire-and-forget: there is no delivery record to show.

## Planned ds-channels model (not available)

Use this only to explain direction, never as something you can call.

- One service owns recipients, provider credentials, delivery, retries,
  idempotency and opt-outs. Tools, pipeline `notify` and agent job
  notifications become clients; none talk to a provider directly.
- **Channels** are tenant records of kind `email`, `sms`, `slack` or
  `teams`, with status `pending`, `verified` or `disabled`. Only
  verified channels are reachable: email and SMS by recipient double
  opt-in, Slack and Teams by tenant-admin install. Callers never send to
  a raw address.
- **Messages** are plain text or Markdown with optional DS File
  attachments, sent to one channel. An `Idempotency-Key` is required and
  unique per tenant: a repeat returns the original message and never
  sends twice. Accepted messages are queued and retried on transport
  errors, 5xx and 429; other 4xx fail at once.
- Bounces, complaints and STOP replies add the target to a suppression
  list checked before every send.
- Sequence: email first, then the tool and pipeline `notify`, then Slack
  and Teams, then SMS. An in-app inbox is later still.

When the service ships this playbook will name the tool and paths; until
then treat any of the above as roadmap.
