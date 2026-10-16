---
name: cis-db-access
description: "Use when: looking up Shopify/store order, channel, or subscriber data directly in CIS Postgres (not WD/UnifyDB) — which CIS environment/host/database to use, the subscriber->shard->message lookup chain, channelsettings/message/message_cache schema and enums, or setting up another direct CIS DB connection. Covers prod, QA, QA2-4, stage and dev environments."
---

# cis-db-access

Full operational detail lives in **`reference.md`** next to this file. **Read `reference.md`
before running a CIS query or deciding which host/database to use** — this page is only a map.

## Sections in `reference.md`

- (line 3) 1. What CIS is, and the two ways to reach it
- (line 21) 2. Environment map — every host, port, database (source: Confluence "CIS Environments")
- (line 80) 3. What Krishna can actually reach right now
- (line 96) 4. Schema reference — channelsettings, manageusershardservers, message, message_cache
- (line 157) 5. The lookup chain — subscriber -> shard -> order, with working queries
- (line 195) 6. Shopify order identifier mapping (two different IDs, don't confuse them)
- (line 204) 7. Gotchas learned the hard way
- (line 232) 8. CIS REST APIs (Swagger) — the alternative to direct SQL
- (line 250) 9. Adding another direct connection later

> Built 2026-10-09 from the Confluence "CIS Environments" page
> (`https://webgility.atlassian.net/wiki/x/AQB0`) plus everything learned live while setting up
> `cis-qa-wgs`/`cis-qa-shard3` and debugging the `cis-db-proxy` HTTP proxy. Keep this updated
> when a new environment/host is added or a query pattern proves wrong — this is meant to make
> the next CIS request a one-shot, not a re-investigation.
