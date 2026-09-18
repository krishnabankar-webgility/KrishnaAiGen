---
description: 'Master router: infer which specialists apply, load only those agents and skills, then execute'
argument-hint: '[any request]'
---

Delegate this request to the **`krishnaaigen`** subagent using the Agent tool.

The subagent must load these skills before acting: `krishnaaigen-ephemeral-output`, `krishnaaigen-skill-evolution`, plus whatever the routed specialist needs.

If the request below is empty, ask what is needed rather than guessing.

## Request

$ARGUMENTS
