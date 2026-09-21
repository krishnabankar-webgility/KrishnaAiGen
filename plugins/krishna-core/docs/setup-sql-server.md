# SQL Server & CIS DB — setup and workflow

Six local MCP servers cover data-layer access. All are read-mostly in practice (used for
diagnosis, not for driving production writes) even though nothing technically blocks a write —
treat them as read tools unless a task specifically calls for a data fix, and say so before
running one.

## `mssql-winauth` — WD local dev SQL Server (Windows auth)

- Env (in `wg-ai-workspace/.env`): `MSSQL_WINAUTH_CONNSTR` (Windows-auth connection string to
  your local dev SQL Server instance), `WD_WINAUTH_DEFAULT_DB` (defaults to `WG_Dev` if unset).
- No password needed — it authenticates as your logged-in Windows account, so the connection
  string should use `Integrated Security=true` / Windows auth, not `uid=/pwd=`.

## `mssql-sqlauth` — WD restored customer databases (SQL auth)

- Env: `MSSQL_CONNECTION_STRING` (SQL-auth connection string — this one **does** carry a
  username/password in the string itself, so keep it in `.env` only, never in a skill or a
  ticket note), `WD_DEFAULT_DB` (defaults to `WG_Dev`).
- Use this one, not `mssql-winauth`, when working against a customer database restored locally
  for a support ticket — those attach under SQL auth, not your Windows identity.
- Both servers are driven by the same underlying tool (`wd-db/WdDbTool.cs`); which one loads is
  just which `WD_AUTH_MODE` (`windows` / `sql`) is baked into that MCP entry in `wg-mcp.json` —
  don't try to set `WD_AUTH_MODE` in `.env`, it's fixed per-server there on purpose.

## `cis-db-proxy` — CIS PostgreSQL, read-only, via HTTP proxy

- Env: `CIS_DB_PROXY_URL` (defaults to the internal proxy host if unset), `CIS_DB_PROXY_BEARER_TOKEN`.
- Get the bearer token from whoever owns the CIS DB proxy service — it is not a personal
  Atlassian/Bitbucket-style token you generate yourself.
- This is a proxy, not a direct DB connection — it only exposes what the proxy's own query
  allow-list permits, which is the point: no raw SQL against production CIS data.

## `cns-db` / `cws-db` — CNS and CWS Postgres, direct connection

- `cns-db` env: `CNS_DB_HOST`, `CNS_DB_USER`, `CNS_DB_PASSWORD`, `CNS_DB_PORT` (defaults `5432`).
- `cws-db` (webhook DB) env: `WEBHOOK_DB_HOST`, `WEBHOOK_DB_USER`, `WEBHOOK_DB_PASSWORD`,
  `WEBHOOK_DB_PORT` (defaults `5432`).
- Both are direct Postgres connections (not proxied) — get host/user/password from whoever owns
  the CNS/CWS databases; these are not something you provision yourself.

## `wo-db` — WO subscriber/tenant databases

- Env: `ECCCLOUD_ADMIN_CONNSTR` (admin connection string used to look up which physical DB a
  subscriber lives on), `AESKEY_CLOUD` / `HEXIV_CLOUD` (the AES key/IV that decrypts each
  subscriber's *own* stored DB credentials — WO keeps per-tenant credentials encrypted at rest,
  so this server needs the decryption key, not a single shared password).
- These three come from whoever owns the WO cloud admin database — do not generate or guess
  them, and never print a decrypted subscriber connection string into chat or a file.

## One-time setup (all six)

1. Get each credential above from its actual owner (not all are Krishna's to generate).
2. Add the relevant keys to `C:\WG-Agentic\wg-ai-workspace\.env`.
3. Run `sync-workspace.ps1` (see [README](../README.md#mcp-servers)), then trust the new
   servers once per project, or run `approve-mcp-trust.py` to cover every repo/tree at once.

## Verify

Ask for something narrow and cheap to check, per server: *"what database does `mssql-winauth`
connect to by default"*, *"ping cis-db-proxy"*, *"which subscriber DB does account X live on"*
(wo-db). A real answer (not a connection error) confirms the credential is right.

## Workflow in short

`db-automation` (`/db`) is the entry point for local SQL Server restore/attach/query work.
`wd-scout` and the `wd-*` domain agents reach for the right DB server directly when a question
is "what does the data actually say" rather than "what does the code say."

## Changing behavior

| To change | Edit |
|---|---|
| Credentials, hosts, ports | `wg-ai-workspace/.env` |
| Which auth mode `mssql-winauth`/`mssql-sqlauth` use, proxy URL default, job wiring | `KrishnaAiGen/.claude/mcp/wg-mcp.json`, then `sync-workspace.ps1` |
| Restore/attach procedure, query conventions | `plugins/krishna-core/skills/db-restore/SKILL.md` |
