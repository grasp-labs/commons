---
title: Your checklist, and the mistakes to avoid
---
# Your checklist, and the mistakes to avoid

## Before you save a workflow

**The container**

- [ ] Named after its outcome, not `workflow-2`
- [ ] `executor` matches the actual size of the job — `lambda` unless you know you need `fargate`
- [ ] `timeout` comfortably above the realistic worst case, but not so wide a hung run goes unnoticed
- [ ] `network` set, and `notify` present — but someone hears about this run through an email task, not `notify`
- [ ] Anything repeated across tasks lives in `variables`

**Every task**

- [ ] Does exactly one thing you can state in one sentence without "and"
- [ ] `type` taken from the registry in its dotted form, settings checked against its typed schema
- [ ] `condition` set deliberately, not left on the default by accident
- [ ] `severity` answers: *if only this fails, did the run fail?*
- [ ] `bindings` wired — or genuinely empty for a reason — with a dependency edge to every task it binds from
- [ ] Named well enough that a binding pointing at it reads clearly

**The graph**

- [ ] Drawn before it was built
- [ ] At least one task reports the outcome on `always` or `any-failure`
- [ ] No edges loop backwards
- [ ] Branch tasks pull data from the task that has the data they need

## The five mistakes people actually make

**1. The notification that never fires.** Left on `all-success`, so the one run you needed to hear about was silent. Use `always`, or pair `all-success` with `any-failure`.

**2. Assuming order implies data.** A task running after another does not receive its output. Dependency edges sequence; `bindings` carry data. An unwired task gets nothing and either fails on a missing input or succeeds at doing nothing.

**3. Everything marked `critical`.** The run fails on a bounced email, alerts become noise, noise gets muted, and then a real failure is ignored. The inverse — everything `minor` — is worse: green runs that wrote nothing.

**4. Retries used as a bug fix.** `retry` is for transient failure, and it re-runs the whole job. A deterministic error just fails three times more slowly.

**5. Reaching for Python first.** The transformation family covers joins, filters, selects, and aggregates — declared and visible in the graph. Check the catalogue before writing an opaque script.

## Where to go next

Build the seven-task example from step 7. Fire it, break it on purpose — flip a notification to `all-success` and watch the silence — then fix it. That failure teaches more than this course did.

> A good workflow is boring: one job per task, honest severities, and something that always tells you what happened. Aim for boring.
