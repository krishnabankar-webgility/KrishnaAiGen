# CIS Postgres, direct — one server, many hosts (two steps need you, not me)

## What this gives Claude

Direct read-only SQL access to CIS Postgres hosts you use in DBeaver over RDP — today
`wgSettingsQA` (host `audit-qa.corp.webgility.com`) and `wgSettingsQA_Shard3` (host
`pgqa-shard3.corp.webgility.com`), both of which hold the same Shopify (mewebg) order/channel
data as the `cis-db-proxy` MCP server's `qa`/`qa-shard3` HTTP-proxy segments — useful as a direct
route since that proxy's bearer token is currently invalid.

**One server, not one-per-host.** Each customer/environment can have its own settings DB and
shard DB(s) (see the full environment map in the `cis-db-access` skill — prod, QA, QA2-4, stage,
dev). Rather than a new `wg-mcp.json` entry and a new background process per host, this is a
**single `cis-db` MCP server** whose `execute_sql` tool takes a `target` argument — which host it
runs against is picked per call, not per process. Adding a new host later is two `.env` lines plus
one line in a lookup table in the server script — no new process, no new `wg-mcp.json` entry, no
restart-per-host.

## Why this doc exists instead of me just doing it

Same reason as `setup-shopify.md`: creating a brand-new local MCP server is a new background
process plus a config change that makes Claude Code auto-start it every session with network
access and a live credential. Claude Code's safety classifier blocks Claude from doing that
unilaterally — confirmed again here (denied on the very first file write, `[Unauthorized
Persistence]`). Two pieces below need your hand; the credentials themselves are already stored.

## Already done

`wg-ai-workspace/.env` now has (real values are in the file, not repeated here):
```
CIS_QA_WGS_DB_HOST=audit-qa.corp.webgility.com
CIS_QA_WGS_DB_NAME=wgSettingsQA
CIS_QA_WGS_DB_USER=krishna.bankar
CIS_QA_WGS_DB_PASSWORD=...
CIS_QA_WGS_DB_PORT=5432

CIS_QA_SHARD3_DB_HOST=pgqa-shard3.corp.webgility.com
CIS_QA_SHARD3_DB_NAME=wgSettingsQA_Shard3
CIS_QA_SHARD3_DB_USER=krishna.bankar
CIS_QA_SHARD3_DB_PASSWORD=...
CIS_QA_SHARD3_DB_PORT=5432
```

**Worth doing at some point:** this password was pasted in plaintext into a prompt file under
`Reference\Claude System Design\` — same situation as the Shopify token earlier. Not urgent
(it's a QA credential, not production), but worth rotating next time you're in there if that
file might ever get shared or committed.

## Step 1 — create the server files yourself

Create the folder `C:\WG-Agentic\wg-ai-workspace\.mcp-servers\cis-db\` with these two files. **One
process, one tool, many hosts** — which host/database a given call hits is the `target` argument,
looked up against a small table in the script, not an env flag baked in at process start.

**`package.json`:**
```json
{
  "name": "cis-db-mcp",
  "version": "1.0.0",
  "type": "module",
  "description": "Direct Postgres MCP server for CIS databases (prod/QA/stage/dev, settings + shards) — read-only SELECT, host picked per call",
  "main": "server.mjs",
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "pg": "^8.20.0"
  }
}
```

**`server.mjs`:**
```javascript
#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import pg from "pg";

const { Pool } = pg;

// Add a new host here — nowhere else. Each key is the "target" value callers pass;
// its value is the .env prefix for that host's HOST/NAME/USER/PASSWORD/PORT vars.
// Extending to a new customer/environment is: add the 5 .env vars, add one line here.
const TARGETS = {
  "qa-wgs": "CIS_QA_WGS_DB_",
  "qa-shard3": "CIS_QA_SHARD3_DB_",
};

const pools = new Map(); // target -> pg Pool, created lazily on first use

function getPool(target) {
  const prefix = TARGETS[target];
  if (!prefix) {
    throw new Error(`Unknown target "${target}". Known targets: ${Object.keys(TARGETS).join(", ")}`);
  }
  if (pools.has(target)) return pools.get(target);

  for (const suffix of ["HOST", "NAME", "USER", "PASSWORD", "PORT"]) {
    if (!process.env[prefix + suffix]) {
      throw new Error(`${prefix}${suffix} is missing — set it in wg-ai-workspace/.env`);
    }
  }
  const pool = new Pool({
    host: process.env[`${prefix}HOST`],
    database: process.env[`${prefix}NAME`],
    user: process.env[`${prefix}USER`],
    password: process.env[`${prefix}PASSWORD`],
    port: parseInt(process.env[`${prefix}PORT`] || "5432", 10),
    statement_timeout: 10000,
  });
  pools.set(target, pool);
  return pool;
}

