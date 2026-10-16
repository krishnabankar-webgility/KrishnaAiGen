# Shopify Admin API — one server, many stores (two steps need you, not me)

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

`C:\WG-Agentic\wg-ai-workspace\.mcp-servers\shopify\` already has these two files, rewritten
2026-10-15 for multi-store:

**`package.json`:**
```json
{
  "name": "shopify-admin-mcp",
  "version": "1.0.0",
  "type": "module",
  "description": "Shopify Admin REST API MCP server — customers/products/orders, read + write, store picked per call",
  "main": "server.mjs",
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0"
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

// Shopify Admin REST API server — read tools plus a small set of clearly-labeled
// write tools. Every write tool changes the LIVE store; there is no dry-run mode.
//
// Multi-store: one process, store picked per call via the `store` argument —
// not one process per store. Add a new store here — nowhere else — plus its
// .env vars; no new wg-mcp.json entry needed.
const STORES = {
  mewebg: "SHOPIFY_MEWEBG_",
  qastudio: "SHOPIFY_QASTUDIO_",
};

const clients = new Map(); // store key -> { baseUrl, accessToken }

function getClient(store) {
  const prefix = STORES[store];
  if (!prefix) {
    throw new Error(`Unknown store "${store}". Known stores: ${Object.keys(STORES).join(", ")}`);
  }
  if (clients.has(store)) return clients.get(store);

  const domain = (process.env[`${prefix}STORE_DOMAIN`] ?? "").replace(/^https?:\/\//, "").replace(/\/$/, "");
  const accessToken = process.env[`${prefix}ADMIN_API_ACCESS_TOKEN`] ?? "";
  const apiVersion = process.env[`${prefix}API_VERSION`] ?? "2024-10";
  if (!domain || !accessToken) {
    throw new Error(`${prefix}STORE_DOMAIN or ${prefix}ADMIN_API_ACCESS_TOKEN is missing — set it in wg-ai-workspace/.env`);
  }
  const client = { baseUrl: `https://${domain}/admin/api/${apiVersion}`, accessToken, domain };
  clients.set(store, client);
  return client;
}

const server = new Server(
  { name: "shopify", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

async function callShopify(store, method, path, { query, body } = {}) {
  const client = getClient(store);
  const qs = new URLSearchParams(
    Object.entries(query ?? {}).filter(([, v]) => v !== undefined && v !== null && v !== "")
  ).toString();
  const url = `${client.baseUrl}${path}${qs ? `?${qs}` : ""}`;

  const resp = await fetch(url, {
    method,
    headers: { "Content-Type": "application/json", "X-Shopify-Access-Token": client.accessToken },
    body: body ? JSON.stringify(body) : undefined,
    signal: AbortSignal.timeout(30_000),
  });

  const text = await resp.text();
  let data;
  try { data = text ? JSON.parse(text) : {}; } catch { data = { raw: text }; }

  if (!resp.ok) {
    return {
      content: [{ type: "text", text: `Shopify API error ${resp.status} on ${method} ${path} (store: ${store}):\n${JSON.stringify(data, null, 2)}` }],
      isError: true,
    };
  }
  return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
}

const STORE_PROP = { store: { type: "string", description: `Which store: ${Object.keys(STORES).join(" or ")}. Call list_stores if unsure.` } };

const TOOLS = [
  { name: "list_stores", description: "List the Shopify stores this server currently knows how to reach (the `store` values every other tool accepts), and which domain each one is.",
    inputSchema: { type: "object", properties: {} } },
  // --- read ---
  { name: "list_products", description: "List products. Input: { store, limit?, title?, status?, collection_id? }",
    inputSchema: { type: "object", properties: { ...STORE_PROP, limit: { type: "number" }, title: { type: "string" }, status: { type: "string" }, collection_id: { type: "string" } }, required: ["store"] } },
  { name: "get_product", description: "Get a product by id. Input: { store, product_id }",
    inputSchema: { type: "object", properties: { ...STORE_PROP, product_id: { type: "string" } }, required: ["store", "product_id"] } },
  { name: "list_orders", description: "List orders. Input: { store, limit?, status? ('open'|'closed'|'cancelled'|'any'), financial_status?, fulfillment_status?, created_at_min?, created_at_max?, name? }",
    inputSchema: { type: "object", properties: { ...STORE_PROP, limit: { type: "number" }, status: { type: "string" }, financial_status: { type: "string" }, fulfillment_status: { type: "string" }, created_at_min: { type: "string" }, created_at_max: { type: "string" }, name: { type: "string" } }, required: ["store"] } },
  { name: "get_order", description: "Get an order by id. Input: { store, order_id }",
    inputSchema: { type: "object", properties: { ...STORE_PROP, order_id: { type: "string" } }, required: ["store", "order_id"] } },
  { name: "list_customers", description: "List customers. Input: { store, limit? }",
    inputSchema: { type: "object", properties: { ...STORE_PROP, limit: { type: "number" } }, required: ["store"] } },
  { name: "search_customers", description: "Search customers. Input: { store, query } e.g. 'email:jane@example.com'",
    inputSchema: { type: "object", properties: { ...STORE_PROP, query: { type: "string" } }, required: ["store", "query"] } },
  { name: "get_customer", description: "Get a customer by id. Input: { store, customer_id }",
    inputSchema: { type: "object", properties: { ...STORE_PROP, customer_id: { type: "string" } }, required: ["store", "customer_id"] } },
  // --- write: each one changes the live store ---
  { name: "create_customer", description: "Create a customer. WRITES to the live store. Input: { store, first_name?, last_name?, email?, phone?, tags? }",
    inputSchema: { type: "object", properties: { ...STORE_PROP, first_name: { type: "string" }, last_name: { type: "string" }, email: { type: "string" }, phone: { type: "string" }, tags: { type: "string" } }, required: ["store"] } },
  { name: "create_product", description: "Create a product. WRITES to the live store. Input: { store, title, body_html?, vendor?, product_type?, status? ('active'|'draft'), variants? (array of {price, sku, option1}) }",
    inputSchema: { type: "object", properties: { ...STORE_PROP, title: { type: "string" }, body_html: { type: "string" }, vendor: { type: "string" }, product_type: { type: "string" }, status: { type: "string" }, variants: { type: "array" } }, required: ["store", "title"] } },
  { name: "create_draft_order", description: "Create a DRAFT order (not a paid/completed order — this is the normal, safe way to build an order for a customer to review/pay). WRITES to the live store. Input: { store, line_items (array of {variant_id, quantity} or {title, price, quantity}), customer_id?, email?, note? }",
    inputSchema: { type: "object", properties: { ...STORE_PROP, line_items: { type: "array" }, customer_id: { type: "string" }, email: { type: "string" }, note: { type: "string" } }, required: ["store", "line_items"] } },
];

server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  const a = args ?? {};

  if (name === "list_stores") {
    const rows = Object.entries(STORES).map(([store, prefix]) => ({
      store,
      domain: process.env[`${prefix}STORE_DOMAIN`] ?? "(not set)",
    }));
    return { content: [{ type: "text", text: JSON.stringify(rows, null, 2) }] };
  }

  try {
    switch (name) {
      case "list_products":
        return await callShopify(a.store, "GET", "/products.json", { query: { limit: a.limit ?? 50, title: a.title, status: a.status, collection_id: a.collection_id } });
      case "get_product":
        return await callShopify(a.store, "GET", `/products/${encodeURIComponent(a.product_id)}.json`);
      case "list_orders":
        return await callShopify(a.store, "GET", "/orders.json", { query: { limit: a.limit ?? 50, status: a.status ?? "any", financial_status: a.financial_status, fulfillment_status: a.fulfillment_status, created_at_min: a.created_at_min, created_at_max: a.created_at_max, name: a.name } });
      case "get_order":
        return await callShopify(a.store, "GET", `/orders/${encodeURIComponent(a.order_id)}.json`);
      case "list_customers":
        return await callShopify(a.store, "GET", "/customers.json", { query: { limit: a.limit ?? 50 } });
      case "search_customers":
        return await callShopify(a.store, "GET", "/customers/search.json", { query: { query: a.query } });
      case "get_customer":
        return await callShopify(a.store, "GET", `/customers/${encodeURIComponent(a.customer_id)}.json`);
      case "create_customer":
        return await callShopify(a.store, "POST", "/customers.json", { body: { customer: { first_name: a.first_name, last_name: a.last_name, email: a.email, phone: a.phone, tags: a.tags } } });
      case "create_product":
        return await callShopify(a.store, "POST", "/products.json", { body: { product: { title: a.title, body_html: a.body_html, vendor: a.vendor, product_type: a.product_type, status: a.status ?? "draft", variants: a.variants } } });
      case "create_draft_order":
        return await callShopify(a.store, "POST", "/draft_orders.json", { body: { draft_order: { line_items: a.line_items, customer: a.customer_id ? { id: a.customer_id } : undefined, email: a.email, note: a.note } } });
      default:
        return { content: [{ type: "text", text: `Unknown tool: ${name}` }], isError: true };
    }
  } catch (error) {
    return { content: [{ type: "text", text: error.message }], isError: true };
  }
});

const transport = new StdioServerTransport();
await server.connect(transport);
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
