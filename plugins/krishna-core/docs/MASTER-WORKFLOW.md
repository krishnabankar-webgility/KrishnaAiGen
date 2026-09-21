# The Claude agentic workflow — how it works, first-time setup, and where to change it

One doc that ties the rest together: what this system is, the complete manual setup for a new
machine or a new team member, and — the part that matters most day to day — exactly which file
to touch to make the flow behave differently.

## What this is

A **Claude Code plugin marketplace** (`krishna-core` + `wd-core`, from
`KrishnaAiGen/.claude-plugin/marketplace.json`) installed once per machine, giving every Claude
surface on it — CLI, VS Code extension, desktop app — the same agents, skills, commands, and MCP
server access, from any working directory under `C:\WG-Agentic` or `C:\WG-Agentic 2`. Full
layout and design rules: [../README.md](../README.md).

## First-time setup, start to finish

1. **Open the right folder in VS Code.** `C:\WG-Agentic` itself — that's where the routing
   `CLAUDE.md` lives. `wg-ai-workspace\wg-agentic.code-workspace` now also opens straight to
   that same root (it used to list 18 sibling folders, 13 of which don't exist on this machine,
   plus a stale `AskAI` path from before the rename — fixed to a single correct root).
2. **Install the plugins** — step by step in [../INSTALL.md](../INSTALL.md); short version is
   three `/plugin` commands typed into the Claude chat box, then a new session.
3. **Trust the local MCP servers without a per-project click-through**: run
   `python KrishnaAiGen/plugins/krishna-core/scripts/approve-mcp-trust.py` once. This has to be
   you, not Claude — Claude Code's own guardrail refuses to let an agent edit its own state file.
4. **Set `permissions.defaultMode: "acceptEdits"`** in `~/.claude/settings.json` (already done
   on this machine) so routine work doesn't stop for a permission prompt every step.
5. **Fill in the credentials each integration needs** — one doc per integration, each with its
   own step-by-step:

   | Integration | Doc |
   |---|---|
   | Bitbucket | [setup-bitbucket.md](setup-bitbucket.md) |
   | Jenkins | [setup-jenkins.md](setup-jenkins.md) |
   | Jira / Confluence / Atlassian | [setup-atlassian.md](setup-atlassian.md) |
   | Slack | [setup-slack.md](setup-slack.md) |
   | SQL Server / CIS DB / WO DB | [setup-sql-server.md](setup-sql-server.md) |
   | QuickBooks Desktop | [setup-quickbooks-desktop.md](setup-quickbooks-desktop.md) — honest: nothing live exists yet |
   | Remote VM / jump box (RDP, PSRemoting) | [setup-remote-access.md](setup-remote-access.md) |
   | Web/browser Claude | [web-claude-access.md](web-claude-access.md) — what already works and what the rest would take |

6. **Memory** — nothing to install; behavior and the file-by-file "what to edit" table are in
   [memory-behavior.md](memory-behavior.md).

## How a session actually flows, once set up

1. `SessionStart` runs `preflight.ps1` — prints branch/dirty state for all repo checkouts,
   which credentials are missing (names only, never values), and the routing table.
2. You describe the work in plain language. Skills load themselves when their `description`
   matches; the right subagent gets picked by its own description. `C:\WG-Agentic\CLAUDE.md`'s
   routing table is the backstop, and `/route` forces the router agent if you'd rather it decide.
3. On a ticket, `ticket-context` loads `Reference/<TICKET>/` and the relevant `memories/` notes
   before anything is planned — skipping this is how the same investigation gets redone.
4. Corrections stick: teach something once and, per `krishnaaigen-skill-evolution`, a matching
   pattern gets recognized and named rather than re-explained, and a genuinely new pattern gets
   folded into the right skill/agent/memory immediately, reported after the fact.
5. `memory-gardener` keeps memory from growing without bound — see
   [memory-behavior.md](memory-behavior.md) for exactly when something archives vs. gets
   permanently deleted.

## Where to change *this*, specifically

| You want to... | Edit |
|---|---|
| Add a new repo/project to the workspace | Clone it under both `C:\WG-Agentic` and `C:\WG-Agentic 2`; add a row to the "Repos here" table and, if it needs its own MCP servers, to `KrishnaAiGen/.claude/mcp/wg-mcp.json`, then `sync-workspace.ps1` |
| Add reference material for a ticket | Create `Reference/<TICKET-ID>/` and drop in screenshots/logs/payloads/RCAs — `ticket-context` finds it by folder name, no registration needed |
| Point Claude at a new log source | Add it to the relevant skill (`wd-es-kibana` for Kibana/ES, `sys-troubleshoot`'s toolkit for Windows-native logs) rather than a generic "logs" setting — there isn't one; each log source is its own integration |
| Change which agent handles a task, or add a new one | The routing table in `C:\WG-Agentic\CLAUDE.md`, or invoke `skill-author` to scaffold a whole new agent/skill |
| Change a procedure (JQL, build steps, QA comment format, …) | That skill's `SKILL.md`/`reference.md` under `plugins/krishna-core/skills/` or `plugins/wd-core/skills/` |
| Change a fact instead of a procedure | Claude's native memory, or `unify-enterprise/memories/` — see [memory-behavior.md](memory-behavior.md) |
| Change local MCP server config (env vars, command, which servers exist) | `KrishnaAiGen/.claude/mcp/wg-mcp.json`, then `sync-workspace.ps1` — never hand-edit the generated `.mcp.json` copies |
| Change permission behavior (ask vs. accept-edits vs. plan) | `/config`, or `~/.claude/settings.json` directly (`permissions.defaultMode`) |
| See every agent and how to invoke one directly | `/agents-list`, or type `@` in the chat box for the native autocomplete |

## Sharing this with the team later

The design already keeps this generic rather than Krishna-only: every credential is named by
env var or connector, never hardcoded; the `wd-core` agents are thin routers onto the *team's*
own `unify-enterprise/.github/agents/` files rather than a personal copy; and this whole doc set
assumes someone else's `.env` and Windows user env vars, not these specific values. Handing it
to a teammate is: clone `KrishnaAiGen`, follow [../INSTALL.md](../INSTALL.md), then work through
the integration docs above for whichever ones they personally need.
