---
title: Step 3 — Pick your tasks from the catalogue
---
# Step 3 — Pick your tasks from the catalogue

There are a couple of dozen built-in task types. You do not need to memorise them, because they fall into five families and the naming tells you which family you are in.

## `io.*` — moving data in and out

Reading and writing. `io.read.dataset` pulls a dataset into the run; `io.create.dataset`, `io.update.dataset`, `io.upsert.dataset` and `io.delete.dataset` push a result back out. Most workflows start with an `io.read` and end with a write, and the interesting part is what happens in between.

## `operational.transformation.*` — reshaping data

The workhorses. Joining frames, selecting and dropping columns, filtering rows, aggregating, renaming. If you are changing the *shape* of data rather than its location, you want this family.

Reach for these before writing code. A declared transformation is visible in the graph and understandable by someone who has never seen your workflow. A Python task is a black box by comparison.

## `control.*` — steering the graph

Branching and pacing. A **choice** evaluates an expression and selects which downstream tasks run; a **channel guard** stops a branch when its input is empty; **sleep** waits. This is how you express "if the data is clean, publish it; otherwise, report on it" without writing an `if` statement anywhere.

## `operational.analytics.*` — inspecting the run

Meant for tasks that look at the run itself rather than the data. The one type here, collect-errors, currently always returns an empty frame, so do not rely on it. To report failures, bind a write task's `failure` channel into a channel guard and an email or a write.

## `functional.*` — talking to humans and callers

`functional.notification.email` sends mail, optionally with data attached as CSV; `functional.input.source` turns a run payload into a frame. A workflow nobody hears about is a workflow nobody trusts. Put a notification at the end of anything that matters, and give it a `condition` that fires on failure too.

## `operational.execution.python` — the escape hatch

Arbitrary code, for the case the catalogue genuinely does not cover.

Treat it as a last resort. It is opaque to the graph, runs in a sandbox with no network access, and is the first place people reach when they haven't read the transformation family. Look for a declared task first; use Python when you have actually confirmed there isn't one.

> Ask `schema("/config/workflows/<id>/tasks")` with no type to list every type available to you. Read the enum once and the families will stick.
