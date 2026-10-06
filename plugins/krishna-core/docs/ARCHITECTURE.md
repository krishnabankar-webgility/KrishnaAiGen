# System architecture — the Claude agentic workflow

The single map of how this system is built and how it runs, from a cold machine to a live
session. For step-by-step setup use [../INSTALL.md](../INSTALL.md); for per-integration
credentials and "what to edit to change X" use [MASTER-WORKFLOW.md](MASTER-WORKFLOW.md) — this
doc is the structural/flow picture those two build on.

---

## 1. What this is, in one paragraph

A **Claude Code plugin marketplace** — two plugins, `krishna-core` (personal) and `wd-core` (WD
team routers) — installed **once per machine** rather than copied into each repo. Every Claude
surface on that machine (CLI, VS Code extension, desktop app) then shares the same agents,
skills, commands, and local MCP-server access, from any working directory under `C:\WG-Agentic`
or `C:\WG-Agentic 2`. Jira/Confluence/Slack/Gmail/Calendar/Drive/HubSpot come from **claude.ai
connectors** instead — those also reach a **web/browser** session, which can't see the local
plugin install at all (see [web-claude-access.md](web-claude-access.md)).

## 2. High-level architecture

```
                         ┌─────────────────────────────────────────┐
                         │   Claude surface (pick one per session)  │
                         │   CLI · VS Code ext · Desktop app · Web  │
                         └───────────────────┬───────────────────────┘
                                              │
              local surfaces only ───────────┼──────────── web/browser only
                                              │
     ┌────────────────────────────────────┐  │  ┌───────────────────────────┐
     │  krishnaaigen plugin marketplace    │  │  │  claude.ai connectors      │
     │  (installed once, ~/.claude)        │  │  │  (Jira, Confluence, Slack, │
     │  ├─ krishna-core (16 agents,        │  │  │   Gmail, Calendar, Drive,  │
     │  │   19 skills, 14 commands)        │  │  │   HubSpot)                 │
     │  └─ wd-core (21 agents, 13 skills   │  │  └───────────────────────────┘
     │      — thin routers onto the        │  │
     │      team's own unify-enterprise    │  │            (both reach here)
     │      .github/ files)                │  │
     └───────────────────┬──────────────────┘  │
                          │                     │
     ┌────────────────────▼──────────────────┐  │
     │  Local MCP servers (.mcp.json,          │  │
     │  generated from wg-mcp.json)            │◄─┘
     │  bitbucket · jenkins · kibana-logs ·    │
     │  wo-log · redis · 6 DB servers          │
     │  — credentials from wg-ai-workspace/.env│
     └──────────────────────────────────────────┘
                          │
     ┌────────────────────▼──────────────────┐
     │  Claude's own memory                    │
     │  native (per-machine, ~/.claude) +      │
     │  repo-tracked (unify-enterprise/memories│
     │  , git-tracked resume notes)            │
     └──────────────────────────────────────────┘
```

`C:\WG-Agentic\CLAUDE.md` (and its `C:\WG-Agentic 2` twin) is the **routing brain** every
session reads first — it names the repos, the routing table, and the standing rules; everything
else in the plugin exists to be reached *from* that file.

## 3. Setup — first time on a machine

Full walkthrough: [../INSTALL.md](../INSTALL.md). Summary:

1. `/plugin marketplace add C:\WG-Agentic\KrishnaAiGen` then `/plugin install krishna-core@krishnaaigen` and `wd-core@krishnaaigen` — typed in the Claude chat box, not a terminal.
2. Run `approve-mcp-trust.py` once (pre-approves the 11 local MCP servers for every repo/tree — the one step that can't be automated, because Claude Code's own guardrail refuses to let an agent edit its own trust state).
3. Fill in credentials per integration — [MASTER-WORKFLOW.md](MASTER-WORKFLOW.md) links each one.
4. Open a new session and confirm the workspace-readiness card appears.

## 4. Directory map — what's where

