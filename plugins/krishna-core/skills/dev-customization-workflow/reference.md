# Customization workflow skill

Use this skill for **customer-specific customization** tasks in this repository. Load **`dev-customization-expertise.skill.md`** first for rules (including **Jira-in-code policy**, **call-site guards**, **mandatory code patterns**, and **completion checklist**); this file focuses on **workflow order** and **step-by-step execution**.

## Step-based implementation workflow (follow in strict order)

---

### STEP -1 — New customer issue bootstrap (runs the moment Krishna hands over a Jira ID)

Set up the workspace, then **tell Krishna in chat**. Krishna then writes his own analysis in the prompt file (manual process); never wait idle - do STEP -1B meanwhile.

**-1A. Scaffold (all six, in order; skip any that already exists, never overwrite):**

1. **Folder:** `C:\WG-Agentic\Reference\<JIRA-ID>\` (named with the Jira ID only, unless Krishna gives another location) containing `<JIRA-ID>_Prompts.txt` (header + `[Prompt 1]`, CRLF; Krishna fills it later).
   Also create an empty `<JIRA-ID>.sql` in the same folder (scratch SQL for the ticket: diagnostic queries, test-data setup, QBD/DB checks; Krishna 2026-10-26). Never overwrite an existing one.
2. **Branch:** `<JIRA-ID>_Krishna` in `unify-enterprise`, cut from **`origin/master`** (fetch first, `--no-track`). Never branch from the current branch.
3. **Local dev files on the branch** (uncommitted): `Desktop/eCC/Xml/apiConfig.xml` + `Desktop/wg.eCC.Controller/AuthenticationController.cs` taken from the **latest stash** (`git rev-parse stash@{0}` BEFORE doing anything), `apiConfig.xml` pointing `UnifyDB` as the catalog on the local SQL Server. Order that works with a dirty tree: `git stash push` current work -> `git checkout -b <ID>_Krishna --no-track origin/master` -> `git stash apply <latest-stash-SHA>`. The working copy may differ from the stash (ticket-specific `CustomizationNode` list) - the stash wins. Never commit these two files.
4. **Confluence page** in Personal -> **Customizations** folder (`3027959816`, space `2590998546`, cloud `a8ce84dd-8aa2-4dd1-b893-5b33a896f918`), title `<JIRA-ID> <prefix>` where prefix is the Jira summary prefix (`CIM` / `FR` / `RN-CIM` / `RN-FR` ...). Body = **Customer Issue Ticket Template** (page `3080192055`, tiny `https://webgility.atlassian.net/wiki/x/NwCYtw`; sections: Customer Issue / HubSpot / Development [Branch, Pull Request, Local Build, Technical Doc] / Customization Node / Environment & Access [Zoom Recording, Backup, Implementation Logic / Prompt, Test Orders]). This replaces the older Customization Notes Template for new pages. Fill only what is known (Jira URL + status, HubSpot link, branch, tech-doc path); leave the rest blank, never invent PR/build/node values.
5. **Jira status (Krishna, 2026-11-09, UD-33880):** move the customer issue to **Design In Progress**, and move each related issue (bug / story / customer issue) to **In Progress** only if it is in the implementation scope. Leave out-of-scope linked issues alone. If a transition is refused (e.g. auto-mode permission), say so; never work around it.
6. **Customer DB + local login (Krishna, 2026-11-09, UD-33880):** if a customer backup exists, find the existing reference DB (`msdb.dbo.restorehistory` by destination name, or the vault/memory note) and restore the **latest** backup over it with REPLACE (safety `COPY_ONLY` backup of the old copy first); if no reference DB exists, create one named after the Jira ID. Then run `wgDB_alter.sql` then `wgDB_update.sql` from the branch (`db-restore` §5). Then:
   - `Desktop\eCCDebug\Xml\remme.txt` <- `SchedulerService.Email` + `Password` (line 1 email, line 2 stored password, CRLF, same pattern as the file). Never print the values.
   - `apiConfig.xml` (both `Desktop\eCC\Xml` and `Desktop\eCCDebug\Xml`): `Initial Catalog=<customer DB>`; `<Mode>prod</Mode>` and comment out `<CIS_URL>` for a customer (prod) DB, `<Mode>dev</Mode>` for a local/QA DB.
   - Enhancement/fix on an existing customization: append the existing node with the profile ID (`Settings_Profiles.IDProfiles` for the store named in the issue or existing docs). Brand-new request: add the new node only after the implementation plan defines it.

