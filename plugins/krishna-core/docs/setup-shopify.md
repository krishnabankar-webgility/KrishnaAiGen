# Shopify Admin API — one server, many stores (two steps need you, not me)

## API access policy (standing rule, 2026-10-19)

**GraphQL only, by default, for every Shopify store this touches.** Shopify has deprecated large
parts of the REST Admin API and warns that continued REST use on a deprecated resource risks the
app's API access being suspended. So:

- Every tool in `shopify/server.mjs` calls `/admin/api/<version>/graphql.json` — none call a
  `/*.json` REST endpoint.
- Do not add a REST call back into this server, and do not run a one-off REST call against a
  Shopify store (even a throwaway script), **unless Krishna explicitly asks for REST** for that
  specific case.
- IDs returned/accepted are GraphQL gids (`gid://shopify/Order/123...`) rather than bare numeric
  REST ids; every tool also accepts a bare numeric id for convenience and converts it internally.
- This reverses how the server was originally built (REST, see history below this doc) — that
  code is kept only as a "what changed and why" record, not something to restore.

## What this gives Claude

Read and write access to Shopify stores' customers, products, and orders via a local
**`shopify`** MCP server — once set up, ask for things like "list the last 20 orders on mewebg" or
"create a draft order on qastudio for customer X" and Claude uses it directly.

**One server, not one-per-store.** Every tool takes a `store` argument (`"mewebg"` or
`"qastudio"` today); which store a call hits is picked per call from a `STORES` table in the
script, not baked into a separate process or server name. A `list_stores` tool reports what's
currently configured. Adding a third store later is two `.env` lines + one line in
`server.mjs`'s `STORES` table — no new `wg-mcp.json` entry, no new background process. (Same
consolidation this repo already did for CIS Postgres — see `setup-cis-qa-postgres.md`'s `cis-db`.)

**Name stays generic on purpose.** The server itself has no store name in it anywhere; it only
reads `SHOPIFY_<STORE>_STORE_DOMAIN`/`SHOPIFY_<STORE>_ADMIN_API_ACCESS_TOKEN` from
`wg-ai-workspace/.env`. (2026-10-14: a same-day rename to `shopify-mewebg` was tried and reverted
once this needed to cover more than one store — tying the server name to any one store was the
wrong call either way.)

## Why this doc exists instead of me just doing it

Creating a brand-new local MCP server, or rewriting an existing one's code, is the same class of
action Claude Code's safety classifier blocks Claude from doing unilaterally — a background
process that auto-starts every session with network access and live credentials. Confirmed
multiple times across this repo's servers. That's a deliberate boundary, not a bug to route
around, so the pieces below are ready to paste — the credentials themselves are already in `.env`.

## Already done

`wg-ai-workspace/.env` has (real values are in the file, not repeated here):
```
SHOPIFY_MEWEBG_STORE_DOMAIN=mewebg.myshopify.com       <- CONFIRM, inferred from "mewebg"
SHOPIFY_MEWEBG_ADMIN_API_ACCESS_TOKEN=shpat_...
SHOPIFY_MEWEBG_API_KEY=...                              <- not used yet, future OAuth flow
SHOPIFY_MEWEBG_API_SECRET_KEY=shpss_...                 <- not used yet, future OAuth flow
SHOPIFY_MEWEBG_API_VERSION=2024-10

SHOPIFY_QASTUDIO_STORE_DOMAIN=qastudio.myshopify.com   <- CONFIRM, inferred from "qastudio"
SHOPIFY_QASTUDIO_ADMIN_API_ACCESS_TOKEN=shpat_...
SHOPIFY_QASTUDIO_API_KEY=...
SHOPIFY_QASTUDIO_API_SECRET_KEY=shpss_...
SHOPIFY_QASTUDIO_API_VERSION=2024-10
```
Both apps are named **KrishnaAiGen** in their respective Shopify admins (Settings -> Apps and
sales channels -> Develop apps) — that's where to rotate or revoke either token later. A Shopify
Admin API token is **store-scoped, not account-scoped** — even with the same login across stores,
each store needs its own app + token created directly in that store's admin; there's no way to
turn a shared login into an API credential.