```
C:\WG-Agentic\                          the workspace root — open THIS in VS Code
  CLAUDE.md                             routing brain, read by every session
  Reference\<TICKET-ID>\                per-ticket material (screenshots, logs, the prompt file)
  KrishnaAiGen\                         this repo — also a separate .NET console app (unrelated
                                         product; see its own README.md) that happens to share
                                         the repo with the plugin system below
    .claude-plugin\marketplace.json     the marketplace both plugins install from
    .claude\mcp\wg-mcp.json             SOURCE OF TRUTH for local MCP servers
    .claude\scripts\sync-workspace.ps1  distributes .mcp.json + CLAUDE.md to both trees
    plugins\
      krishna-core\
        agents\          personal specialists — one .md per agent
        skills\          SKILL.md (+ reference.md when large) per skill
        commands\        thin /slash-command launchers onto the agents
        hooks\           SessionStart preflight
        scripts\         preflight.ps1, approve-mcp-trust.py
        docs\            this file + per-integration setup + MASTER-WORKFLOW.md
        reference\       archived Copilot prompts — not active
      wd-core\
        agents\          16 wd-* domain routers + wd-lead/dev/qa/review/scout
        skills\          wrappers that read unify-enterprise/.github/skills/ at run time
    .cursor\, .github\   historical Cursor/Copilot content — nothing reads these anymore
  unify-enterprise\                     WD product code (the actual thing being worked on)
  cloud-integration-systems\            CIS — the platform REST API
  wg-ai-workspace\                      owns .env and the local MCP server source code
C:\WG-Agentic 2\                        second working tree, same layout, often a different branch
```

## 5. Execution flow — what happens when a session starts

Same regardless of surface (CLI, VS Code extension, desktop app) because all three read the same
`~/.claude` install:

1. **`SessionStart` hook fires** — runs `preflight.ps1`. Prints a readiness card: branch/dirty
   state for all 8 repo checkouts (both trees × 4 repos), which credentials are missing **by
   name only** (never a value), and the routing table.
2. **You describe the work in plain language.** Two dispatch mechanisms run in parallel:
   - **Skills** self-load when their `description` frontmatter matches the request.
   - **Subagents** get picked by the `Agent` tool matching their own description, or you invoke
     one directly with `@agent-name` or its `/command`.
   `C:\WG-Agentic\CLAUDE.md`'s routing table is the backstop when neither is obvious — `/route`
   forces the `krishnaaigen` master router to decide explicitly.
3. **Starting a ticket:** `ticket-context` loads first — `Reference/<TICKET>/` (including the
   prompt-history file named after the ticket), prior `memories/` notes, and the Jira issue
   itself, before anything is planned or coded.
4. **Corrections and new patterns persist immediately** — `krishnaaigen-skill-evolution` decides
   whether something is a procedure (→ a skill), a fact (→ memory), or a routing change (→
   `CLAUDE.md`), edits it in the same turn, and reports what changed after.
5. **`memory-gardener`** runs periodically (or on request) to archive/delete memory per the
   lifecycle in [memory-behavior.md](memory-behavior.md) — nothing about this happens on session
   start automatically; it's invoked, not scheduled.

**Web/browser Claude** skips steps 1 and most of step 2 (no local hook, no local MCP, no
plugin) — it can still read this repo from GitHub and follow a skill's instructions if you point
it at the file directly, and reach the 7 claude.ai connectors identically to local sessions.

## 6. Claude's memory — where it actually lives

| Store | Path | Reachable from |
|---|---|---|
| Native auto-memory | `~/.claude/projects/<sanitized-cwd>/memory/` — `MEMORY.md` index + one file per fact | CLI, VS Code extension, desktop app (same machine, same account). **Not** web. |
| Repo-tracked memory | `unify-enterprise/memories/<module>/*.{md,json}`, plus the customization write-ups at `unify-enterprise/memories/customizations/<TICKET>-<slug>.md` | Anywhere the repo is cloned — including a web session reading it from GitHub. |
| Resume notes | `Reference/<TICKET>/RESUME.md` or `Reference/_active-work.md` — git-tracked | Same as repo-tracked memory; this is the one that closes the web-session gap for in-progress state specifically (`resume-work` skill). |

