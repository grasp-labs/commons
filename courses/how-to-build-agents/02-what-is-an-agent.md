---
title: "What is an agent?"
---
## What is an agent?

An agent is more than a chatbot. A chatbot *answers*; an agent *acts*. It can reason about a goal, pick the right tool or data source, and carry out steps until the task is done.

### The parts of an agent

- **Instructions (the brain):** a system prompt that sets the agent's role, tone, and rules.
- **Knowledge:** sources it can read — documents, websites, databases.
- **Tools / actions:** things it can *do* — call an API, create a ticket, run a query.
- **Triggers:** what starts it — a user message, a schedule, or an event.
- **Memory / context:** what it remembers within and across conversations.

### The loop

Most agents follow a simple loop:

1. **Perceive** — read the request and context.
2. **Plan** — decide which tool or knowledge to use.
3. **Act** — call the tool / fetch the data.
4. **Observe** — read the result.
5. **Repeat or finish** — loop until the goal is met, then reply.

> **Key idea:** the tools you give an agent define what it can do. Most of building an agent is writing good instructions and wiring up the right tools.
