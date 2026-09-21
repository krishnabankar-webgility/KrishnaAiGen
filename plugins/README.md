# Claude agentic workflow — install and layout

This is the Claude Code equivalent of the `.cursor/` and `.github/` agent systems in this
repo. Unlike those, it is **installed once per machine** rather than copied into each repo,
so the same agents, skills and commands are available in every session — VS Code extension,
desktop app, or `claude` on the command line — from any working directory, in both
`C:\WG-Agentic` and `C:\WG-Agentic 2`.

---

## Install (one time)

**Step-by-step walkthrough: [INSTALL.md](INSTALL.md)** — where these lines get typed, what
each one does, and what "restart" means for each Claude surface. Read that if anything below
is unclear.

**Per-integration setup and the full picture: [docs/MASTER-WORKFLOW.md](docs/MASTER-WORKFLOW.md)**
— one doc per third-party system (Bitbucket, Jenkins, Jira/Confluence, Slack, SQL Server/CIS DB,
QuickBooks Desktop, remote VM/RDP, web/browser Claude), plus how a session flows and exactly
which file to edit to change any part of it.

The short version — typed into the **Claude chat box**, not a terminal:

```
/plugin marketplace add C:\WG-Agentic\KrishnaAiGen
/plugin install krishna-core@krishnaaigen
/plugin install wd-core@krishnaaigen
```

Then start a new session. You should see the **workspace readiness card** appear at the top
of it — that is the `SessionStart` preflight confirming it is live.

Verify:

```
/plugin          # both plugins listed as installed
/agents          # 14 personal + 21 wd-* agents
/mcp             # 11 local servers + your claude.ai connectors
```

Typing `/` should now offer `/jira`, `/git`, `/bitbucket`, `/customization`, `/ship-to-qa`,
`/kibana`, `/confluence`, `/slack`, `/db`, `/daily-update`, `/sys-fix`, `/learn`, `/route`.

### Updating later

The plugins are read from this directory, so `git pull` here updates them. Run
`/plugin marketplace update krishnaaigen` if a new plugin is added to the marketplace file.

---

## What is in here

```
KrishnaAiGen/
  .claude-plugin/marketplace.json     the marketplace both plugins are installed from
  .claude/
    mcp/wg-mcp.json                   SOURCE OF TRUTH for local MCP servers
    mcp/wg-mcp-optional.json          connector-duplicating servers, not active
    scripts/sync-workspace.ps1        distributes .mcp.json + CLAUDE.md to both trees
  plugins/
    krishna-core/
      agents/      16   personal specialists (jira, git, bitbucket, slack, db, confluence,
                        daily-update, dev-customization, sys-troubleshoot, kibana, ship-to-qa,
                        krishnaaigen router, krishnaaigen-autonomous, agent-learning,
                        skill-author, memory-gardener)
      skills/      19   the 17 ported .cursor/skill-library packs + ticket-context +
                        resume-work + krishnaaigen-skill-evolution (rewritten for the
                        plugin era — see "Standing behavior" below)
      commands/    14   thin launchers onto the agents above, + /agents-list
      hooks/            SessionStart preflight
      scripts/          preflight.ps1, approve-mcp-trust.py (see "One-time setup extras")
      reference/        archived Copilot prompts (not active — see its README)
      docs/             per-integration setup (Bitbucket/Jenkins/Atlassian/Slack/SQL/RDP/QB),
                        memory-behavior.md, web-claude-access.md, and MASTER-WORKFLOW.md — the
                        single doc tying all of it together, start there
    wd-core/
      agents/      21   16 wd-* domain routers + wd-lead / wd-dev / wd-qa / wd-review / wd-scout
      skills/      13   wrappers onto unify-enterprise/.github/skills/
```

---

## The two design rules

**1. Behavior lives in skills; agents stay thin.**
An agent file says which skills to load and how to decide. The operational detail — the Jira
section numbers, the Jenkins pipeline, the QA templates — lives in a skill. That is what keeps
a session's context small: only the skills that match the work get loaded.

Skills over ~15 KB are split: `SKILL.md` is a map with an index, `reference.md` holds the full
rules and is read on demand.

**2. Nothing that the WD team maintains is copied.**
The `wd-core` agents and skills are *routers*. `wd-posting` does not contain a copy of
`unify-enterprise/.github/agents/wd-posting.md` — it reads that file at run time. The team
edits their file; the next session picks it up. No sync step, no drift.

The same is deliberately **not** true of the personal `.cursor/skill-library/` packs: those
were copied into `plugins/krishna-core/skills/`, because Cursor is no longer in use and
`plugins/` is now the live copy. If you edit one, edit the one under `plugins/`.

---

## MCP servers

Jira, Confluence, Slack, Gmail, Calendar, Drive and HubSpot come from the **claude.ai
connectors** already authorized on the account. They need no local process.

The 11 servers in `.claude/mcp/wg-mcp.json` are the ones connectors do not cover:

| Server | Purpose |
|---|---|
| `bitbucket` | PRs, branches, repo metadata |
| `jenkins` | Trigger and poll the UnifyEnterprise build |
| `kibana-logs` | CIS / internal Elasticsearch |
| `wo-log` | WO production Elasticsearch |
| `redis` | Lock and queue inspection |
| `cis-db-proxy` | CIS PostgreSQL, read-only |
| `wo-db`, `cns-db`, `cws-db` | WO / CNS / CWS databases, read-only |
| `mssql-winauth` | WD local dev SQL Server (Windows auth) |
| `mssql-sqlauth` | WD restored customer databases (SQL auth) |

They all read credentials from `C:\WG-Agentic\wg-ai-workspace\.env`, and their paths are
absolute so they work from any directory.