function isDestructive(sql) {
  return /\b(UPDATE|DELETE|INSERT|DROP|ALTER|TRUNCATE|EXEC|EXECUTE|CREATE|GRANT|REVOKE)\b/i.test(sql);
}

const server = new Server({ name: "cis-db", version: "1.0.0" }, { capabilities: { tools: {} } });

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
        "Run a read-only SELECT against a CIS Postgres database. Call list_targets first if " +
        "unsure which `target` to use. Shopify (mewebg) order/channel data lives in " +
        "wgsettings.public.channelsettings, wgsettings.public.manageusershardservers, " +
        "public.message, and public.message_cache — see the cis-db-access skill for the exact " +
        "lookup chain (subscriberid -> shard -> message/message_cache). SELECT only; LIMIT 50 " +
        "auto-appended if omitted.",
      inputSchema: {
        type: "object",
        properties: {
          target: { type: "string", description: "Which database, e.g. \"qa-wgs\" or \"qa-shard3\" — see list_targets." },
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
      host: process.env[`${prefix}HOST`] ?? "(not set)",
      database: process.env[`${prefix}NAME`] ?? "(not set)",
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
    const pool = getPool(a.target);
    client = await pool.connect();
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

Then install its dependencies once:
```
cd C:\WG-Agentic\wg-ai-workspace\.mcp-servers\cis-db
npm install
```

**If `cis-qa-pg\` (the old two-process version) already exists**, this replaces it — once `cis-db`
is live and confirmed working, the two `cis-qa-wgs`/`cis-qa-shard3` entries and the old
`cis-qa-pg\` folder can be removed; not urgent, just avoids two servers doing the same job.

## Step 2 — register one entry yourself in `wg-mcp.json`

Open `C:\WG-Agentic\KrishnaAiGen\.claude\mcp\wg-mcp.json` and add (comma-separate with the
existing entries, don't replace anything) — and remove the old `cis-qa-wgs`/`cis-qa-shard3`
entries if they're there from a previous setup:
```json
"cis-db": {
  "command": "node",
  "args": [
    "--env-file",
    "C:/WG-Agentic/wg-ai-workspace/.env",
    "C:/WG-Agentic/wg-ai-workspace/.mcp-servers/cis-db/server.mjs"
  ]
}
```

Then sync and trust, same as every other server here:
```
powershell -ExecutionPolicy Bypass -File C:\WG-Agentic\KrishnaAiGen\.claude\scripts\sync-workspace.ps1
```
First time only, Claude Code will ask to trust the new server per project — or run
`approve-mcp-trust.py` once (see the main [README](../README.md#one-time-setup-extras)) to cover
every repo/tree at once. Start a new session afterward and ask Claude to call `list_targets`, then
look up an order by its display number (e.g. `#60366`) to confirm it's live.

## Using it once it's live

See the **`cis-db-access`** skill for the full reference — environment map (every CIS
host/port/database, not just these two), schema/enums, the subscriber->shard->order lookup
chain with working queries, and the gotchas found while building this (shared QA store names,
`message` vs `message_cache` staleness, unscoped queries timing out). Short version: on target
`qa-wgs`, `channelsettings` (subscriberid, integrationtypeid=13 for Shopify) ->
`manageusershardservers` (which shard: 1/2/3); then on target `qa-shard3` (or the matching
target for another shard), `public.message` / `public.message_cache`, filtering by
`marshalleddatav2->>'Number'` for a display order number like `#60366`, or
`externalentitycode` for the raw Shopify numeric order id.

## Changing behavior later

| To change | Edit |
|---|---|
| Which SQL is safe to run (currently: SELECT-only, no table allow-list) | `cis-db/server.mjs`'s `isDestructive` check |
| Add another host (new shard, prod, a customer's dedicated DB, …) | Add `CIS_<NAME>_DB_*` vars to `.env`, add one line to the `TARGETS` table in `server.mjs`. No new `wg-mcp.json` entry, no new process. |
| Credentials (rotate) | Update the password in `.env` — same account (`krishna.bankar`) used in DBeaver |