## Step 1 — the server files (already updated, here for reference / a clean re-create)

`C:\WG-Agentic\wg-ai-workspace\.mcp-servers\shopify\` already has these two files — rewritten
2026-10-15 for multi-store, then rewritten again 2026-10-19 to GraphQL-only (see policy above).
Read the live `server.mjs` for the exact current code (it's the source of truth); the shape is:
GraphQL `gqlCall(store, query, variables)` helper, `toGid()` for id conversion, one tool per
operation (`list_stores`, `list_products`, `get_product`, `list_orders`, `get_order`,
`list_customers`, `search_customers`, `get_customer`, `create_customer`, `create_product`,
`create_draft_order` — now with an optional `discount_code` resolved via the
`codeDiscountNodeByCode` GraphQL query — and `complete_draft_order`, which turns a draft order
into a real Order).

**`package.json`:**
```json
{
  "name": "shopify-admin-mcp",
  "version": "1.0.0",
  "type": "module",
  "description": "Shopify Admin GraphQL API MCP server — customers/products/orders, read + write, store picked per call",
  "main": "server.mjs",
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0"
  }
}
```

No `npm install` needed if the folder already has `node_modules` from the original single-store
setup — the dependency (`@modelcontextprotocol/sdk`) hasn't changed, only this file's own code.
If setting this up fresh:
```
cd C:\WG-Agentic\wg-ai-workspace\.mcp-servers\shopify
npm install
```

## Step 2 — `wg-mcp.json` entry (unchanged)

No change needed here versus the original single-store setup — still one `shopify` entry, since
store selection now happens per call, not per process:
```json
"shopify": {
  "command": "node",
  "args": [
    "--env-file",
    "C:/WG-Agentic/wg-ai-workspace/.env",
    "C:/WG-Agentic/wg-ai-workspace/.mcp-servers/shopify/server.mjs"
  ]
}
```
If it's already there from the original setup, nothing to do. Otherwise add it, then sync:
```
powershell -ExecutionPolicy Bypass -File C:\WG-Agentic\KrishnaAiGen\.claude\scripts\sync-workspace.ps1
```
Start a new session afterward and ask Claude to call `list_stores`, then list products on each
store to confirm both are live.

## On the third-party alternative (you asked about this)

A few community Shopify Admin API MCP packages exist on npm (`shopify-mcp-server`,
`shopify-store-mcp`, and others surfaced in a search) that claim similar customer/product/order
coverage. They are unverified, independently-maintained code that would receive the live access
tokens the moment they're wired in — Claude has no way to audit what a given version of one of
those packages actually does with them. The server above does the same job in code Claude wrote
and you can read end to end, so that's the recommendation; only reach for a third-party package if
you specifically want its extra features and are comfortable reviewing its source yourself first.

## Changing behavior later

| To change | Edit |
|---|---|
| **Which stores this talks to** | `SHOPIFY_<STORE>_STORE_DOMAIN` + `SHOPIFY_<STORE>_ADMIN_API_ACCESS_TOKEN` in `.env` for an existing store; add a new `SHOPIFY_<NAME>_*` block plus one line in `server.mjs`'s `STORES` table for a new one |
| Which store data operations are available | `shopify/server.mjs`'s `TOOLS` array and the `switch` in the tool handler |
| API version (per store) | `SHOPIFY_<STORE>_API_VERSION` in `.env` |
| Credentials (rotate/revoke) | That store's Shopify admin -> Settings -> Apps and sales channels -> Develop apps -> **KrishnaAiGen** -> API credentials; then update `.env` |
| Handing this to a teammate | Same server file, same `wg-mcp.json` entry name (`shopify`) — only their own `.env` differs (their stores' domains + their own apps' tokens, under whatever keys they add to `STORES`) |
