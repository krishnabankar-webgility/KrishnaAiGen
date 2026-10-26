# CIS DB Access — full reference

## 1. What CIS is, and the two ways to reach it

CIS (Cloud Integration Systems) is the Platform REST API every store/channel call from WD and
WO goes through — WD never calls Shopify/Amazon/eBay directly (see root `CLAUDE.md`). Its data
lives in a set of Postgres databases, split into a **settings** database (`wgsettings`-family:
subscriber/profile/channel config) and 1-3 **shard** databases per environment (`wgmessage`-
family: the actual order/product/payment messages), plus an **audit** database.

Two ways to query this data:

1. **Direct Postgres connection** — what this reference is mostly about. Fast, full SQL,
   needs a direct network route + DB credentials per host.
2. **HTTP OpenAPI proxy** (`cis-db-proxy` MCP server, `postgres-mcp` under the hood) — a
   wrapper some environments expose so you don't need direct DB credentials. See §3 for which
   one is actually live right now.

---

## 2. Environment map — every host, port, database

Source of truth: Confluence **"CIS Environments"** (`https://webgility.atlassian.net/wiki/x/AQB0`,
page id `7602177`) — re-read that page if this ever looks stale, it's the team's own doc, not
mine. **Note from that page: pgbouncer (connection pooling) listens on port 6432 on these same
hosts — direct port 5432 is what's confirmed working for the connections below, 6432 is the
pooled alternative if 5432 ever gets restricted.**

### CIS Production (`https://cis.webgility.com`)

| Role | Host | Port | Database(s) |
|---|---|---|---|
| Settings | `prod-wgs.corp.webgility.com` | 5432 | `wgsettings`, `message_Seqdb`, `wg_data_privacy` |
| Shard 1 | `postgres-prd1.corp.webgility.com` | 5432 | `wgmessage_shard1` (+ `message_2022`) |
| Shard 2 | `prod-shard2.corp.webgility.com` | 5432 | `wgmessage_shard2` (+ `message_2022`) |
| Shard 3 | `awlx-cisp-pg03.corp.webgility.com` | 5432 | `wgmessage_shard3` (+ `message_2022`) |
| Audit | `audit-prd.corp.webgility.com` | — | `Audit_2018`..`Audit_2021`, `wgsettings_Audit` |
| Data model | `prd-dm1.corp.webgility.com` | — | `wg_datamodel`, `wg_datamodel_new`, `wg_datamodel_old` |
| Backup | `172.31.65.170` | 5432 | `wgmessage_shard1_copy`, `wgmessage_shard2_restore` |

### CISQA (`https://cisqa.webgility.com`) — the environment Krishna actually uses

| Role | Host | Port | Database(s) |
|---|---|---|---|
| Settings | `postgres-qa1.corp.webgility.com` | 5432 | `wgSettingsDev3QA`, `wgSettingsDev3QA_Shard1`, `wgSettingsQA_Shard1`, `wg_datamodel_QA`/`_QA3`, `wgsettings_qa2`(+`_shard1`) |
| Settings (alt host) | `audit-qa.corp.webgility.com` | 5432 | **`wgSettingsQA`** (this is the one in use — `channelsettings`, `manageusershardservers` live here), `wgSettingsQA_Audit`, `message_seqdb_QA` |
| Shard 2 | `pgqa-shard2.corp.webgility.com` | — | `wgSettingsQA_Shard2`, `wgsettingsDev3QA_Shard2`, `wg_wiap`, `wgnotificationDev3QA` |
| Shard 3 | `pgqa-shard3.corp.webgility.com` | 5432 | **`wgSettingsQA_Shard3`** (this is the one in use) |

### Other QA variants (exist, not wired up — note if ever needed)

| Environment | Host | Database(s) |
|---|---|---|
| CISQA2 (`cisqa2.webgility.com`) | `postgres-qa1.corp.webgility.com` | `wgsettings_qa2`, `wgsettings_qa2_shard1` |
| CISQA2 shard3 | `pgqa-shard3.corp.webgility.com` | `wgsettings_qa2_shard3` |
| CISdev3QA (`cisdev3-qa.webgility.com`) | `postgres-qa1` / `pgqa-shard2` / `pgqa-shard3` / `audit-qa` | `wgSettingsDev3QA` family |
| CISQA4 (`cisdev4-qa.webgility.com`) | `pgqa-shard3.corp.webgility.com` | `wgSettingsQA4_Shard3` (shard1/2/3 all point here), `wgSettingsQA4` |
| CISQA4 audit | `audit-qa.corp.webgility.com` | `wgSettingsQA4_Audit` |

