# Setup: CIS Postgres (QA + prod), one shared login, read-only (Prompt 37)

Goal: the existing `cis-db` MCP server reaches **QA and prod** CIS Postgres with **one** set of
`USER`, `PASSWORD`, `PORT` values. Each host only declares its own `HOST` and `NAME`. No new server or process.
`execute_sql` refuses anything but SELECT, so the server stays read-only at the code level.

Status 2026-10-22: `list_targets` shows only `qa-wgs` and `qa-shard3`; prod is not configured. A login test to the prod host
was denied by Claude Code's auto-mode classifier, so do the three steps below yourself (editing `.env` and a credentialed server file is the
class of change the classifier blocks).

## Design

| Value | Where it lives | Used by |
|---|---|---|
| `CIS_DB_USER`, `CIS_DB_PASSWORD`, `CIS_DB_PORT` | once, in `.env` | every target (QA and prod) |
| `CIS_<TARGET>_DB_HOST`, `CIS_<TARGET>_DB_NAME` | once per host | that target |
| optional `CIS_<TARGET>_DB_USER/_PASSWORD/_PORT` | only if one host needs a different login | overrides the shared value for that target |

The per-host override means that if prod turns out to need a different read-only role than QA (likely: your QA account may have no
rights on prod), you add 2 lines for prod only and QA keeps working.

## Step 1: `wg-ai-workspace/.env`

**Remove** these six old lines (and any other `..._DB_USER/_PASSWORD/_PORT` of a CIS host): `CIS_QA_WGS_DB_USER`,
`CIS_QA_WGS_DB_PASSWORD`, `CIS_QA_WGS_DB_PORT`, `CIS_QA_SHARD3_DB_USER`, `CIS_QA_SHARD3_DB_PASSWORD`, `CIS_QA_SHARD3_DB_PORT`.
Keep the existing `CIS_QA_WGS_DB_HOST/_NAME` and `CIS_QA_SHARD3_DB_HOST/_NAME` lines as they are.
Then add (move your current QA values into the shared three lines):

```
# ---- CIS Postgres: shared by every target (QA + prod) ----
CIS_DB_USER=<the current CIS_QA_WGS_DB_USER value>
CIS_DB_PASSWORD=<the current CIS_QA_WGS_DB_PASSWORD value>
CIS_DB_PORT=5432

# ---- prod hosts: only HOST and NAME ----
CIS_PROD_WGS_DB_HOST=prod-wgs.corp.webgility.com
CIS_PROD_WGS_DB_NAME=wgsettings
CIS_PROD_SHARD1_DB_HOST=postgres-prd1.corp.webgility.com
CIS_PROD_SHARD1_DB_NAME=wgmessage_shard1
# add when a lookup lands there:
# CIS_PROD_SHARD2_DB_HOST=prod-shard2.corp.webgility.com
# CIS_PROD_SHARD2_DB_NAME=wgmessage_shard2
# CIS_PROD_SHARD3_DB_HOST=awlx-cisp-pg03.corp.webgility.com
# CIS_PROD_SHARD3_DB_NAME=wgmessage_shard3

# ---- only if prod needs a DIFFERENT login than QA (otherwise omit) ----
# CIS_PROD_WGS_DB_USER=<prod read-only user>
# CIS_PROD_WGS_DB_PASSWORD=<password>
# CIS_PROD_SHARD1_DB_USER=<same prod user>
# CIS_PROD_SHARD1_DB_PASSWORD=<password>
```

Prod hosts for reference (cis-db-access `reference.md`): `prod-wgs` = settings (`channelsettings`, `manageusershardservers`: subscriber -> shard),
`prod-shard1/2/3` = `message` / `message_cache`. Start with `prod-wgs`, then add only the shard it points to.

## Step 2: replace `wg-ai-workspace/.mcp-servers/cis-db/server.mjs` entirely with this