**-1B. Then, without being asked (read-only analysis):**

Read the issue fully + every Jira comment (incl. bot/FR analysis comments), linked issues and the HubSpot ticket; check **existing WD configuration** (STEP 0.5) and **existing customizations alone or combined** (STEP 1).

**Order is mandatory (Krishna, 2026-10-21):** FIRST tell Krishna in chat what you found - an existing config, an existing customization (alone or combined), or a workaround - or that none exists. **Only if no resolution already exists**, write `Reference/<JIRA-ID>/<JIRA-ID>_ImplementationPlan.md` (new FR/CIM) - high-level (ask, scope, flows) down to low-level (files, methods, data, gating node, tests). If something already solves it, stop at the chat finding and let Krishna decide; no plan md.

**Jira comments are two-stage (Krishna, 2026-10-21):**
1. **First comment = effort estimation (SP) ONLY** (`jira-workflow` §1a.1: complexity-based Fibonacci, Analysis / Dev / QA / Combined), with one brief line per figure saying what it covers. No approach, workflow or plan text. Post it after the existing-coverage finding; Krishna's SP method is known - do not ask how; if unsure of a figure, show it in chat first. **Post it even when the Jira Story Points field is already filled** (Krishna sets that field by hand; it is not the estimate comment - UD-33709 miss, 2026-10-23).
2. Then continuous prompting in `<JIRA-ID>_Prompts.txt` until the final implementation plan exists.
3. **Only when Krishna says so**, post a NEW comment: the high-level implementation plan + the updated SP estimate. **Never delete or edit the earlier estimate comment** - the history of the estimate stays visible.

**Housekeeping (Krishna, 2026-10-21):** always `git stash push` any uncommitted work BEFORE switching branches so it is saved for next time; and rename the Claude session chat to the Jira ID only (`/rename <JIRA-ID>`; tell Krishna if it cannot be done from inside the session).

**-1C. Handoff:** report -1A done in chat, keep going on -1B, and when Krishna names a prompt (`Prompt N` in `<JIRA-ID>_Prompts.txt`) take his analysis/plan/feedback there as the next instruction. Chat stays short: gaps, blockers, questions only; detail goes in the md.

**-1D. Close-out Confluence update (Krishna, 2026-11-09, UD-33880):** when all cases and QA bugs are done and the customer issue goes to **Ready for Release** or its PR merges, or when Krishna confirms, update the STEP -1A Confluence page. Below the customer-issue request details, add one short start-to-end technical summary:
- what this issue's implementation covered
- extra items done, new behaviour, out-of-scope items, limitations
- effort estimate before (the Jira estimate comment) vs after implementation and testing, and the PR
- the QA Jira note: build, branch, node, impacted areas, and other details
- attach or link the `<JIRA-ID>_ImplementationPlan.md`
Then link the Confluence page on the main customer issue in Jira.

---

### STEP 0 — Read the Jira Ticket

Before anything else, read the provided Jira ticket and extract:

| Field | What to Look For |
|-------|-----------------|
| **Ticket Type** | CIM / Customization, FR / Feature Request, CFC / Feasibility Check |
| **Customer / Profile ID** | Mentioned in description or linked account |
| **Request Summary** | What the customer needs — in one clear sentence |
| **Business Logic** | Rules, conditions, field mappings, expected behaviour |
| **Affected Area** | Which module, transaction type, report, or flow is impacted |
| **Attachments / Screenshots** | Any reference files, DB queries, sample data |

> Present your understanding of the ticket and **wait for confirmation before proceeding.**

---

### STEP 0.5 — Check for an Existing Generic Configuration First

> Mandatory, and **before** Step 1 — cheaper than a customization node and often already
> shipped. Skipping straight to "what node do we need" misses the case where a plain
> setting/toggle already does the job for every customer, not just this one.

- Look for an existing **generic setting, UI toggle, or configuration** (not gated behind any
  customization node) that already fulfills the request, fully or partly, for any customer who
  turns it on.
- If one fully covers the request: that's the answer — no customization, no new node. Say so
  and stop here.
- If it covers **part** of the request, carry the remaining gap into Step 1 (it may be filled
  by an existing node, or need new work) — don't restart the analysis from scratch once a
  partial generic-config answer is found.

