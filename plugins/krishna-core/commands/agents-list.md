---
description: 'List every personal and wd-core agent available in this session, with what each does and how to invoke it directly'
argument-hint: '[optional: a word to filter by, e.g. "payout" or "jira"]'
---

Print this table (filtered to rows matching "$ARGUMENTS" if it's non-empty; otherwise print all
of it). Do not call any of these agents — just list them. Add one line above the table stating
how to invoke one directly: type `@` followed by the agent name in the chat box, or just describe
the task in plain language and let routing pick it.

## Personal (krishna-core)

| Agent | What it does |
|---|---|
| `jira-automation` | Jira UD: create, subtasks, Story Points/OE, Done vs RFT, QA comment, sprints |
| `git-automation` | Commit, push, branch sync (master-first) |
| `bitbucket-automation` | unify-enterprise branch + PR on Bitbucket |
| `confluence-automation` | Confluence pages, reports, QA comment mirror |
| `slack-automation` | Post/read Slack via MCP |
| `db-automation` | Local SQL Server restore/attach/query |
| `dev-customization` | Customer-specific customization (CIM/FR/CFC) with node-gating |
| `ship-to-qa` | Implementation done → hand off to QA: Jenkins build, QA share, Jira RFT, Slack notify, QA comment (10 steps) |
| `wd-es-kibana` | Kibana/Elasticsearch log analysis and daily report |
| `daily-work-update` | Krishna's daily digest to Slack |
| `sys-troubleshoot` | Windows/VPN/SMB/network/VM diagnostics |
| `agent-learning` | Persist a correction into a skill or into memory |
| `skill-author` | Build a brand-new skill or agent for this plugin |
| `memory-gardener` | Archive stale/resolved memory (never deletes), with a report |
| `krishnaaigen` | Master router - infers which specialist(s) apply |
| `krishnaaigen-autonomous` | VS Code tooling variant of the router |

## Webgility Desktop (wd-core)

**Roles** - the order you normally want them:

| Agent | What it does |
|---|---|
| `wd-scout` | Read-only: "where is X", "how does Y work", "what calls this" |
| `wd-lead` | Plans the change, assesses blast radius, names the owning domain agent |
| `wd-dev` | Writes the code, following repo conventions and node-gating |
| `wd-qa` | Test scenarios, regression scope, the QA Testing comment |
| `wd-review` | Reviews a diff before the PR - read-only |

**Domain agents** - route to the team's own `.github/agents/` definitions in `unify-enterprise`:

| Agent | Module |
|---|---|
| `wd-master` | Entry point - routes a ticket to the right domain agent |
| `wd-posting` | Order download from CIS, post-to-accounting, AutoSynch |
| `wd-payout-settlement` | Payout download, 4-step post (payments/refunds/adjustments/fees) |
| `wd-payout-shopify` | Shopify Payments payouts |
| `wd-payout-walmart` | Walmart DSV payout parsing |
| `wd-amazon-settlement` | Amazon Settlement download and posting |
| `wd-accounting` | QB Desktop/QBO/NetSuite/Avalara adapters |
| `wd-inventory` | Inventory sync, POS, Purchase Orders, Lokad |
| `wd-channels` | CIS adapter, store profile setup, automation rules |
| `wd-platform` | Scheduler, notifications, analytics, CRM |
| `wd-shipping` (+ `-ups`, `-usps`, `-amazon`) | Carrier integrations |
| `wd-architect` | Cross-module design review |
| `wd-callchain-refresh` | Re-traces stale call-chain docs |

Slash-command shortcuts for the most-used ones: `/jira`, `/git`, `/bitbucket`, `/customization`,
`/ship-to-qa`, `/kibana`, `/confluence`, `/slack`, `/db`, `/daily-update`, `/sys-fix`, `/learn`,
`/route`.