```js
#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import pg from "pg";

const { Pool } = pg;

// USER / PASSWORD / PORT are shared by every target: CIS_DB_USER, CIS_DB_PASSWORD, CIS_DB_PORT.
// Each target adds only its own HOST and NAME (<prefix>HOST, <prefix>NAME). A target can still
// override any of the five with its own <prefix>USER / PASSWORD / PORT if it ever needs a different login.
// Add a host: 2 .env lines (HOST, NAME) + 1 line here.
const SHARED = "CIS_DB_";
const TARGETS = {
  "qa-wgs": "CIS_QA_WGS_DB_",
  "qa-shard3": "CIS_QA_SHARD3_DB_",
  "prod-wgs": "CIS_PROD_WGS_DB_",
  "prod-shard1": "CIS_PROD_SHARD1_DB_",
};

const pools = new Map(); // target -> pg Pool, created lazily on first use

// per-host value wins, otherwise the shared value
function cfg(prefix, suffix) {
  return process.env[prefix + suffix] ?? process.env[SHARED + suffix];
}

function getPool(target) {
  const prefix = TARGETS[target];
  if (!prefix) {
    throw new Error(`Unknown target "${target}". Known targets: ${Object.keys(TARGETS).join(", ")}`);
  }
  if (pools.has(target)) return pools.get(target);

  for (const suffix of ["HOST", "NAME", "USER", "PASSWORD", "PORT"]) {
    if (!cfg(prefix, suffix)) {
      throw new Error(`${prefix}${suffix} (or ${SHARED}${suffix}) is missing - set it in wg-ai-workspace/.env`);
    }
  }
  const pool = makePool(prefix, parseInt(cfg(prefix, "PORT") || "5432", 10));
  pools.set(target, pool);
  return pool;
}

function makePool(prefix, port) {
  return new Pool({
    host: cfg(prefix, "HOST"),
    database: cfg(prefix, "NAME"),
    user: cfg(prefix, "USER"),
    password: cfg(prefix, "PASSWORD"),
    port,
    statement_timeout: 10000,
    connectionTimeoutMillis: 5000, // a blocked port fails fast so the fallback kicks in
  });
}

// Connect-level failures only (not SQL errors): then retry once through pgbouncer on 6432
// and keep that pool for the target. Override the fallback port with CIS_DB_PORT_FALLBACK if ever needed.
const CONNECT_ERRORS = new Set(["ECONNREFUSED", "ETIMEDOUT", "EHOSTUNREACH", "ENETUNREACH", "ECONNRESET"]);
async function getClient(target) {
  try {
    return await getPool(target).connect();
  } catch (error) {
    const timedOut = /timeout exceeded when trying to connect/i.test(error.message);
    const fallbackPort = parseInt(process.env.CIS_DB_PORT_FALLBACK || "6432", 10);
    const prefix = TARGETS[target];
    if (!prefix || !(CONNECT_ERRORS.has(error.code) || timedOut) || fallbackPort === parseInt(cfg(prefix, "PORT") || "5432", 10)) throw error;
    const old = pools.get(target);
    pools.set(target, makePool(prefix, fallbackPort));
    old?.end().catch(() => {});
    return await pools.get(target).connect();
  }
}

function isDestructive(sql) {
  return /\b(UPDATE|DELETE|INSERT|DROP|ALTER|TRUNCATE|EXEC|EXECUTE|CREATE|GRANT|REVOKE)\b/i.test(sql);
}

const server = new Server({ name: "cis-db", version: "1.1.0" }, { capabilities: { tools: {} } });

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "list_targets",
      description: "List the CIS database targets this server currently knows how to reach (the 'target' values execute_sql accepts), and which host/database each one is.",
      inputSchema: { type: "object", properties: {} },
    },
    {
      name: "execute_sql",
      description:
        "Run a read-only SELECT against a CIS Postgres database (QA or prod). Call list_targets first if " +
        "unsure which `target` to use. Shopify (mewebg) order/channel data lives in " +
        "wgsettings.public.channelsettings, wgsettings.public.manageusershardservers, " +
        "public.message, and public.message_cache - see the cis-db-access skill for the exact " +
        "lookup chain (subscriberid -> shard -> message/message_cache). SELECT only; LIMIT 50 " +
        "auto-appended if omitted. Prod holds real customer data: select only needed columns.",
      inputSchema: {
        type: "object",
        properties: {
          target: { type: "string", description: "Which database, e.g. \"qa-wgs\", \"qa-shard3\", \"prod-wgs\", \"prod-shard1\" - see list_targets." },
          sql: { type: "string" },
        },
        required: ["target", "sql"],
      },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  const a = args ?? {};

  if (name === "list_targets") {
    const rows = Object.entries(TARGETS).map(([target, prefix]) => ({
      target,
      host: cfg(prefix, "HOST") ?? "(not set)",
      database: cfg(prefix, "NAME") ?? "(not set)",
    }));
    return { content: [{ type: "text", text: JSON.stringify(rows, null, 2) }] };
  }

  if (name !== "execute_sql") {
    return { content: [{ type: "text", text: `Unknown tool: ${name}` }], isError: true };
  }

  let sql = a.sql ?? "";
  if (isDestructive(sql)) {
    return {
      content: [{ type: "text", text: "SECURITY EXCEPTION: only SELECT is allowed on this server." }],
      isError: true,
    };
  }
  if (!/\bLIMIT\b/i.test(sql)) {
    sql = sql.replace(/;+\s*$/, "") + " LIMIT 50;";
  }

  let client;
  try {
    client = await getClient(a.target);
    const result = await client.query(sql);
    return { content: [{ type: "text", text: JSON.stringify(result.rows, null, 2) || "0 rows." }] };
  } catch (error) {
    return { content: [{ type: "text", text: `Database error: ${error.message}` }], isError: true };
  } finally {
    if (client) client.release();
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
```

## Step 3: reload and check

Reload the VS Code window (or `/mcp`, reconnect `cis-db`), then ask me to call `list_targets`. It should show four targets
(`qa-wgs`, `qa-shard3`, `prod-wgs`, `prod-shard1`) with host and database only. It never prints user or password.
Quick QA regression check: one `SELECT 1` on `qa-wgs` should still work.

## Safety
- Connect over VPN (`vm-manager.ps1 vpn-check`). Port 6432 (pgbouncer) is an **automatic fallback**: if a connection to `CIS_DB_PORT` (5432) is refused or times out, the server retries once on 6432 and keeps using it for that target. No `.env` change needed; optionally `CIS_DB_PORT_FALLBACK` changes the fallback port. SQL errors (bad login, permissions) do not trigger the fallback.
- Prod is real customer data: SELECT only, small LIMITs, select needed columns (never `*` on `channelsettings`, it holds live tokens), and no customer data in repo files.
- Prefer a read-only prod role (SELECT grants only). If one login serves QA and prod it must not have write rights on prod.
- Never paste the real password into docs or chat; it lives only in `.env`.

## Then
Tell me "prod is wired" and I will run the MyriamAcosta lookup: subscriber and email from `wgsettings`, then the purchase-order messages from its shard.

Also update (I will do this once it is live): `cis-db-access/SKILL.md` + `reference.md` §3/§9 to describe the shared `CIS_DB_*` convention and the prod targets.
