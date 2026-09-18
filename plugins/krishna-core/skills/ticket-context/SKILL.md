---
name: ticket-context
description: "Use at the START of any work on a Jira ticket (UD-xxxxx, WOC-xxxxx, a Customer Issue, or a HubSpot case) to gather everything already known about it before touching code — the Reference/<TICKET>/ folder of screenshots, logs and sample data, prior customization memories, the branch, and the Jira issue itself. Also use when asked to write up or resume a ticket."
---

# ticket-context — gather what is already known before starting

Krishna keeps per-ticket working material on disk. Reading it first routinely saves a
whole round of questions, and skipping it is how the same investigation gets done twice.

Run this **before** planning or editing, not after.

## 1. The Reference folder

```
C:\WG-Agentic\Reference\<TICKET-ID>\
```

One folder per Jira ID (`UD-33334`, `UD-32762`, `UD-33257`, …). Not every ticket has one.
It typically holds:

| What | Examples seen |
|---|---|
| Screenshots of the reported behavior | `BeforeQtySync.png`, `ReorderPointAlertPopup.png` |
| Sample payloads from the store or CIS | `#12764_2Item_2LotNumEach.json`, `MDS1643.json` |
| Customer logs | `<date>_Debug.log`, `_Error.log`, `_Info.log` |
| Prior analysis | `RCA_*.md`, `*-qa-verification.html`, implementation plans |
| Draft PR / review replies | `PR10422_ReviewReplies_Draft.md` |
| Exported data | `*.csv` from a report being fixed |

Loose files directly under `Reference\` (not in a ticket folder) are cross-ticket:
RCA write-ups, `Branch_PR.txt`, design HTML. Scan filenames for the ticket ID before
concluding there is nothing.

**How to read it:** list the folder first, then open only what the question needs.
Screenshots are worth opening when the ticket is about UI or about what the customer saw.
Do not dump whole logs into context — grep them for the error, the order number, or the
profile ID.

## 2. Prior memories on this ticket or module

Two places, both worth a look:

- **`unify-enterprise/memories/<module>/`** — one fact per file, JSON or MD, written by
  previous sessions (`posting/`, `accounting/`, `payout/`, `inventory/`, `channels/`,
  `cross-domain/`, `qa/`, `shipping/`, `platform/`, `pipelines/`). Grep the whole tree for
  the ticket ID first — a prior session may have recorded exactly the trap you are about to hit.
- **Claude's own memory directory** — check whether a `ticket` or customization note
  already exists for this ID before re-deriving it.

## 3. The ticket itself

Fetch it with the Atlassian MCP tools (`mcp__claude_ai_Atlassian_Rovo__getJiraIssue`).
Read the description, the acceptance criteria, and **the comments** — for customer issues
the actual requirement is usually in a comment, not the description.

For a customization ticket (CIM / FR / CFC), also resolve the customer **Profile ID** and
check `wg.eCC.DTO/Shared/CustomizationConstant.cs` for an existing `PREFIX_<ProfileID>`
node — the work may already be half-built.

## 4. Where the code for it lives

- Branch naming here is `UD-xxxxx_Krishna` / `UD-xxxx-krishna`. `git branch -a | grep <id>`
  finds an existing branch before you create a second one.
- The two working trees can sit on **different branches** — check both:
  `C:\WG-Agentic\unify-enterprise` and `C:\WG-Agentic 2\unify-enterprise`.

## 5. Report what you found, briefly

Before proceeding, state in a few lines: what the ticket asks, what material already
exists, what a prior session already established, and what is still unknown. Then start.

If the Reference folder, the memories and Jira disagree, say so rather than silently
picking one — on customer issues the newest comment usually wins, but flag it.

## Writing the context back

When a ticket's work is finished, or when asked to "prepare context" for one, write the
durable version to `unify-enterprise/memories/customizations/<TICKET>-<slug>.md`
(create the folder if it does not exist yet), covering: what the feature does, the
settings and customization node that gate it, the processing logic, how it posts to
QuickBooks, known issues and their fixes, impact analysis, test scenarios, a diagnostic
checklist, and how to resume the work. One file per ticket, updated rather than duplicated.
