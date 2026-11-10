---
title: 'The two objects: config and tasks'
---
# The two objects: config and tasks

Every workflow you build is exactly two things. Get this shape in your head and the rest is filling in blanks.

## 1. The workflow config — the container

One record that owns the whole thing. It carries the settings that apply to *every* task inside it:

- **`compute_engine`** — the dataframe engine the run uses (today only `pandas`).
- **`executor`** — where the work physically happens. `lambda` for short, small runs; `fargate` when you need more room or more time.
- **`network`** — `{ "mode": ... }`, the networking mode the executor runs under (`public`, `nat`, `vpn`, `static_ip`; `fargate` allows only `nat` or `static_ip`). Matters the moment a task needs to reach something outside the platform.
- **`retry`** — `{ "max_attempts": ..., "backoff_seconds": ... }`: how many times a failed *job* is re-run, as a new job, before it is left failed.
- **`timeout`** — how long the run may take before it is cut off (at most 900 seconds on `lambda`, 86400 on `fargate`).
- **`notify`** — `{ "email": [...], "on_success": ..., "on_failure": ... }`. Required, but these emails are currently never sent — use an email task to tell people.
- **`variables`** — named values your tasks can read, so you are not hard-coding the same bucket name into nine places.

The container does no work. It sets the conditions under which work happens.

## 2. The tasks — the actual work

Many records, each belonging to the config. Every task declares:

- **`type`** — *which* task this is, chosen from a fixed registry. You do not invent types; you pick one.
- **`settings`** — the parameters for that specific type. A read task needs to know what to read; an email task needs to know who to email.
- **`condition`** — whether it is allowed to run, based on how earlier tasks finished.
- **`severity`** — whether its failure should sink the run or just be noted.
- **`bindings`** — where its input data comes from.

Tasks are linked by **dependency edges**, one small record per edge (`/config/maps/workflow-task-dependencies`): this task waits on that one. Edges decide order; nothing flows along them by itself.

## Why the split matters

Because it decides where you go when something is wrong.

Run timed out, or couldn't reach an external host? That is **container** territory — `timeout`, `network`. One task read the wrong column, ran when it shouldn't have, or nobody got told? That is **task** territory — `settings`, `condition`, `bindings`, and the edges.

People waste a lot of time editing tasks to fix problems that live in the config, and vice versa.

> Container = the conditions of the run. Tasks = the work of the run. Two records, two jobs.
