# Jira & Confluence (Atlassian) — setup and workflow

## The primary path needs no setup here

Jira and Confluence are covered by the **claude.ai Atlassian connector**, already authorized on
the account (`krishna.bankar@webgility.com`). It works in the CLI, the VS Code extension, the
desktop app, and web/browser Claude alike — nothing in this repo starts or configures it. This
is why `jira-automation`/`/jira` and `confluence-automation`/`/confluence` need no `.env` entry
for basic read/write issue and page work.

If a session ever reports the connector unavailable: that's an Anthropic-account-side
connection, not a local config problem — check **Settings -> Connectors** on claude.ai, not
anything in this repo. Re-authorizing there is the fix, not editing `.env` or `wg-mcp.json`.

## The local fallback (not active by default)

`KrishnaAiGen/.claude/mcp/wg-mcp-optional.json` defines local `jira` and `atlassian` MCP
servers as a backup path, in case the connector is ever unavailable for an extended stretch.
They are **deliberately not merged into `wg-mcp.json`** — running both would give every session
two copies of every Jira tool, and Claude would have to guess which one to call.

To activate one:

1. Get a **Jira API token** from `id.atlassian.com` -> Security -> API tokens (this is the
   generic Atlassian token — different from a Bitbucket access token, don't reuse one for the
   other).
2. In `wg-ai-workspace/.env`, `JIRA_API_TOKEN`, `JIRA_BASE_URL` and `JIRA_USER_EMAIL` already
   exist for other tooling. **Known mismatch to check first**: the `jira` entry in
   `wg-mcp-optional.json` reads `${JIRA_EMAIL}`, not `${JIRA_USER_EMAIL}` — confirm which name
   the specific npm package (`@nexus2520/jira-mcp-server`) actually expects before activating
   it; don't assume the existing `.env` key covers it as-is.
3. Merge the chosen server's block from `wg-mcp-optional.json` into `wg-mcp.json`, run
   `sync-workspace.ps1`, trust it once (or `approve-mcp-trust.py`).

## Verify

Ask: *"what's the title of <a ticket you know exists>"*. That alone proves read access without
needing to look at ticket content in the transcript.

## Workflow in short

`ticket-context` reads the issue (description, acceptance criteria, and **comments** — for
customer issues the real requirement is usually in a comment) before any code is touched.
`jira-automation`/`/jira` creates issues/subtasks, sets Story Points/OE, and manages the
Done-vs-RFT transition with the QA comment. `confluence-automation`/`/confluence` writes pages
and reports, including a QA-comment mirror for customer-issue documentation. Both read the JQL,
field-mapping and comment-format details from their own `SKILL.md`/`reference.md`, not from
this doc.

## Changing behavior

| To change | Edit |
|---|---|
| JQL, field mappings, RFT/Done rules, QA comment format | `plugins/krishna-core/skills/jira-workflow/` (`SKILL.md` + `reference.md`) |
| Confluence page templates, report format | `plugins/krishna-core/skills/confluence-workflow/` (`SKILL.md` + `reference.md`) |
| Local fallback server config | `KrishnaAiGen/.claude/mcp/wg-mcp-optional.json` → merge into `wg-mcp.json`, then `sync-workspace.ps1` |
