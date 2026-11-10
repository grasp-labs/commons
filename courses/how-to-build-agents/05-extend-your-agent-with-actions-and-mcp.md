---
title: Extend your agent with actions and MCP
---
## Extend your agent with actions and MCP

A basic agent can answer questions. To let it *do things* you add **actions**. An action is a capability the agent can call — a connector, a prompt, a flow, or a set of tools exposed by an MCP server.

### What is MCP?

**Model Context Protocol (MCP)** is an open standard for exposing *tools* and *data* to AI agents. Instead of wiring up each API by hand, an MCP server publishes a list of tools and their inputs, and any MCP-aware agent can discover and call them.

One big advantage: when the server adds or updates a tool, your agent picks up the change automatically — no rebuild needed.

### How it fits together in Copilot Studio

- You add an MCP server as a **tool** on your agent.
- Copilot Studio reads the server's tool list and makes those tools available to the agent.
- At run time the agent chooses which tool to call based on the user's request.

> **Reference:** Microsoft's guide *Extend your agent with actions using MCP* at learn.microsoft.com/en-us/microsoft-copilot-studio/agent-extend-action-mcp

The next page, connecting the AI Commons AI Gateway as an MCP server, is still to be written. In short: in Copilot Studio choose **Add tool → Model Context Protocol**, enter the gateway's MCP URL, and use **Manual OAuth 2.0** (dynamic discovery does not work with the gateway). Only the tools your tenant policy allows will appear.