### CIS Stage (`https://cis-stage.webgility.com`)

| Role | Host | Database(s) |
|---|---|---|
| Settings | `postgres-stg1.corp.webgility.com` | `wgsettings`, `wgmessage_shard1`, `message_seqdb`, `wgsettings_test` |
| Audit / Shard 2 | `audit-stg.corp.webgility.com` | `wgmessage_shard2`, `wgsettings_Audit`, `Audit_2018`/`2019`/`message_2021` |
| Shard 3 | `postgres-awlx-cis-spg3.corp.webgility.com` | `wgmessage_shard3` |
| Data model | `stg-dm1.corp.webgility.com` | `wg_datamodel`, `wg_datamodel1`, `wg_datamodel_old` |

### Dev environments (CIS localhost / CISDev / CISDev2 / CISDev3 / cisdev4) — local/dev only

All share **`postgres-dev1.corp.webgility.com`** (settings + shard1 + data model),
**`pgdev-shard1.corp.webgility.com`** (shard2), **`audit-dev.corp.webgility.com`** (audit), with
per-team database name suffixes (`CIS_LocalDev1`, `CIS_LocalDev2`, `CIS_LocalDev3`,
`wgSettings_Dev4_Shard2`, etc). Owned by the India/US dev teams per the Confluence page — not
something to connect to without a reason; listed here only so a mention of e.g. `CISDev2`
resolves to a real host instead of a guess.

---

## 3. What Krishna can actually reach right now

| Access path | Status | Notes |
|---|---|---|
| `cis-db` MCP — **one server, host picked per call** (direct Postgres) | **Live** | `execute_sql({ target, sql })`, SELECT-only. `list_targets` lists what's configured. Today: `qa-wgs` (`wgSettingsQA` on `audit-qa.corp.webgility.com`) and `qa-shard3` (`wgSettingsQA_Shard3` on `pgqa-shard3.corp.webgility.com`). Credentials `CIS_QA_WGS_DB_*` / `CIS_QA_SHARD3_DB_*` in `.env`. See `setup-cis-qa-postgres.md`. |
| `cis-db-proxy` MCP (HTTP proxy, `192.168.0.231:9000`, segments `qa`/`qa1`-`qa5`/`qa-shard3`) | **Blocked** | `CIS_DB_PROXY_BEARER_TOKEN` in `.env` is invalid (403) — get a current one from the team password manager / proxy owner, not generated by Krishna. See `setup-sql-server.md`. |
| Direct Postgres to **production** (`cis-db` targets `prod-wgs`, `prod-shard1/2/3`) | **Live (2026-10-22), read-only** | One shared login `CIS_DB_USER/PASSWORD/PORT` for QA + prod, per-host only `CIS_<X>_DB_HOST/NAME`; 6432 pgbouncer is an automatic fallback. Lookup: `prod-wgs` `manageusershardservers` (subscriberid -> shardserverid) then that shard's `message_cache`. Prod payload is in **`marshalleddatav2`** (`marshalleddata` is NULL in message_cache). `messagetypeid` 55 = PurchaseOrder (cloud-integration-systems `MessageTypes.cs`). The classifier denied a `select *` on `manageusershardservers`; named columns passed. Setup: `docs/setup-cis-prod-postgres.md`. |
| CIS REST APIs (Swagger) | **Not used** | See §8 — a live alternative if direct DB access is ever unavailable. |

Shard-1/shard-2 targets don't exist yet in `TARGETS` — only `qa-shard3` was added because that's
where the orders actually used in testing (subscriber 79665/86640 etc.) happen to live. Add one
the same way (§9) if a lookup ever resolves to shard 1 or 2 — it's a `.env` + one-line addition,
not a new server.

---

## 4. Schema reference

### `public.channelsettings` (in the settings DB — `wgSettingsQA` / `wgsettings` etc.)

One row per subscriber+profile+integration. Key columns:

