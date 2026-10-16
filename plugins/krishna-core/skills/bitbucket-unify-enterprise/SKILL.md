---
name: bitbucket-unify-enterprise
description: "Use when: working with the unify-enterprise repo on Bitbucket - cloning, setting an authenticated remote URL, pushing a branch, creating or reviewing a pull request, BITBUCKET_PASSWORD / HTTP access token setup, x-token-auth scheme, or 'bitbucket auth failed'. Covers git-over-HTTPS plus the Bitbucket MCP server."
---

# Skill: Bitbucket — `unify-enterprise` (Cloud Agent)

## Purpose

Use **Git over HTTPS** plus optional **Bitbucket MCP** so a Cursor Cloud Agent can work on `webgility/unify-enterprise` similarly to desktop Cursor: clone/read/analyze code, run tests, commit, push branches, and handle PRs (create draft PR, review via diff, comment when MCP is available).

## Secrets

Set in `C:\WG-Agentic\wg-ai-workspace\.env` (see `setup-bitbucket.md`), read by the local
`bitbucket` MCP server and by these git-over-HTTPS commands alike — not a Cursor Cloud Agent
secret store, that framing is historical:

| Variable | Role |
|----------|------|
| `BITBUCKET_USERNAME` | Bitbucket **account username** (slug), e.g. `krishnabankar` — **not** an email address (`@` breaks URL parsing). |
| `BITBUCKET_PASSWORD` | **Bitbucket HTTP access token** (repository/workspace scoped). **Not** an Atlassian `id.atlassian.com` API token (those are for Jira/Confluence only). Minimum scopes: **Repositories: Read**; add **Write** to push branches. |

If only `BITBUCKET_PASSWORD` is set, **`x-token-auth`** as the username may work (see `AGENTS.md`). Prefer **username + token** when both are configured.

## Repository

| Item | Value |
|------|--------|
| Workspace | `webgility` |
| Repo slug | `unify-enterprise` |
| HTTPS clone URL | `https://bitbucket.org/webgility/unify-enterprise.git` |

## One-time remote URL (authenticated)

Before `git fetch` / `git pull` / `git push` against Bitbucket, set the remote URL so Git embeds credentials (Cloud Agent shell):

**Bash (encode token if it contains reserved URL characters):**

```bash
export BB_USER="${BITBUCKET_USERNAME}"
export BB_PASS_ENC="$(python3 -c "import os,urllib.parse; print(urllib.parse.quote(os.environ['BITBUCKET_PASSWORD'], safe=''))")"
git remote set-url bitbucket "https://${BB_USER}:${BB_PASS_ENC}@bitbucket.org/webgility/unify-enterprise.git"
```

**PowerShell:**

```powershell
$enc = [uri]::EscapeDataString($env:BITBUCKET_PASSWORD)
git remote set-url bitbucket "https://$($env:BITBUCKET_USERNAME):$enc@bitbucket.org/webgility/unify-enterprise.git"
```

If the remote is not named `bitbucket`, use `origin` or add:  
`git remote add bitbucket https://bitbucket.org/webgility/unify-enterprise.git` then `set-url` as above.

## Clone (fresh workspace)

```bash
git clone "https://${BITBUCKET_USERNAME}:$(python3 -c "import os,urllib.parse; print(urllib.parse.quote(os.environ['BITBUCKET_PASSWORD'], safe=''))")@bitbucket.org/webgility/unify-enterprise.git" unify-enterprise
cd unify-enterprise
```

Use a **shallow clone** if the repo is large and you only need recent history:

```bash
git clone --depth 1 --branch master "https://..." unify-enterprise
```

## Day-to-day Git (parity with desktop)

| Goal | Command pattern |
|------|-----------------|
| Update local `master` | `git fetch bitbucket master` then `git checkout master && git merge bitbucket/master` (or `git pull bitbucket master`) |
| Feature branch | `git checkout -b feature/your-topic` |
| Commit | `git add -A && git commit -m "message"` |
| Push branch | `git push -u bitbucket feature/your-topic` |
| Sync with target branch | `git fetch bitbucket master && git merge bitbucket/master` (resolve conflicts if any) |

Follow safety rules in `git-sync.skill.md` (status before merge, no force-push unless asked).

## .NET / tests (this repo)

The solution layout lives under `Desktop/` (multiple projects). Discover sln/csproj with search or:

```bash
find . -name "*.sln" | head -20
dotnet test path/to/Your.sln
```

Use `dotnet build` / `dotnet test` from the cloned root after `dotnet restore` as needed.

## PRs: Git vs Bitbucket MCP

| Action | Mechanism |
|--------|-----------|
| **Push branch** | Git (after authenticated `set-url`) |
| **Create PR / draft PR** | Bitbucket web UI, or **Bitbucket MCP** tools (`createPullRequest`, `createDraftPullRequest`) if MCP is connected and authenticated |
| **Review PR (diff, comments)** | **Bitbucket MCP**: `getPullRequest`, `getPullRequestDiff`, `getPullRequestComments`, etc. — **requires MCP auth** (401 if secrets only in Cloud Agent but MCP not linked to Bitbucket) |
| **Read full files on a branch** | **Local clone** + read/search tools — MCP alone usually does not expose arbitrary file paths |

Workflow: **push branch with Git → open or draft PR via MCP or UI → review using MCP diff or local `git diff`**.

## Commit/push discipline (mandatory, every time)

- **Never merge code yourself**, and **never commit or push to `develop` or `master`** — always
  the branch currently being worked on. This is absolute, not a default that can be inferred
  away.
