---
name: wd-callchain-refresh
description: 'WD Call Chain Refresh agent. Detects stale call chain files by comparing traced file lists against git history, re-traces stale call chains by reading changed source files directly, updates the call chain content, and resets the baseline commit hash. Fully autonomous — no handoffs needed.'
model: inherit
---

# wd-callchain-refresh — router to the team-maintained agent definition

Your full operating instructions are **not** in this file. They live in the
`unify-enterprise` repo, which the WD team maintains, so this router always
picks up their latest version instead of a stale copy.

## Step 1 — load your definition (mandatory)

Read **`.github/agents/wd-callchain-refresh.md`** relative to the `unify-enterprise` repo root.

If that file does not exist, you are not running inside `unify-enterprise`. Say so
and stop — do not improvise the agent's behavior. The repo lives at
`C:\WG-Agentic\unify-enterprise` (mirror: `C:\WG-Agentic 2\unify-enterprise`).

Also read **`CLAUDE.md`** at that repo root for architecture and module ownership.

## Step 2 — translate tool names

The file is written for GitHub Copilot. Map its tool names as you go:

| Copilot tool in the file | Use instead |
|---|---|
| `read`, `search` | `Read`, `Glob`, `Grep` |
| `edit` | `Edit`, `Write` |
| `execute` | `Bash` or `PowerShell` |
| `agent` | the `Agent` tool |
| `todo` | handled natively — ignore |
| `atlassian/*` | `mcp__claude_ai_Atlassian_Rovo__*` |
| `mssql-winauth/*`, `mssql-sqlauth/*` | `mcp__mssql-winauth__*`, `mcp__mssql-sqlauth__*` |

Its `handoffs:` block lists other agents — invoke those with the `Agent` tool using
the same `wd-*` name.

## Step 3 — follow it exactly

Then execute the request. Supporting context the file may point at:

- `.github/context/master/codebase-inventory.md` — module → agent map
- `.github/context/master/workflow.md` — the 5-stage dev cycle
- `.github/context/call-chains/` — traced call chains
- `.github/skills/` — triage, developer, qa, architect, sql-mcp, jira-integration
- `memories/` — durable per-module findings (one file per fact)
