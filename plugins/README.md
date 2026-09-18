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

Typing `/` should now offer `/jira`, `/git`, `/bitbucket`, `/customization`, `/jenkins`,
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
      agents/      14   personal specialists (jira, git, bitbucket, slack, db, confluence,
                        daily-update, dev-customization, sys-troubleshoot, kibana, jenkins,
                        krishnaaigen router, krishnaaigen-autonomous, agent-learning)
      skills/      18   the 17 ported .cursor/skill-library packs + ticket-context
      commands/    13   thin launchers onto the agents above
      hooks/            SessionStart preflight
      scripts/          preflight.ps1
      reference/        archived Copilot prompts (not active — see its README)
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