- **Validate the branch matches the actual ticket in play before pushing.** If you're working
  UD-XXXXX but the checked-out branch doesn't look like it belongs to that ticket (wrong ticket
  number, or it looks like it was left over from other work), **stop and get clarity first** —
  don't push on a guess. A branch that's merely on a different feature naming convention but
  demonstrably for the same ticket is fine; a mismatch in the actual ticket number is not.
- **Never stage or commit `apiConfig.xml` or `AuthenticationController.cs`.** These are Krishna's
  personal local dev setup, not code changes made as part of the work — always exclude them
  explicitly (`git add` the specific files that are the real change, or `git reset` those two out
  before committing) rather than a blanket `git add -A` that would sweep them in.
- **If `ship-to-qa` is invoked but the code isn't committed yet:** commit the changes to the
  current local branch and push it to its own remote (not `develop`/`master`) before the
  pipeline runs — the build needs the branch to actually have the code on it. Don't ask
  separately; this is expected setup for that pipeline to work at all.

## Unrelated task mid-ticket — isolate with a worktree, never touch the current branch

If Krishna asks for different work that has nothing to do with the ticket the current branch is
checked out for — fresh investigation, analysis, or a code review on another ticket/branch —
do **not** switch or stash on the current branch to do it. Isolate it instead:

1. Fetch the right base fresh: `git fetch origin develop master 101/RightNetwork_Release`
   (whichever of these the new task actually needs — develop is the default assumption unless
   the new ticket's context points at `master` or a specific numbered release branch).
2. Create a worktree off that base with an explicit branch, e.g.
   `git worktree add ../unify-enterprise-<new-ticket> origin/develop -b <new-ticket>_Krishna`
   (swap `origin/develop` for `origin/master` or the release branch as needed). Claude Code's
   own `EnterWorktree` tool does this natively when the base is just the repo's default branch;
   for an explicit non-default base, use `git worktree add` directly as above so the base ref
   is exact, not whatever the tool's default happens to be.
3. Do all the investigation/analysis/code changes for the new task inside that worktree. The
   original working directory and its checked-out branch are untouched for the whole detour.
4. **On completion, clean up** — remove the worktree (and its branch, if it was scratch-only)
   once the work is wrapped up or abandoned: `git worktree remove <path>` (`ExitWorktree` with
   `action: "remove"` if it was opened via `EnterWorktree`). Don't leave stale worktrees
   sitting around after the detour is done.

## After a PR review: don't touch Jira unless asked

Finishing a PR review (diff read, findings reported in chat) is **not** itself a reason to post
anything to the related Jira issue. Default is silence on Jira after a review:

- **Never post a PR-review comment on the Jira issue until Krishna explicitly asks for it.** The
  review findings go in chat; Jira stays untouched unless told otherwise.
- **If the issue's status is already `In Test` / `Ready For Release`** (i.e. past the point where
  review feedback is still actionable pre-handoff), **never post a comment there even if asked
  generically** — flag it to Krishna in chat instead ("issue is already `<status>` — did you
  still want a comment posted, or should this go elsewhere?") and wait for a clear answer rather
  than guessing.
- This is specifically about **PR-review output**. It doesn't change the separate, already-
  mandatory Jira touchpoints elsewhere in this system (the `jira-workflow` §1a pre-code plan
  comment, the §7 QA/RFT comment) — those still happen on their own triggers.

## Reviewing a PR: isolate in a worktree, check existing patterns first, stay terse

When asked to review a Bitbucket PR (not a pre-PR local diff — see `wd-review`/`wd-pr-review` for
that), this is the default shape unless told otherwise:

- **Never check out the PR branch in the current session/branch.** Delegate to a `wd-review`-type
  agent with `isolation: "worktree"` (or an equivalent isolated clone) so the PR's source commit
  gets checked out somewhere that isn't the session's own working tree — the current branch (and
  any uncommitted work on it) stays untouched throughout.
- **Read the whole diff before concluding anything.** Large diffs get saved to a file by the MCP
  tool and truncated in the response — read the saved file in full, chunked if needed. Say so
  explicitly if a diff genuinely couldn't be read in full.
- **Check how the existing codebase already does the same kind of thing before flagging it** —
  grep/read the actual repo (in the isolated worktree), don't review from the diff in isolation.
  If a "finding" just matches a pattern already used elsewhere, it's not a finding — at most a
  non-blocking suggestion.
- **Verify the PR description's own safety claims against the code and tests** — don't take a
  "this is safe because X" comment at face value; find X and confirm it actually holds (or flag
  precisely which part is an assumption, not something provable from the diff — e.g. an
  operational claim about a prod system's config that only the author can confirm).
- **Output stays terse:** file path + line, then 1-3 sentences — what the problem is and what
  could be done. No long write-ups, no restating the diff, no "no issues found" filler for files
  with nothing wrong. Classify every finding as **Suggestion** (safe to ignore, flagged anyway) or
  **Critical**/**needs confirmation** (explain briefly why it matters).
- **Report in chat first; only post to Bitbucket if asked** — same as the Jira rule above. Once
  asked, post the overall verdict + scope notes as one general PR comment and each per-line
  finding as its own inline comment (`path` + `to` line), not one giant comment.

## Troubleshooting

- **401 / authentication failed:** Confirm token is a **Bitbucket HTTP access token** with correct scopes; confirm username is the **slug**, not email; URL-encode the token in the URL.
- **403:** Token may lack **Write** (push) or **Read** (clone) on `unify-enterprise`.
- **MCP 401 on PR tools:** Git secrets do not automatically authenticate the Bitbucket MCP server — complete MCP OAuth/token setup in Cursor for Bitbucket, or use the website for PR actions.

---
> Ported from `.cursor/skill-library/bitbucket-unify-enterprise.skill.md` (canonical Cursor/Copilot copy). Keep both in sync — see the `krishnaaigen-skill-evolution` skill.