| Column | Meaning |
|---|---|
| `subscriberid` | The account. |
| `profileid` | Which store/channel config under that subscriber (`> 0` for real profiles). |
| `integrationtypeid` | Which platform — **Shopify = 13** (full enum in §6/below). |
| `storename` | Human label — **not unique**, can be reused across many unrelated profiles (a shared QA demo store like "mewebg" is used by ~50 different test profiles — storename alone never identifies "the" profile, see §7). |
| `store_account_id` | Internal store account id. |
| `channeltype` | 1=Store, 2=Shipping, 3=Payment, 4=AccountingSoftware. |
| `extradata` (jsonb) | Per-platform connection details — for Shopify: `AccessToken`, `ShopifyStoreName`, `DownloadStartDate`, etc. **`extradata->>'ShopifyStoreName'`** is the actual Shopify shop slug — more reliable than `storename` for matching a specific store. |
| `isdeleted`, `isenabled`, `isexpired` | Always filter `isdeleted = false` for a live profile. |

### `public.manageusershardservers` (same settings DB)

Maps `subscriberid` -> which message shard its data lives on:
```sql
SELECT shardserverid FROM public.manageusershardservers WHERE subscriberid = <id>;
```
`shardserverid` 1/2/3 -> shard1/shard2/shard3 host (per environment, see §2).

### `public.message` (in the shard DB)

The durable message log — one row per message version; `islatestrecord = true` marks the
current one. **Can be stale** — a profile with no recent download activity may have nothing
newer than weeks ago even though fresher data exists in `message_cache` (see §7).

Allowed/known columns: `id`, `subscriberid`, `profileid`, `externalentitycode`, `messagetypeid`,
`testmode`, `createdon`, `marshalleddata`, `channeltype`, `islatestrecord`, `integrationtypeid`,
`searchkey`, `request_id`, `marshalleddatav2`.

### `public.message_cache` (in the shard DB)

The current-state cache — keyed by `store_account_id` rather than `profileid` directly, and
gets updated on real sync activity even when `message` hasn't had a fresh batch write. **Check
this when `message` comes back empty for an order you know exists.**

Allowed/known columns: `id`, `subscriberid`, `channeltype`, `messagetypeid`, `externalentitycode`,
`testmode`, `marshalleddata`, `integrationtypeid`, `searchkey`, `external_createdon`,
`external_updatedon`, `createdon`, `updatedon`, `store_account_id`, `external_status`,
`marshalleddatav2`.

### Enums worth having memorized

**`messagetypeid`:** Order=1, Refund=6, Product=7, Shipping=18, Payment=19,
ProductInventory=20, SettlementReport=25, Report=31, DraftOrder=33, Invoice=36, Payout=37,
Return=57, PaymentTransaction=58.

**`channeltype`:** Store=1, Shipping=2, Payment=3, AccountingSoftware=4.

**`integrationtypeid`** (the ones likely to come up): Shopify=13, Amazon=10, AmazonEU=11,
eBay=19, Etsy=22, BigCommerce=15, WooCommerce=41, Walmart=32, QuickBooksOnline=46, PayPal=26,
Square=28, Stripe=44. (Full list in `.github/skills/cis-tech-support-db/SKILL.md` if a rarer
one comes up.)

---

## 5. The lookup chain — subscriber -> shard -> order

**Step 1 — find the subscriber/profile** (run on the settings DB, target `qa-wgs`):
```sql
SELECT subscriberid, profileid, store_account_id, channeltype,
       extradata->>'ShopifyStoreName' AS shopify_store_name
FROM public.channelsettings
WHERE integrationtypeid = 13        -- Shopify
  AND profileid > 0
  AND isdeleted = false
  AND extradata->>'ShopifyStoreName' = '<shop-slug>';
```

**Step 2 — find the shard** (same DB):
```sql
SELECT shardserverid FROM public.manageusershardservers WHERE subscriberid = <id>;
```
Or combine both in one query (see `setup-cis-qa-postgres.md` for the full join version).

**Step 3 — query the order on the matching shard connection**, filtering by
**`subscriberid` + `profileid` together** (this pair is indexed — a query without both times
out on the real table sizes, see §7):
```sql
-- by display order number
SELECT * FROM public.message_cache
WHERE subscriberid = <id> AND profileid = <pid> AND messagetypeid = 1
  AND marshalleddatav2->>'Number' = '#60366';

-- by Shopify numeric order id (externalentitycode)
SELECT * FROM public.message
WHERE subscriberid = <id> AND profileid = <pid> AND messagetypeid = 1
  AND islatestrecord = true
  AND externalentitycode = '18934295756862';
```
Check **both** `message` and `message_cache` if one comes back empty (§7).

