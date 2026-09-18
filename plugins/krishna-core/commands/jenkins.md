---
description: 'Trigger a Jenkins build for unify-enterprise, deploy to the QA share, set Jira RFT, notify Slack'
argument-hint: '[branch name, or "status"]'
---

Delegate this request to the **`wd-jenkins-build`** subagent using the Agent tool.

The subagent must load these skills before acting: `wd-jenkins-build`, plus `vpn-smb-access` if the share fails and `slack-integration` for posting.

If the request below is empty, ask what is needed rather than guessing.

## Request

$ARGUMENTS
