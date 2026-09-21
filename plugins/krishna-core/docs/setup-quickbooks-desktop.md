# QuickBooks Desktop — current state (no live connector exists)

Being direct about this one: **there is no MCP server, plugin, or connector today that gives
Claude a live connection to QuickBooks Desktop.** Checked `wg-ai-workspace/.mcp-servers/` — the
only servers there are `cis-db-proxy`, `cns-db`, `cws-db`, `es-logs`, `jenkins`, `slack`,
`wd-db`, `wo-db`. Nothing QBXML/QBFC-shaped exists yet.

## The local sandbox company file

```
C:\Users\Public\Documents\Intuit\QuickBooks\Company Files\SellFromHome.qbw
```

Krishna's local testing/sandbox QBD company file — the one `UnifyDB` posts against locally.
Read/write **against this specific file** is fine for testing (it's local and disposable, not a
customer's data) — but see below: nothing today actually gives Claude a live connection to
drive that read/write itself. `.qbw` is a proprietary QuickBooks database format, not something
readable as plain bytes, so "access" here means through QuickBooks Desktop's own QBXML/QBFC
automation, not direct file I/O — `qbsdklog.txt` (`C:\ProgramData\Intuit\QuickBooks\qbsdklog.txt`)
is where every request/response WD already sends to it gets logged, and is the fastest way to
see what actually happened without a live connector at all. Full local-debugging path reference
(app logs, this SDK log, UnifyDB): `plugins/krishna-core/skills/wd-local-diagnostics/SKILL.md`.

## What Claude *can* already do

- Read and write the **integration code** in `unify-enterprise` that talks to QuickBooks
  Desktop via QBXML/QBFC — that's `wd-dev`/`wd-accounting`'s normal work, no connector needed,
  because it's editing source, not driving a live QB session.
- Use the **reflection-harness technique** documented in the UD-33220 memory note (see
  `ud-33220-payout-payment-null-memo.md`) to probe QBFC behavior *through the app's own compiled
  code*, run as a one-off diagnostic — not a standing connection Claude holds open itself.
- Query the local dev/customer SQL Server databases (`mssql-winauth`/`mssql-sqlauth`, see
  [setup-sql-server.md](setup-sql-server.md)) for what WD *recorded* about a QB posting, which
  is usually enough to diagnose a posting bug without touching QuickBooks directly.

## Why a live connector isn't a quick add

QuickBooks Desktop's automation surface (QBXML over `qbXMLRP32`, or QBFC) is COM-based,
single-threaded per company file, and tied to the exact machine QuickBooks Desktop is installed
and licensed on — plus QB itself prompts a one-time "allow this application" dialog per
application name the first time it connects, which an unattended MCP server can't click through.
Building one would mean a small local Windows service (or a stdio MCP server, same shape as the
others in `.mcp-servers/`) running QBFC calls on *this specific machine*, with its own approval
dialog to clear once. That's a real, scoped project — not a settings change — and worth doing
only if live QB queries (not code/DB access) turn out to be a recurring need.

## If you want this built

Say so specifically and it can be scoped properly: what operations it needs (read-only lookups
vs. posting), which company file(s), and whether it only ever needs to run on this machine or
needs to be reachable more broadly. Until then, this doc stays the honest record that the gap
exists rather than a setup guide for something that isn't there.