### STEP 1 — Check for Existing Customization Node Solution

> This step is **mandatory** for all ticket types: CIM, FR, and CFC. Reached when Step 0.5
> found no (or only a partial) generic-configuration answer.

#### 1.1 — Locate All Customization Nodes
- Open `CustomizationConstant.cs` in the **unify-enterprise** workspace.
- This file is the **single source of truth** for all customization nodes.
- Do **not** look for nodes anywhere else.

#### 1.2 — Find a Matching Node or Combination
Evaluate whether the customer request can be fulfilled by, in this order:

| Scenario | Description |
|----------|-------------|
| **Single Node** | One existing node fully covers the requirement |
| **Combination of Nodes** | Two or more nodes together fulfill the requirement |
| **Config + Node(s)** | The Step 0.5 generic setting plus an existing node together cover it |
| **Nodes + Extra Handling** | Existing node(s) with minor additional changes cover the requirement |
| **Partial + New Work** | Existing settings/node(s) cover part of the requirement; the remaining part is genuinely new — scope the new work to just that remainder, not the whole request |

Only once every row above has been ruled out does this become new, from-scratch work —
and only then move to Step 2's architecture-level analysis.

#### 1.3 — Understand the Node's Workflow
For any candidate node found:
- Review its definition in `CustomizationConstant.cs`
- Find **all references** of that node across the codebase
- Understand its complete workflow and solution flow end-to-end

#### 1.4 — Present Findings
- Always suggest existing solutions **first**, before proposing new implementation.
- Clearly explain how the existing node(s) can address the customer request.
- If a combination is needed, explain how they work together and what extra handling is required.

> **Present findings and wait for confirmation.**
> Proceed to Step 2 **only** if no existing solution can fulfill the request.

---

### STEP 2 — Code Analysis & Implementation Plan

> Reached only if Step 1 confirms no existing solution is applicable.

#### 2.1 — Code Analysis
- Identify all files, classes, and methods relevant to the implementation area.
- Understand the existing code flow end-to-end before proposing any changes.
- Document integration points where new logic will be injected.

#### 2.2 — Define New Customization Node

| Ticket Type | Node Definition Rule |
|-------------|---------------------|
| **CIM / Customization** | Define node **with `_` at the end** — Profile ID specific |
| **FR / Feature Request** | Define node **without `_` at the end** — all profiles |

- Add the new node to `CustomizationConstant.cs`.
- Naming convention must clearly describe what the customization does.

#### 2.3 — Prepare Implementation Plan
Present a structured plan covering:

1. New customization node name, type, and location in `CustomizationConstant.cs`
2. All files to be modified
3. Where the customization node condition will be applied
4. New method(s) to be created and their responsibilities
5. Business logic breakdown — step by step
6. Any DB changes, queries, or schema updates required
7. All transaction types or flows in scope
8. Build targets affected by the changes

**Write the plan to its own implementation file** at
`Reference\<TICKET-ID>\<TICKET-ID>_Implementation.md` (create the ticket folder if it doesn't
exist yet) — this is a separate file from the plan presented in chat, not just a copy of the
chat message. Keep the chat message itself short: a summary, plus the file path. **Any open
question, blocker, or confirmation needed goes in the chat itself** (concise, summarized), not
buried inside the implementation file — the file is the plan, the chat is where decisions get
made. Skip re-flagging anything already clarified earlier in the conversation or resolved by
code analysis.

> **Present the plan. Do NOT begin coding until it is reviewed and approved.**
> Incorporate feedback and re-present if corrections are requested.
> Once approved, this is also the trigger point for `jira-workflow` §1a — post the
> summarized plan (with Fibonacci Story Points) as a Jira comment **before** Step 3 begins.

---

### STEP 3 — Implementation

Once the plan is approved, begin code changes following these rules:

#### ✅ Mandatory Implementation Rules

**For ALL changes — CIM and FR:**
- Every new code change **must** be gated behind a customization node condition.
- **Zero direct changes** to existing code flow without a node condition — no exceptions.
- Follow the **modular pattern** strictly:
  ```
  [Customization Node Condition]
      → Call new dedicated method
          → All business logic lives inside the new method
  ```

