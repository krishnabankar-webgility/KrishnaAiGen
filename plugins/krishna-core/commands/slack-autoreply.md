---
description: 'Slack DM auto-reply (KrishnaAiGen app): status, dry run, run now, pause/resume, go live or back to proposals'
argument-hint: '[status | dry run | run | pause [Nh] | resume | live | shadow | answers live|shadow | away live|shadow | rule: ...]'
---

Delegate this request to the **`slack-auto-responder`** subagent using the Agent tool.

The subagent must load these skills before acting: `slack-auto-reply`.

If the request below is empty, treat it as `status`.

## Request

$ARGUMENTS
