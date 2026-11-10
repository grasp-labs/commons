---
title: 'Welcome: from idea to a running workflow'
---
# How to create a workflow

A workflow can be an automated process.

If you have ever exported a dataset, reshaped a few columns, joined it against another table, and then emailed someone the result — you have run a workflow. You just ran it manually. This course is about writing it down once, so the platform runs it for you, the same way, every time.

## What you will learn

- What a workflow is on this platform, and the two objects it is made of
- How to configure a workflow: executor, network, retries, notifications, variables
- How to add **tasks**, and what every task must declare
- The task catalogue — 29 built-in types, grouped into families you can actually remember
- How `condition` decides whether a task runs, and how `severity` decides whether a failure matters
- How `bindings` wire tasks together
- How to run a workflow and read what came back

## What you need

Nothing installed. A workflow is a configuration record plus some task records and the edges between them — if you can draw your process step-by-step in a map, you can build a workflow.

## How long this takes

About 25 minutes to read. Longer if you build as you go, which is the point.

> **One idea to hold onto:** a workflow is not code. It is a *declaration* of work — typed tasks and the rules connecting them. You write the declaration; the platform turns it into a running job. Keeping those two apart is most of the skill.