**For CIM (Customization — Profile-Specific):**
- Node condition must include **Profile ID check** using the `_` suffix convention.
- Logic applies only to the specified customer profile.

**For FR (Feature Request — All Profiles):**
- Node condition applies **without Profile ID** — available to all profiles.
- No `_` suffix in node value.

#### ✅ Code Quality Rules
- Write **modular code** — one method per responsibility.
- Never embed business logic directly inside a node condition block — always delegate to a new method.
- Add **Kibana log statements** for all errors and exceptions — mandatory.
- Remove any unnecessary, redundant, or debug code before presenting changes.

#### ⚠️ Constraints
- Work on **current local branch only.**
- **No commits. No pushes. No PRs at this stage.**
- Present all code changes for review after implementation.

---

### STEP 4 — Build & Resolve Failures

After implementation:

1. **Rebuild** all projects and files where new changes were added.
2. Review build output for any errors, warnings, or failures.
3. **Resolve all build failures** before proceeding.
4. Re-build after fixes to confirm a clean build.

> Do **not** proceed to Step 5 until the build is clean.

---

### STEP 5 — Unit Tests

Once the build is clean:

1. Write **unit test code** covering:
   - The new customization node condition logic
   - All new methods and business logic
   - Edge cases and failure scenarios
2. **Re-build** the project including test code.
3. **Run all unit test cases.**
4. Resolve any test failures — fix and re-run until all tests pass.

> Do **not** proceed to Step 6 until all unit tests pass.

---

### STEP 6 — Code Review, Optimization & Push

#### 6.1 — Code Review & Optimization
Before any commit or push:
- Review all code changes for quality and clarity.
- Remove any unnecessary, unused, or redundant code.
- Confirm Kibana log statements are in place for all error and exception paths.
- **Wait for explicit confirmation from the user before committing or pushing.**

#### 6.2 — Git Safety Check (Mandatory Before Push)
Before syncing or pushing:

1. Run `git status` — review all changed files.
2. Verify `HEAD` is pointing to the **correct current local branch.**
3. Check that the **remote origin matches the current local branch.**
   - If the current branch has **no remote tracking branch** → publish/push the branch to remote first and set remote origin to current branch.
   - If remote origin points to a **different branch** → fix it before proceeding.
4. Only after the above checks pass — commit and push changes.

> 🚫 **NEVER push or merge code into `develop` or `master` — under any circumstances.**
> 🚫 **Never push without explicit user confirmation.**

---

### STEP 7 — Jira QA Comment

Once implementation is pushed to the remote branch:

Add a comment on the related Jira ticket using the template in `dev-customization-expertise.skill.md` (Jira QA Comment template section).

> This comment is the final step. Do **not** skip it.

---

## Intent parsing

- Extract explicit **must-haves** (API, payload fields, UI location, profile gating).
- Detect implied constraints (**minimum change**, reuse existing flow, non-impact behavior).
- Confirm **manual vs scheduler** expectations from the latest user clarification.

## Node discovery process (Step 1 reference)

When evaluating existing customization nodes:

1. **Search by feature area** in `CustomizationConstant.cs` using keywords:
   - Feature name (e.g., `SHIPTIME`, `PROFITABILITY`, `ZIPCODE`)
   - Transaction type (e.g., `INVOICE`, `SALESORDER`, `RECEIPT`)
   - Data source (e.g., `AMAZON`, `SHOPIFY`, `MAGENTO`)
   - Action type (e.g., `SYNC`, `DOWNLOAD`, `EXPORT`, `REPORT`)

2. **Review node definition** — read name, value, inline comments, note CIM vs FR type.

3. **Trace all references** — find every usage across the codebase, map where the node condition is checked, follow the code path end-to-end.

4. **Evaluate fit:**

| Evaluation | Question to Ask |
|-----------|----------------|
| Full match | Does this node alone fulfill the entire request? |
| Partial match | Does it cover most of the request with minor gaps? |
| Combination | Do two or more nodes together fulfill the request? |
| Nodes + handling | Do existing nodes plus small extra changes fulfill the request? |
| No match | No existing node is relevant — proceed to Step 2 |

### Presenting findings format

