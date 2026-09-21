---
description: 'Implementation done, ready for QA: Jenkins build for unify-enterprise, deploy to the QA share, set Jira RFT, notify Slack, post the QA comment — the full 10-step handoff'
argument-hint: '[branch name, or "status"]'
---

Delegate this request to the **`ship-to-qa`** subagent using the Agent tool.

The subagent must load these skills before acting: `ship-to-qa`, plus `vpn-smb-access` if the share fails and `slack-integration` for posting.

If the request below is empty, ask what is needed rather than guessing.

## Request

$ARGUMENTS
