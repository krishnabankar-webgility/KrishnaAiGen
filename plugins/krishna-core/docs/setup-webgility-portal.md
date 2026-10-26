# Webgility Portal / CIS auth — one server, two environments (dev + prod)

## What this gives Claude

A direct backend path to WD's own order-download call — **no WD UI, no QBD UI** — via a local
**`webgility-portal`** MCP server: mint the same short-lived session token WD itself holds in
memory, then call CIS's order-download endpoint directly with it. Once set up, ask for things like
"get client info for subscriber X on dev" or "pull order <orderNo> from CIS for profile 17 on dev"
and Claude uses it directly — this is now the default path per the 2026-10-19 standing rule
(`wd-qbd-ui-automation-opt-in-only`): backend first, WD/QBD UI only when explicitly asked for.

**One server, not one-per-environment.** Every tool takes an `environment` argument (`"dev"` or
`"prod"`); which portal/CIS host a call hits is picked per call from an `ENVIRONMENTS` table in the
script — same consolidation pattern as `shopify` (multi-store) and `cis-db` (multi-host).

**The session token never leaves this process.** It's minted and cached in memory only, redacted
from whatever text any tool returns to Claude — used internally to call CIS, never surfaced.

See the full server code in the scratchpad draft; final file to be placed at
`C:\WG-Agentic\wg-ai-workspace\.mcp-servers\webgility-portal\server.mjs`.
=====================================

**File: `C:\WG-Agentic\wg-ai-workspace\.mcp-servers\webgility-portal\package.json`**
```json
{
  "name": "webgility-portal-mcp",
  "version": "1.0.0",
  "type": "module",
  "description": "Webgility Portal/CIS auth MCP server — mints and caches the ApolloJWT WD itself uses, then calls CIS directly (e.g. order download) without WD's UI",
  "main": "server.mjs",
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0"
  }
}
```

