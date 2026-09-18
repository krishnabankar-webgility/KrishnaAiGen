---
description: 'Generate Krishna''s daily work digest (Yesterday/Today/Pending/Blockers/TL;DR) and post to Slack'
argument-hint: '[optional: date, or "dry run" to skip posting]'
---

Delegate this request to the **`daily-work-update`** subagent using the Agent tool.

The subagent must load these skills before acting: `daily-work-update`.

If the request below is empty, ask what is needed rather than guessing.

## Request

$ARGUMENTS
