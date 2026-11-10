---
title: Step 5 — Decide what counts as failure
---
# Step 5 — Decide what counts as failure

`condition` decides whether a task runs. `severity` decides whether its failure *matters*.

Two values: **`critical`** and **`minor`**.

## What the difference actually does

When a `critical` task fails, the run is a failure. When a `minor` task fails, the failure is recorded, the run continues, and the overall verdict is unaffected. `severity` never changes scheduling: an `all-success` task downstream of a failed `minor` task is still skipped.

That is the whole mechanic. Its usefulness comes from applying it honestly.

## The question to ask

Not "is this task important?" — every task you bothered to write is important. Ask instead:

**If this single task fails and everything else succeeds, was the run a success?**

If the answer is yes, it is `minor`. If no, it is `critical`.

## Worked through

- The dataset read fails → nothing downstream is meaningful. **`critical`**.
- The publish write fails → the entire point of the run did not happen. **`critical`**.
- The success email fails → the data landed correctly; the mail server had a bad afternoon. **`minor`**.
- The optional metrics snapshot fails → mildly annoying, nothing depends on it. **`minor`**.

(The built-in email task does not even report a send error: it logs it and succeeds, so confirm a new notification arrives once by hand.)

That email case is the one that catches people. A workflow marked *failed* because a notification bounced sends everyone hunting for a data problem that does not exist. Meanwhile a genuinely broken run gets ignored, because the team has learned this workflow cries wolf.

## The failure mode in both directions

**Everything `critical`** and your run fails on trivia. Alerts become noise, and noise gets muted.

**Everything `minor`** and your run reports success while writing nothing. This is worse. A loud failure gets fixed; a quiet one ships bad data for weeks.

> `severity` is how you decide what deserves someone's attention at 3am. Spend a moment on it per task, and your alerts stay worth reading.
