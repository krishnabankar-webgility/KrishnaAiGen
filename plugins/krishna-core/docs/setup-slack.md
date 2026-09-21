# Slack — setup and workflow

## What this gives Claude

Posting the daily digest, Jenkins build notifications, and Kibana log-analysis reports to the
right channel, plus reading threads when asked — via `slack-automation`/`/slack`,
`daily-work-update`, `ship-to-qa`, and `wd-es-kibana`.

## One-time setup

1. **Bot token**: a Slack app with a bot token (`xoxb-...`) and the scopes those skills need
   (`chat:write`, `channels:read`, and `channels:history`/`groups:history` if reading threads
   matters). Whoever manages the Webgility Slack workspace's app settings issues this — it is
   not something you generate solo unless you're also the workspace admin.
2. In `wg-ai-workspace/.env`:
   ```
   SLACK_BOT_TOKEN=<xoxb-... from step 1>
   SLACK_REPORT_CHANNEL_ID=<channel ID the daily digest / reports post to>
   SLACK_PERF_CHANNEL_ID=<channel ID performance/Kibana reports post to>
   ```
   These three aren't read by the local MCP server code itself — they're referenced *by name*
   inside the skills/agents above (`slack-integration`, `daily-work-update`, `ship-to-qa`,
   `wd-es-kibana`) so the channel destinations live in one place instead of being hardcoded into
   each skill.
3. **`SLACK_TEAM_ID`** (a **Windows user environment variable**, not `.env` — matches
   `preflight.ps1`'s expectation) is needed only if you activate the local `slack` MCP server in
   `wg-mcp-optional.json` (currently inactive — see below); the `@modelcontextprotocol/server-slack`
   package it runs requires it directly, hardcoded there today as `T7XA2G1MW` for convenience.
   The primary path (next section) doesn't need it at all.

## The primary path: claude.ai connector

Per the root [CLAUDE.md](../../../CLAUDE.md), Slack is also one of the claude.ai connectors,
already authorized on the account — that path needs none of the above and works in web/browser
Claude too. The local server in `wg-mcp-optional.json` exists as a fallback, same reasoning as
the Jira/Confluence one in [setup-atlassian.md](setup-atlassian.md) — not merged into the active
`wg-mcp.json` on purpose, to avoid two copies of every Slack tool in one session.

## Verify

Ask: *"post 'test' to the report channel"* (then delete it), or *"list the last 5 messages in
<channel>"* if only read access matters right now.

## Workflow in short

`daily-work-update` posts Krishna's digest on its own schedule/trigger. `ship-to-qa`
notifies on build completion. `wd-es-kibana` posts its daily log-analysis summary. All three
route their actual message content and timing through their own skill file — this doc only
covers getting the token and channel IDs in place.

## Changing behavior

| To change | Edit |
|---|---|
| Bot token, channel IDs | `wg-ai-workspace/.env` |
| Digest format/schedule | `plugins/krishna-core/skills/daily-work-update/` |
| Which channel a given report goes to | the referencing skill/agent file (see the list above) — they read the env var by name, so changing the `.env` value alone is usually enough |
| Local fallback server | `KrishnaAiGen/.claude/mcp/wg-mcp-optional.json` → merge into `wg-mcp.json`, then `sync-workspace.ps1` |