```
## Existing Node Analysis — [JIRA-ID]

### Candidate Node(s) Found:
- `NODE_NAME` — [Brief description of what it does]

### How It Addresses the Request:
[Explain clearly how the existing node(s) can fulfill the customer requirement]

### What Is Still Needed (if any):
[List any gaps — extra handling, minor changes, or config adjustments]

### Recommendation:
- [ ] Existing node(s) fully cover the request — no new implementation needed
- [ ] Existing node(s) + minor changes can cover the request
- [ ] No existing solution — proceed to new implementation (Step 2)
```

## Git workflow safety (critical before coding)

**Root cause (UD-32682 + UD-32643 incidents):** When a branch is created from `develop` using `git checkout -b <branch> origin/develop`, git sets the upstream tracking to `origin/develop`. VS Code "Sync Changes" then pushes commits directly to `origin/develop`, bypassing PR review. Bitbucket auto-closes the PR as "MERGED" even though the Merge button was never clicked.

### ⚠️ Critical Rules (Non-Negotiable)

- 🚫 **NEVER push or merge into `develop` or `master`**
- 🚫 **NEVER push without explicit user confirmation**
- ✅ **Always verify git status and remote origin BEFORE pushing**

### Pre-Push Checklist — Run Every Time

Execute these checks in order before any commit or push:

1. **Check Git Status**
   ```powershell
   git status
   ```
   - Review all changed files
   - Confirm only intended files are staged
   - No unexpected changes or untracked files should be included

2. **Verify Current Branch**
   ```powershell
   git branch
   # or
   git rev-parse --abbrev-ref HEAD
   ```
   - Confirm `HEAD` is pointing to the **correct current local branch**

3. **Check Remote Tracking Branch**
   ```powershell
   git branch -vv
   ```
   - Confirm remote origin is set to the **same branch as current local branch**
   - Remote should show: `[origin/<current-branch-name>]`
   - 🔴 Danger: `[origin/develop]` — **do NOT sync**

### Prevention — immediately after every new feature branch push

```powershell
git push -u origin <current-branch-name>
```

### Scenarios & Resolutions

| Scenario | Action |
|----------|--------|
| **Remote branch exists & matches** ✅ | Safe to proceed. Commit and push normally |
| **No remote tracking branch set** | `git push --set-upstream origin <current-branch-name>` |
| **Remote origin points to different branch** ⚠️ | `git branch --unset-upstream` then `git push --set-upstream origin <current-branch-name>` |
| **HEAD is detached or misaligned** ⚠️ | `git checkout <correct-branch-name>` then re-run checklist |

### Commit Message Convention

Always reference the Jira ticket ID:
```
UD-XXXXX: [Clear, concise description of what was implemented]
```

### After Push — Confirm

After pushing, verify the remote branch received the changes:
```powershell
git log origin/<branch-name> --oneline -5
```
Confirm the latest commit appears on the remote branch. Report push status before proceeding to Step 7 (Jira comment).

## Implementation pattern

- Add or extend **constants and enums** only when required by the existing flow.
- Wire **UI control visibility** to customization node + `profileID`.
- Keep **button / manual actions** in existing user control/controller paths.
- **Reuse** existing sync endpoint and **DTO contract**.
- Restrict request item list to **existing mapped/matched** item logic.

## Safety pattern

- **Preserve** original state values after temporary overrides.
- **Avoid global side effects** when setting sync mode or filters.
- Return **informative user messages** for empty-result sync operations.

## Observability pattern

- Log **start/end** with profile id and total records.
- Log **skip reasons** (no mapped/matched items, missing data).
- Log and **bubble exceptions** with context.

## Null vs zero discipline

When a customization syncs a **nullable field** from QBD to an online store:

1. **Distinguish absent from zero** at the download level — assign `Nothing` / `null` when the SDK property is absent.
2. **Persist null** through the DAL — use `DBNull.Value` or `NULL` in SQL, not `"0"`.
3. **Exclude null items** from the sync payload — do not send a default value; skip them entirely.
4. **Audit DTO type changes** across all consumers before committing — especially NetSuite, POS, Canada/Australia VB files, and DAL insert/update paths.

---

## PR Comment Review and Replies Workflow

When responding to bot review comments on a Bitbucket PR, follow this workflow for consistent, clean threaded replies:

### ✅ Use Bitbucket MCP API (NOT Browser UI)

**Why:** Browser-based manual comment management is unreliable:
- Authentication tokens expire during manual interaction
- Multiple comment posts/retries create duplicates
- Comment threading gets inconsistent
- Cannot programmatically verify/clean up

