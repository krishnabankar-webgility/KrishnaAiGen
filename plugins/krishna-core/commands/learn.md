---
description: 'Persist a correction into the agents/skills so the mistake is not repeated, keeping Claude/Cursor/Copilot copies in sync'
argument-hint: '[what was wrong and what the correct behavior is]'
---

Delegate this request to the **`agent-learning`** subagent using the Agent tool.

The subagent must load these skills before acting: `krishnaaigen-skill-evolution`.

If the request below is empty, ask what is needed rather than guessing.

## Request

$ARGUMENTS
