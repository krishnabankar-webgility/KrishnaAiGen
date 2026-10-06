---
name: wd-local-diagnostics
description: "Use when debugging Webgility Desktop locally: finding today's/yesterday's WD application log (manual or scheduler), the QuickBooks SDK log, connecting to the local UnifyDB test database, or reading/writing the local QBD sandbox company file. Covers exact paths, file-naming conventions, and which DB/file is safe to write to."
---

# wd-local-diagnostics — local WD app logs, QBD SDK log, UnifyDB, sandbox company file

Where Krishna's local WD debugging data actually lives, and the one hard safety rule that
governs all of it: **only `UnifyDB` and the local sandbox `.qbw` are safe to write to — anything
else on these paths is read-only.**

## 1. WD application logs

Two kinds (manual and scheduler), each in two possible locations depending on whether you're
looking at a repo clone running from source, or an installed build:

| | Manual logs | Scheduler logs |
|---|---|---|
| **Local debug (repo clone)** | `<repo-root>\unify-enterprise\Desktop\eCCDebug\ErrorLog` | `<repo-root>\unify-enterprise\Desktop\eCCDebug\SchedulerLog` |
| **Installed WD app** | `C:\Webgility\UnifyEnterprise\ErrorLog` | `C:\Webgility\UnifyEnterprise\SchedulerLog` |

**`<repo-root>` varies** — `C:\WG-Agentic\unify-enterprise`, `C:\WG-Agentic 2\unify-enterprise`,
or any other clone location (`C:\<FolderName>\unify-enterprise`, `C:\unify-enterprise`, a
different drive letter entirely). The part that never changes is everything from
`\unify-enterprise\Desktop\eCCDebug` onward — match on that suffix rather than assuming a fixed
drive/parent folder. The installed-app path, by contrast, is fixed (`C:\Webgility\UnifyEnterprise\...`)
regardless of where the repo happens to be cloned.

### File naming — always check today's file first, then yesterday's

Manual logs, one file per day, filename starts with the date:

```
<DD-MM-YYYY>_Error     e.g. 17-09-2026_Error
<DD-MM-YYYY>_Info      e.g. 17-09-2026_Info
<DD-MM-YYYY>_Debug     e.g. 17-09-2026_Debug
<DD-MM-YYYY>_Warn      e.g. 17-09-2026_Warn
```

Scheduler logs use a different date format and two separate file roots:

```
ProcessingLog-<D-Mon-YY>   e.g. ProcessingLog-7-Apr-26
ErrorLog_<D-Mon-YY>        e.g. ErrorLog_7-Apr-26
```

If today's file doesn't show the issue (or doesn't exist yet — e.g. investigating first thing
in the morning), check yesterday's before concluding there's nothing logged.

**Order download request/response is in the `_Warn` file, not `_Error` or `_Info`.** When an
order is downloaded from the platform (via CIS) into the WD DB, the request and response —
including the order JSON payload itself — is logged at **Warn** level in the manual ErrorLog
folder. Check `_Warn` first for anything about what CIS actually sent for a given order.

## 1a. Clear log history before you run a test yourself

When you (not the user) are about to exercise a QBD or WD code path to verify something —
running a manual test scenario, reproducing a bug, checking a fix — **clear/remove the relevant
log file(s) first** so the run you're about to do produces a clean, unambiguous log to read
afterward, not one mixed in with everything that happened before it:

- Touching QBD → clear `qbsdklog.txt` first.
- Touching WD → clear the relevant `_Error`/`_Info`/`_Debug`/`_Warn` files (and the scheduler
  `ProcessingLog`/`ErrorLog` files if the scheduler path is involved) before the run.

This is about *your own* verification runs, not a customer's or QA's logs — never clear a log
that's evidence for an issue someone else reported.

## 2. QuickBooks SDK log

```
C:\ProgramData\Intuit\QuickBooks\qbsdklog.txt
```

Every QBXML/QBFC request and response WD sends to QuickBooks Desktop — the first place to check
when a posting looks wrong on the WD side but you need to confirm what was actually sent to (or
returned by) QuickBooks itself.

## 3. Local WD database — `UnifyDB`

- **Catalog name is always `UnifyDB`** for local testing/sandbox work — not `WG_Dev` (that's
  just the MCP tooling's generic fallback default when nothing else is configured; this
  environment's `.env` already pins `WD_WINAUTH_DEFAULT_DB`/`WD_DEFAULT_DB` to `UnifyDB`).
- For a repo-clone debug session, connection details (server, auth) come from `apiconfig.xml`.
- For the installed app: `Data Source=WGIN-NTB-276\SQLEXPRESS` — same server the
  `mssql-winauth`/`mssql-sqlauth` MCP servers and `db-automation` agent already use (see
  [setup-sql-server.md](../../docs/setup-sql-server.md)). Use the MCP connection first; fall
  back to the relevant Windows user env var only if the MCP path isn't available this session.

**The safety rule (also recorded in `db-restore` §5, the agent that actually runs SQL):**
`UnifyDB` is local and testing-only — any operation, read or write, no extra confirmation
needed. Every other database on that server is read-only unless explicitly told otherwise.

**ProfileID 11 is the designated test profile.** For analysis/reproduction work — editing an
order's details in `UnifyDB` and reposting it to the QBD sandbox to reproduce a reported issue,
or any other data-change/unit-testing on an order — use **ProfileID = 11**. This is explicitly
allowed (edit any order's data under that profile, post to the QBD sandbox company file, repeat
as needed); it does not relax the read-only rule for anything outside `UnifyDB` and the sandbox
`.qbw` itself — other profiles/databases stay read-only.

## 4. QBD sandbox company file

```
C:\Users\Public\Documents\Intuit\QuickBooks\Company Files\SellFromHome.qbw
```

This is the local, testing-only company file `UnifyDB` posts against — **full read and write
access is explicitly allowed** against *this specific file*, since it's local and testing-only,
not a customer's data. Note it's a proprietary QuickBooks file format, not something readable as
plain bytes — "read/write" here means through QuickBooks Desktop's own QBXML/QBFC automation
(see `qbsdklog.txt` above to see what was actually sent), not direct file I/O. **There is
currently no MCP server or plugin that gives Claude a live connection to it** — see
[setup-quickbooks-desktop.md](../../docs/setup-quickbooks-desktop.md) for what exists today (code
and DB access) versus what a live connector would take.

**Credentials:** Windows user env var **`QBD_CREDS`** — holds `un:<username>, pwd:<password>`
for this company file. Reference by name only, never print the value.

---
> Captured from a working-style walkthrough (see `krishnaaigen-skill-evolution`) — this is
> Krishna's personal local-machine convention, not a team-documented one, which is why it lives
> under `krishna-core` rather than as a `wd-core` router onto `unify-enterprise/.github/`.