Lifecycle (live → archived → permanently deleted) and exactly which rule fires when:
[memory-behavior.md](memory-behavior.md).

## 7. Full inventory

**`krishna-core`** — 16 agents, 19 skills, 14 commands. Run `/agents-list` any time for the
live, descriptive version of this table (filterable, e.g. `/agents-list payout`) — this is a
structural summary, not the source of truth:

| Category | Agents |
|---|---|
| Cross-repo automation | `jira-automation`, `git-automation`, `bitbucket-automation`, `confluence-automation`, `slack-automation`, `db-automation` |
| WD-specific | `dev-customization`, `ship-to-qa`, `wd-es-kibana`, `sys-troubleshoot` |
| Meta / self-maintaining | `krishnaaigen` (master router), `krishnaaigen-autonomous`, `agent-learning`, `skill-author`, `memory-gardener` |
| Reporting | `daily-work-update` |

Skills without a dedicated agent (loaded directly when their trigger matches): `ticket-context`,
`resume-work`, `wd-local-diagnostics`, `krishnaaigen-skill-evolution`,
`krishnaaigen-ephemeral-output`, plus the skill half of every agent above (`jira-workflow`,
`git-sync`, `bitbucket-unify-enterprise`, `confluence-workflow`, `slack-integration`,
`db-restore`, `dev-customization-expertise` + `dev-customization-workflow`, `wd-jenkins-build`
skill folder now named `ship-to-qa`, `vpn-smb-access`, `network-profile-fix`,
`sys-cleanup-optimization`, `remote-vm-management`).

**`wd-core`** — 21 agents (`wd-scout`/`wd-lead`/`wd-dev`/`wd-qa`/`wd-review` as the role
pipeline, plus 16 `wd-*` domain routers), 13 skills. These don't carry their own operational
content — they read `unify-enterprise/.github/agents/` and `.github/skills/` at run time, so the
WD team's own edits take effect immediately with no sync step.

## 8. Credentials, plugins, MCP — where each config file lives

| Concern | File |
|---|---|
| Plugin registration | `~/.claude/settings.json` → `enabledPlugins`, `extraKnownMarketplaces` (machine/account-wide, not per-repo) |
| Permission mode (accept-edits vs. ask) | `~/.claude/settings.json` → `permissions.defaultMode` |
| MCP server definitions | `KrishnaAiGen/.claude/mcp/wg-mcp.json` (active) / `wg-mcp-optional.json` (connector-duplicating, inactive) |
| Generated per-repo MCP config | `.mcp.json` at each repo root and at each tree root — regenerated by `sync-workspace.ps1`, never hand-edited |
| MCP per-project trust | `~/.claude.json` → `projects.<cwd>.enabledMcpjsonServers` — pre-approved in bulk by `approve-mcp-trust.py` |
| Credentials (local MCP servers, git-over-HTTPS) | `wg-ai-workspace/.env` |
| Credentials (Windows-env-var-only items — no `.env` equivalent, e.g. `QBD_CREDS`, `RDP_UN`/`RDP_PWD`) | Windows **user** environment variables |
| Jira/Confluence/Slack/Gmail/Calendar/Drive/HubSpot | claude.ai account-level connectors — not a file at all |

Full one-time setup for each row: [MASTER-WORKFLOW.md](MASTER-WORKFLOW.md) and the
`setup-*.md` docs next to it.

## 9. Extending or changing the system

This doc explains the shape; **[MASTER-WORKFLOW.md](MASTER-WORKFLOW.md)** has the "I want to
change X, edit Y" table — new repo, new log source, new agent, new MCP server, new permission
mode, all covered there rather than duplicated here.