**How:** Always use MCP Bitbucket API tools for comment operations.

### ✅ Authenticate Correctly

When using Bitbucket REST API directly (for operations MCP doesn't cover, like thread deletion):

```powershell
# ❌ WRONG — x-token-auth only works with HTTP Access Token
$base64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("x-token-auth:${token}"))

# ✅ CORRECT — username:token (token is HTTP Access Token, not Atlassian API token)
$base64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${username}:${token}"))
```

**Important:** `BITBUCKET_PASSWORD` must be an **HTTP Access Token** (created from Bitbucket repository settings → Access tokens), NOT an Atlassian API token from `id.atlassian.com`.

### ✅ Threaded Reply API Format

When posting a threaded reply to a bot comment using Bitbucket REST API:

```json
POST /2.0/repositories/{workspace}/{repo}/pullrequests/{pr_id}/comments
{
  "content": {
    "raw": "Your reply text here"
  },
  "parent": {
    "id": <bot_comment_id>
  }
}
```

**Critical Details:**
- `content.raw` only — do NOT include `markup` field
- `parent.id` must be the numeric ID of the bot's review comment
- If `markup` is present → returns 400 Bad Request with "extra keys not allowed"
- If `content` is a string instead of object → returns 400 with "expected a dictionary"

### ✅ 1:1 Comment Mapping (No Duplicates)

**Standard structure for code review responses:**
- 1 bot review comment = 1 threaded reply
- Each reply is a direct child of that bot comment
- No branching or nested threads within a reply thread

**Cleanup protocol if duplicates exist:**

1. **Fetch all PR comments** via MCP: `getPullRequestComments(all=true)`
2. **Identify duplicates** — look for:
   - Multiple replies with same `parent.id` (same bot comment)
   - Stray standalone comments (not threaded, or orphaned threads)
   - Comments marked `deleted: true` in the API response (still appear in fetch, but are hidden in UI)
3. **Delete systematically** — via REST API `DELETE /comments/{comment_id}`
   - Status 204 (No Content) = success
   - Takes 1-2 seconds to propagate to next API fetch
   - Deleted comments appear in subsequent fetches with `deleted: true`
   - Use `Invoke-WebRequest -SkipHttpErrorCheck` to handle all status codes

4. **Verify clean state** — re-fetch comments and confirm:
   - Only 3 bot comments exist (from reviewer, not deleted)
   - Exactly 3 threaded replies exist (one per bot comment)
   - All non-active replies have `deleted: true`

### ✅ Typical Workflow Steps

1. Fetch all PR comments
   ```powershell
   mcp_bitbucket-mcp_getPullRequestComments(all=true, pull_request_id=<pr_id>, ...)
   ```

2. Parse structure (separate bot comments from replies)
   ```powershell
   $botComments = $json | Where-Object { $_.user.display_name -eq "ReviewerName" }
   $replies = $json | Where-Object { $_.parent -ne $null }
   ```

3. For each bot comment, post exactly one threaded reply
   ```powershell
   $body = @{
     content = @{ raw = "Your response text" }
     parent = @{ id = $botCommentId }
   } | ConvertTo-Json -Depth 3
   
   Invoke-RestMethod -Uri $url -Method POST -Headers $headers -Body $body
   ```

4. Clean up any stray/duplicate replies
   ```powershell
   Invoke-WebRequest -Uri $url -Method DELETE -Headers $headers -SkipHttpErrorCheck
   ```

5. Final verification — re-fetch and confirm 1:1 mapping

### ⚠️ Common Pitfalls

| Pitfall | Solution |
|---------|----------|
| **Token expires during manual UI work** | Use MCP/API automation from the start — no manual browser comments |
| **Multiple replies on same bot comment** | Audit and delete duplicates; re-post single clean reply via API |
| **Comments not deleted despite 204 response** | 204 means success; check `deleted: true` in next fetch; may take 2-3 seconds to appear |
| **Stray standalone comments** | These are not threaded (no `parent` field); identify and delete via REST API |
| **Mixed auth schemes (x-token-auth vs username:token)** | Always use `username:token` with HTTP Access Token; x-token-auth may fail with "must be used with an atlassian registered email" |
| **Forgotten to verify final state** | Always re-fetch comments after cleanup to confirm exactly 3 active replies (1 per bot comment) |
