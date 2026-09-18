---
name: daily-work-update
description: "Use when: generating Krishna's daily or morning work digest - Yesterday / Today / Pending / Blockers / TL;DR - by pulling Jira (UD), Slack mentions and threads, Bitbucket unify-enterprise commits and PRs, Google Calendar/Gmail/Drive, and HubSpot customer-issue comments, then posting to Slack #my-daily-update."
---

# daily-work-update

Full operational rules live in **`reference.md`** next to this file. **Read `reference.md` before taking any action** — it is the authoritative source and this page is only a map of it.

## Sections in `reference.md`

- (line 3) Purpose
- (line 51) Identity / fixed inputs
- (line 73) Required secrets / MCP servers
- (line 87) Time window
- (line 99) Data sources & queries
- (line 376) Categorization rules (where each item lands)
- (line 412) Output format (Slack-flavored markdown)
- (line 504) Access boundaries
- (line 520) Posting rules
- (line 533) Scheduling
- (line 549) Cursor Automation setup (copy/paste-ready)
- (line 623) Output for Cursor session (when invoked manually)
- (line 635) Failure / fallback behavior
- (line 647) Privacy & safety
- (line 656) Learnings locked in (do not re-discover)
- (line 690) Future extensions (not built yet)

> Ported from `.cursor/skill-library/daily-work-update.skill.md` (canonical Cursor/Copilot copy). Keep both in sync — see the `krishnaaigen-skill-evolution` skill.