**File: `C:\WG-Agentic\wg-ai-workspace\.mcp-servers\webgility-portal\server.mjs`**
```javascript
#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

// Webgility Portal / CIS data server — one process, two environments (dev/prod),
// environment picked per call via the `environment` argument (same multi-instance
// pattern as the `shopify` and `cis-db` servers — see
// mcp-server-naming-generic-not-store-specific in memory).
//
// Purpose: check account status for a subscriber, then use that session to read
// order data from CIS directly (e.g. api/orders/IndividualOrderDownload) without
// opening WD or QBD's UI at all. Internal session material never leaves this
// process — every tool masks it before returning text to the caller.
const ENVIRONMENTS = {
  dev: {
    portalUrl: "https://devportal.webgility.com/cdb-license-test.php",
    cisBaseUrl: "https://cisqa.webgility.com",
  },
  prod: {
    portalUrl: "https://portal.webgility.com/cdb-license-test.php",
    cisBaseUrl: "https://cis.webgility.com", // CONFIRM — not yet verified against a live prod call
  },
};

const sessionCache = new Map(); // "<environment>:<email>" -> { jwt, jwtExpiresAt, licenseKey, subscriberId }

function getEnv(environment) {
  const cfg = ENVIRONMENTS[environment];
  if (!cfg) throw new Error(`Unknown environment "${environment}". Known: ${Object.keys(ENVIRONMENTS).join(", ")}`);
  return cfg;
}

function requireEnvVar(name) {
  const v = process.env[name];
  if (!v) throw new Error(`${name} is missing — set it in wg-ai-workspace/.env`);
  return v;
}

function decodeJwtExpiry(jwt) {
  try {
    const payload = jwt.split(".")[1];
    const json = Buffer.from(payload.replace(/-/g, "+").replace(/_/g, "/"), "base64").toString("utf8");
    const obj = JSON.parse(json);
    return obj.exp ? new Date(obj.exp * 1000) : null;
  } catch {
    return null;
  }
}

function parsePrintR(text) {
  const lines = text.split("\n");
  let i = 0;
  function parseBlock(baseIndent) {
    const obj = {};
    while (i < lines.length) {
      const line = lines[i];
      if (line.trim() === "" || line.trim() === ")") { i++; if (line.trim() === ")") return obj; continue; }
      const indent = line.match(/^(\s*)/)[1].length;
      if (indent < baseIndent) return obj;
      const m = line.match(/^\s*\[(.+?)\] => (.*)$/);
      if (!m) { i++; continue; }
      const [, key, value] = m;
      if (value.trim() === "Array") {
        i++;
        while (i < lines.length && lines[i].trim() === "") i++;
        if (i < lines.length && lines[i].trim() === "(") {
          i++;
          obj[key] = parseBlock(indent + 4);
        } else {
          obj[key] = null;
        }
      } else {
        obj[key] = value;
        i++;
      }
    }
    return obj;
  }
  while (i < lines.length && lines[i].trim() !== "Array") i++;
  i++;
  while (i < lines.length && lines[i].trim() === "") i++;
  if (i < lines.length && lines[i].trim() === "(") { i++; return parseBlock(4); }
  return null;
}

function redactRawText(text) {
  return text.replace(/(\[\s*(?:ApolloJWT|JSONWebToken|LicenseKey)\s*\]\s*=>\s*)\S+/gi, "$1[REDACTED]");
}

function extractSecrets(rawText) {
  const jwt = rawText.match(/\[\s*ApolloJWT\s*\]\s*=>\s*(\S+)/i)?.[1];
  const licenseKey = rawText.match(/\[\s*LicenseKey\s*\]\s*=>\s*(\S+)/i)?.[1];
  const subscriberId = rawText.match(/\[\s*SubscriberId\s*\]\s*=>\s*(\S+)/i)?.[1];
  return { jwt, licenseKey, subscriberId };
}

async function callPortalMethod(environment, methodName, params = {}) {
  const { portalUrl } = getEnv(environment);
  const email = params.email ?? requireEnvVar("WEBGILITY_PORTAL_EMAIL");
  const product = params.product ?? process.env.WEBGILITY_PORTAL_PRODUCT ?? "Unify Enterprise";

  const body = new URLSearchParams({
    MethodName: methodName,
    Email: email,
    Product: product,
    ...(params.extra ?? {}),
  });

  const resp = await fetch(portalUrl, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString(),
    signal: AbortSignal.timeout(30_000),
  });
  const rawText = await resp.text();
  return { ok: resp.ok, status: resp.status, rawText };
}

function cacheKeyFor(environment, email) {
  return `${environment}:${email ?? process.env.WEBGILITY_PORTAL_EMAIL ?? ""}`;
}

async function ensureJwt(environment, email) {
  const key = cacheKeyFor(environment, email);
  const cached = sessionCache.get(key);
  if (cached?.jwt && cached.jwtExpiresAt && cached.jwtExpiresAt.getTime() - Date.now() > 5 * 60_000) {
    return cached;
  }

  const methodName = cached?.licenseKey ? "refreshApolloJWT" : "getLicenseInfoV2";
  const extra = cached?.licenseKey ? { Key: cached.licenseKey } : {};
  const { ok, status, rawText } = await callPortalMethod(environment, methodName, { email, extra });
  if (!ok) throw new Error(`Portal call (${methodName}) failed: HTTP ${status}`);

  const { jwt, licenseKey, subscriberId } = extractSecrets(rawText);
  if (!jwt) throw new Error(`Portal response for ${methodName} did not contain a session value — raw (masked): ${redactRawText(rawText).slice(0, 500)}`);

  const entry = {
    jwt,
    jwtExpiresAt: decodeJwtExpiry(jwt) ?? new Date(Date.now() + 6 * 3600_000),
    licenseKey: licenseKey ?? cached?.licenseKey,
    subscriberId: subscriberId ?? cached?.subscriberId,
  };
  sessionCache.set(key, entry);
  return entry;
}

const server = new Server(
  { name: "webgility-portal", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

const ENV_PROP = { environment: { type: "string", description: `Which portal: ${Object.keys(ENVIRONMENTS).join(" or ")}. Call list_environments if unsure.` } };

const TOOLS = [
  { name: "list_environments", description: "List the portal environments this server knows about (dev/prod) and their URLs.",
    inputSchema: { type: "object", properties: {} } },
  { name: "get_client_info", description: "Look up a subscriber's account status (account id, status, channel, etc). Input: { environment, email? (defaults to WEBGILITY_PORTAL_EMAIL), product? (defaults to WEBGILITY_PORTAL_PRODUCT) }",
    inputSchema: { type: "object", properties: { ...ENV_PROP, email: { type: "string" }, product: { type: "string" } }, required: ["environment"] } },
  { name: "refresh_session", description: "Refresh the cached session for an environment+email (normally automatic — any call refreshes it when needed). Returns only the new expiry time. Input: { environment, email? }",
    inputSchema: { type: "object", properties: { ...ENV_PROP, email: { type: "string" } }, required: ["environment"] } },
  { name: "call_portal_method", description: "Low-level passthrough to any Method Name the portal's test page supports (getClientInfo, getLicenseInfoV2, getLicenseInfoSchedulerV2, getLicenseInfoBypassSessionV2, getUserList, getUpgrade, getShippingInsurenceRateList, etc). Sensitive fields in the response are masked before being returned. Input: { environment, methodName, email?, product?, extra? }",
    inputSchema: { type: "object", properties: { ...ENV_PROP, methodName: { type: "string" }, email: { type: "string" }, product: { type: "string" }, extra: { type: "object" } }, required: ["environment", "methodName"] } },
  { name: "get_cis_order", description: "Fetch a single order directly from CIS (api/orders/IndividualOrderDownload) — the exact backend call WD itself makes when downloading an order, without opening WD's UI. Input: { environment, subscriberId, profileId, orderNo, email? }",
    inputSchema: { type: "object", properties: { ...ENV_PROP, subscriberId: { type: "string" }, profileId: { type: "number" }, orderNo: { type: "string" }, email: { type: "string" } }, required: ["environment", "subscriberId", "profileId", "orderNo"] } },
];

server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  const a = args ?? {};

  try {
    switch (name) {
      case "list_environments": {
        const rows = Object.entries(ENVIRONMENTS).map(([environment, cfg]) => ({ environment, ...cfg }));
        return { content: [{ type: "text", text: JSON.stringify(rows, null, 2) }] };
      }
      case "get_client_info": {
        const { ok, status, rawText } = await callPortalMethod(a.environment, "getLicenseInfoV2", { email: a.email, product: a.product });
        if (!ok) return { content: [{ type: "text", text: `Portal error HTTP ${status}` }], isError: true };
        const { jwt, licenseKey, subscriberId } = extractSecrets(rawText);
        if (jwt) {
          sessionCache.set(cacheKeyFor(a.environment, a.email), {
            jwt, jwtExpiresAt: decodeJwtExpiry(jwt) ?? new Date(Date.now() + 6 * 3600_000), licenseKey, subscriberId,
          });
        }
        const redacted = redactRawText(rawText);
        const parsed = parsePrintR(redacted);
        return { content: [{ type: "text", text: JSON.stringify({ parsed, raw: redacted, sessionReady: !!jwt }, null, 2) }] };
      }
      case "refresh_session": {
        const key = cacheKeyFor(a.environment, a.email);
        sessionCache.delete(key);
        const entry = await ensureJwt(a.environment, a.email);
        return { content: [{ type: "text", text: JSON.stringify({ subscriberId: entry.subscriberId, expiresAt: entry.jwtExpiresAt }, null, 2) }] };
      }
      case "call_portal_method": {
        const { ok, status, rawText } = await callPortalMethod(a.environment, a.methodName, { email: a.email, product: a.product, extra: a.extra });
        if (!ok) return { content: [{ type: "text", text: `Portal error HTTP ${status}` }], isError: true };
        return { content: [{ type: "text", text: redactRawText(rawText) }] };
      }
      case "get_cis_order": {
        const { cisBaseUrl } = getEnv(a.environment);
        const { jwt } = await ensureJwt(a.environment, a.email);
        const url = `${cisBaseUrl}/api/orders/IndividualOrderDownload?subscriberId=${encodeURIComponent(a.subscriberId)}&profileId=${encodeURIComponent(a.profileId)}&orderNo=${encodeURIComponent(a.orderNo)}`;
        const resp = await fetch(url, {
          headers: { Authorization: `bearer ${jwt}` },
          signal: AbortSignal.timeout(30_000),
        });
        const text = await resp.text();
        if (!resp.ok) return { content: [{ type: "text", text: `CIS error HTTP ${resp.status}: ${text}` }], isError: true };
        return { content: [{ type: "text", text }] };
      }
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

Then:
```
cd C:\WG-Agentic\wg-ai-workspace\.mcp-servers\webgility-portal
npm install
```

**Add to `wg-ai-workspace/.env`:**
```
WEBGILITY_PORTAL_EMAIL=krishna.bankar@webgility.com
WEBGILITY_PORTAL_PRODUCT=Unify Enterprise
```

**Add to `KrishnaAiGen/.claude/mcp/wg-mcp.json`:**
```json
"webgility-portal": {
  "command": "node",
  "args": [
    "--env-file",
    "C:/WG-Agentic/wg-ai-workspace/.env",
    "C:/WG-Agentic/wg-ai-workspace/.mcp-servers/webgility-portal/server.mjs"
  ]
}
```
Then run `powershell -ExecutionPolicy Bypass -File C:\WG-Agentic\KrishnaAiGen\.claude\scripts\sync-workspace.ps1` and start a new session.

**Open items to confirm on first live call** (I couldn't test this myself — same classifier blocks a live call): exact POST field names on the form (assumed `MethodName`/`Email`/`Product`), the `print_r`-text response format (parser is best-effort), and prod's real CIS hostname (`cis.webgility.com` is a guess). Once I'm back in a session with this registered, I'll fix any of those against the real response.