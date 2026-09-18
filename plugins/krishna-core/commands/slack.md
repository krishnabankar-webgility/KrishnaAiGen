---
description: 'Post or read Slack messages via the Slack MCP server'
argument-hint: '[channel + message, or what to read]'
---

Delegate this request to the **`slack-automation`** subagent using the Agent tool.

The subagent must load these skills before acting: `slack-integration`.

If the request below is empty, ask what is needed rather than guessing.

## Request

$ARGUMENTS