`wg-mcp-optional.json` holds `atlassian`, `slack`, `jira` and `google-workspace` — local
equivalents of the connectors. They are **not** active, because running both would give you
two copies of every Jira and Slack tool. Merge them into `wg-mcp.json` only if a connector
becomes unavailable.

### Changing the MCP setup

Edit `.claude/mcp/wg-mcp.json`, then:

```
powershell -ExecutionPolicy Bypass -File C:\WG-Agentic\KrishnaAiGen\.claude\scripts\sync-workspace.ps1
```

It writes `.mcp.json` into `KrishnaAiGen`, `unify-enterprise` and `cloud-integration-systems` in
**both** trees, and regenerates `C:\WG-Agentic 2\CLAUDE.md`. It never touches
`wg-ai-workspace\.mcp.json` — that one is the team's and still works when you open Claude
directly in that repo. Pass `-WhatIf` to preview.

> The generated `.mcp.json` files land as **untracked** files in the two team repos. They are
> not meant to be committed. Add `.mcp.json` and `CLAUDE.local.md` to those repos' local
> excludes (`.git/info/exclude`) if they clutter your `git status`.

---

## One-time setup extras

**MCP approval, without clicking through it per project.** Claude Code requires a one-time
approval per project directory before it will start the local `.mcp.json` servers — normally
that means clicking "yes" the first time you open a session in each repo. To skip that entirely:

```
python "C:\WG-Agentic\KrishnaAiGen\plugins\krishna-core\scripts\approve-mcp-trust.py"
```

Run once. It pre-approves all 11 servers for every repo, both trees, in every path-spelling
Windows tools produce for the same directory. Safe to re-run after adding a new repo or server.
This has to be run by you — Claude Code's own guardrail refuses to let an agent edit its own
state file (`~/.claude.json`) on its own, which is exactly the right call here.

**Permission mode.** `permissions.defaultMode` is set to `"acceptEdits"` in
`C:\Users\<you>\.claude\settings.json` (user-level — every surface reads this file) so routine
edits and tool calls proceed without a prompt; Claude still asks before something genuinely
destructive. Change it with the `/config` command, or ask Claude to change it via the
`update-config` skill.

## Standing behavior (not a file you install — how sessions are expected to act)

- **Repeats get named, not re-explained.** When you teach something that matches an earlier
  correction, the session says so ("same rule as `<skill>`") and does the work — it doesn't
  re-ask for details already on file, and it folds new patterns into a skill or memory
  immediately rather than waiting to be asked. See `krishnaaigen-skill-evolution`.
- **Memory moves through live -> archived -> permanently deleted.** `memory-gardener`
  archives a ticket-tied memory right away once it's Done via RFT + a QA comment; a ticket
  closed some other way waits for 15 idle days; a still-open ticket is never archived on idle
  time alone; non-ticket memory just uses the 15-day-idle rule. Archived memory is skipped by
  default on routine reads (`ticket-context`, `resume-work`) — named or specifically-asked-for
  access only. If an archived file then sits untouched for 15 *more* days on already-finished
  work, it's permanently deleted (with a one-line entry in `_archive/_deleted-log.md` first) —
  the only step here that isn't reversible.
- **A session resumes from anywhere.** Claude's own memory already reaches the CLI, the VS Code
  extension and the desktop app (same account, same machine). For a web session or a different
  machine, `resume-work` reads/writes a short git-tracked resume note instead.

## Seeing and invoking agents directly

Type `@` in the chat box — Claude Code's agent-mention autocomplete lists every installed
subagent, personal and `wd-core` alike, and selecting one runs that agent on your message
directly (no routing through a conversation first). Or just describe the task in plain language
and let the routing table in `C:\WG-Agentic\CLAUDE.md` pick the right one.

For a plain list instead of the autocomplete UI, run `/agents-list` (optionally filtered, e.g.
`/agents-list payout`) — prints every personal and `wd-core` agent with a one-line description.

## Credentials

Never in a file that gets committed, never printed. They live in:

- **Windows user environment variables** — `BITBUCKET_TOKEN`, `BITBUCKET_USERNAME`,
  `SLACK_BOT_TOKEN`, `SLACK_TEAM_ID`, `KIBANA_WD_AUTH`, `JIRA_API_TOKEN`,
  `GOOGLE_OAUTH_CLIENT_ID` / `_SECRET`, `USER_GOOGLE_EMAIL`.
- **`C:\WG-Agentic\wg-ai-workspace\.env`** — what the local MCP servers read.

The session preflight reports which of these are **missing** by name. It never reads a value.

`BITBUCKET_TOKEN` must be a Bitbucket **HTTP access token** (repo settings to Access tokens),
not an Atlassian API token from `id.atlassian.com`. The username is the account slug
`krishnabankar`, not the email — `@` breaks the remote URL.

---

## How a session actually flows

1. **SessionStart** runs `preflight.ps1`: branch and dirty state for all 8 repo checkouts,
   which credentials are missing, whether `.env` is there, and the routing table.
2. **You describe the work.** Skills whose `description` matches load themselves; the right
   subagent is picked by its description. The routing table in `C:\WG-Agentic\CLAUDE.md` is
   the backstop, and `/route` forces the router agent if you would rather it decide.
3. **On a ticket**, `ticket-context` pulls `Reference/<TICKET>/` and the `memories/` notes
   before anything is planned.
4. **Corrections stick.** `/learn` writes the fix into the skill file so the next session
   starts from the corrected version.

---

## Web and cloud Claude

Those cannot install a local plugin. They can read this repo from GitHub, which is why the
plugin lives in a pushed repo rather than in `~/.claude`. Point a web session at
`plugins/krishna-core/skills/<name>/SKILL.md` and it works from the same instructions.