---

## 6. Shopify order identifier mapping — don't confuse these two

| Field | Column | Example | Use when... |
|---|---|---|---|
| Shopify numeric order id | `externalentitycode` | `18934295756862` | You already have the numeric id (from the Shopify Admin API MCP, a webhook, or a prior query). |
| Display order number | `marshalleddatav2->>'Number'` | `#60366` | The user gives a store-visible number like `#60366` — **never** query that against `externalentitycode`. |

---

## 7. Gotchas learned the hard way

- **A shared QA store name doesn't identify a profile.** The demo store "mewebg" is reused by
  ~50 unrelated test profiles across many subscribers (classic WD QA pattern: one convenient
  Shopify dev store, many test configs pointed at it). `storename` or even
  `extradata->>'ShopifyStoreName'` alone is not enough — you need the actual subscriberid the
  user is working with, or you're guessing across dozens of candidates.
- **`message` can be stale while `message_cache` is current.** A profile's `message` table may
  not have had a fresh batch write in weeks even though a brand-new order exists — always check
  `message_cache` too before concluding an order "isn't there."
- **Cross-database references don't work.** Once a query is running against a specific `target`
  (e.g. `qa-shard3` → `wgSettingsQA_Shard3`), drop any `wgsettings.public.xxx`-style database
  prefix from example queries (including the ones in the Confluence/Copilot skill docs, which were
  written for the HTTP proxy where the DB name differs) — just use `public.xxx`.
- **An unscoped query times out.** `SELECT ... FROM message WHERE messagetypeid = 1 AND
  marshalleddatav2->>'Number' = '#X'` with no `subscriberid`/`profileid` filter will hit the
  statement timeout on the real table sizes — there's no usable index for that scan shape.
  Always resolve the subscriber first (§5 step 1-2).
- **The HTTP proxy's segment names and the actual environment aren't the same thing.**
  `cis-db-proxy`'s code (and the Confluence/Copilot skill docs) assume segments
  `wgs`/`shard1`/`shard2`/`shard3` at `172.31.76.42:9000` (production-shaped naming) — but
  Krishna's actual configured proxy URL point at a **different host**, `192.168.0.231:9000`,
  which exposes QA-shaped segments `qa`/`qa1`-`qa5`/`qa-shard3` instead. Don't assume the two
  naming schemes are interchangeable; check `GET /openapi.json` on whichever proxy host is
  actually configured before trusting a documented segment name.

---

## 8. CIS REST APIs (Swagger) — the alternative to direct SQL

Not currently used, but documented in case direct DB access is ever unavailable (e.g. before a
replacement bearer token arrives for `cis-db-proxy`). Dev environment Swagger UIs:
```
https://cisdev.webgility.com/swagger/invoices/index.html
https://cisdev.webgility.com/swagger/settings/index.html
https://cisdev.webgility.com/swagger/messages/index.html
https://cisdev.webgility.com/swagger/orders/index.html
https://cisdev.webgility.com/swagger/inventory/index.html
https://cisdev.webgility.com/swagger/Shipping/index.html
https://cisdev.webgility.com/swagger/userasset/index.html
```
Production/QA almost certainly expose the same paths under `cis.webgility.com` /
`cisqa.webgility.com` respectively (not yet confirmed live).

---

## 9. Adding another direct connection later

As of 2026-10-13, `cis-db` is a **single MCP server covering every direct-Postgres host** —
adding one more (a third shard, production, a customer's own DB) is just:
1. Add `CIS_<NAME>_DB_HOST/NAME/USER/PASSWORD/PORT` to `wg-ai-workspace/.env`.
2. Add one line to the `TARGETS` table in `cis-db/server.mjs` (`"<name>": "CIS_<NAME>_DB_"`).

No new `wg-mcp.json` entry, no new background process, no restart of other targets. Steps 1-2
still need to be Krishna's hand (editing the server file / `.env` that a running credentialed
MCP server reads is the same class of action Claude Code's safety classifier blocks — confirmed
on Shopify and the original two-server CIS setup) — see `setup-cis-qa-postgres.md` for the full
worked template. Write the ready-to-paste instructions, don't retry the blocked action.
