# Web/browser Claude — what already works, and what closing the rest would take

Local setup (plugins, MCP servers, permission mode) is machine-and-account state under
`~/.claude` — a browser tab at claude.ai has no local filesystem and can't reach any of it.
This is a hard product boundary, not a config gap. This doc is the honest map of what already
works there today, and the real options for the rest — options, not something already built,
because closing the remaining gap means standing up internet-reachable infrastructure, which is
a decision with real security exposure, not a settings toggle.

## Already works on web, zero extra setup

- **The 7 claude.ai connectors** — Jira, Confluence, Slack, Gmail, Calendar, Drive, HubSpot.
  These are account-level, not local; a web session has exactly the same access as CLI/VS
  Code/desktop for all of them right now.
- **Reading this repo** — `KrishnaAiGen` is on GitHub, so pointing a web session at, say,
  `plugins/krishna-core/skills/jira-workflow/SKILL.md`'s GitHub URL and asking it to follow
  those instructions works — it's just reading a file, no MCP or plugin needed. Same for a
  `resume-work` resume note once it's pushed.

## Does not work, and can't without new infrastructure

- **Any local stdio MCP server** — `bitbucket`, `jenkins`, `kibana-logs`, the DB servers,
  `redis`. These are child processes this machine spawns; a browser can't spawn or talk to a
  local process, full stop.
- **The plugin marketplace** (`krishna-core`, `wd-core`) — claude.ai has no local plugin
  runtime. There's also no known "sync your plugins to web" feature today (the `syncClaudeAiSkills`
  setting goes the *other* direction — claude.ai skills sync down to local Claude Code, not the
  reverse).
- **Windows user environment variables** — irrelevant to a browser session; nothing to "share."

## The one real bridge: a remote MCP server

claude.ai supports **custom connectors** over Streamable HTTP/SSE — an MCP server reachable by
URL instead of spawned as a local process, added via **Settings -> Connectors -> Add custom
connector**. That's the only mechanism that would give a web session anything beyond the 7
connectors above. It needs three things none of which exist yet for these servers:

1. **The server itself running as a persistent HTTP service**, not a stdio process launched
   per-session — a genuine rewrite/redeploy of the transport layer, not a config change.
2. **A public (or at least internet-reachable) HTTPS endpoint** — hosted somewhere (a small
   cloud VM, a container service) or tunneled from this machine (Cloudflare Tunnel, ngrok) if
   you'd rather not stand up separate hosting.
3. **An auth layer at that endpoint** — OAuth2 (the more correct long-term answer) or a static
   bearer token entered once when adding the connector (simpler, but that token now travels
   over the internet and must be treated like a password, not like a local `.env` value).

## Which of the local-only servers would even make sense to expose

Ranked by how much this actually helps vs. how much it exposes:

| Server | Exposing it to web makes sense? | Why |
|---|---|---|
| `bitbucket`, `jenkins`, `kibana-logs` | Reasonable candidate | Already scoped, already token-gated at the source (Bitbucket/Jenkins/ES credentials), mostly read or CI-trigger actions |
| `redis` | Only with care | Lock/queue inspection is low-risk read-only, but it's a direct line into internal infra — gate behind a narrow read-only view, not the raw protocol |
| `cis-db-proxy`, `wo-db`, `cns-db`, `cws-db`, `mssql-winauth`, `mssql-sqlauth` | **Don't, without a real network story** | Direct or near-direct database access. Exposing a database (even read-only) to the public internet behind just a bearer token is a materially different risk than a local process only this machine can reach — this needs at minimum a VPN-gated tunnel, ideally proper network-level restriction, and should be an explicit decision, not a default. |

## What I can and can't do here

I can write the actual remote-MCP server code (the existing stdio servers, adapted to
Streamable HTTP transport) and a step-by-step deployment doc once a hosting approach is picked.
I can't provision cloud hosting, register a tunnel service, obtain a domain/TLS cert, or decide
which of the DB-backed servers is worth the exposure — those need your call, and some need
billing/account access I don't have. Nothing above is built yet; this is the map for deciding
what's worth building, not a changelog of what already happened.

If you want to move on this: which servers (from the "reasonable candidate" row) and which
hosting style (your own tunnel from this machine vs. a small cloud VM) is the actual decision
needed before anything gets written.
