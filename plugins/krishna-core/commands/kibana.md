---
description: 'Elasticsearch / Kibana log analysis: daily WD log report, error spike investigation, health check'
argument-hint: '[e.g. "daily report for today" or "error spike for subscriber 91162"]'
---

Delegate this request to the **`wd-es-kibana`** subagent using the Agent tool.

The subagent must load these skills before acting: `wd-es-kibana`, and `slack-integration` if posting.

If the request below is empty, ask what is needed rather than guessing.

## Request

$ARGUMENTS
