---
name: pr-review
description: "Use when: reviewing a Bitbucket pull request on unify-enterprise (not a pre-PR local diff — see wd-review for that). Triggers: 'review this PR', 'review <bitbucket PR url>', '/pr-review'. Covers worktree isolation, verifying claims against code/tests, terse file+line findings with severity, the short overview comment with counts, and posting rules."
---

# pr-review

Krishna's standing PR-review process, built from direct feedback across PR #10453 and #10454
(2026-10-15/16) and meant to keep improving the same way: every time Krishna gives feedback on how
a review went — a format he wants, something he'd rather I check first, a posting rule — fold it
into this file immediately (per `krishnaaigen-skill-evolution`), don't just apply it once and
forget it. This file **is** the review process, not a summary of it; keep it current rather than
writing a separate "lessons learned" doc elsewhere.

## The process, step by step

1. **Get the PR details and full diff** (`mcp__bitbucket__getPullRequest`, `getPullRequestDiff`,
   `getPullRequestCommits`). Large diffs get saved to a file and truncated in the response — read
   the saved file in full, chunked if needed. **Read 100% of the diff before concluding anything**;
   if it genuinely can't be read in full, say exactly what was missed before giving a verdict.

2. **Isolate in a worktree — never touch the current session's branch or working tree.** Delegate
   to a `wd-core:wd-review` agent (or equivalent) with `isolation: "worktree"`, so the PR's source
   commit gets checked out somewhere separate. If the agent needs the real remote (not just the
   local clone) to fetch a branch, it clones into a scratch subfolder of its own worktree, adds the
   remote, fetches, and deletes the scratch clone when done — the session's own branch and any
   uncommitted work on it stay untouched throughout.

3. **Check how the existing codebase already does the same kind of thing before flagging
   anything.** Read the actual repo in the isolated worktree — don't review the diff in isolation.
   A "finding" that just matches a pattern already used elsewhere isn't a finding — at most a
   non-blocking suggestion, and often not worth mentioning at all.

4. **Verify the PR description's own claims against the code and tests — don't take them at face
   value.** If the description says "this is safe because X," find X and confirm it actually
   holds. If it can't be confirmed from the diff/tests (e.g. an operational claim about a
   production system's config that only the author can verify), say precisely that it's an
   assumption needing the author's confirmation, not a bug.

5. **Specifically scrutinize the highest-consequence failure mode for what this PR touches** —
   named explicitly in the request when there is one (e.g. "a wrong match here silently posts to
   the wrong QuickBooks customer, worse than an order going to Error"). Check test coverage against
   that specific scenario, not just that tests exist and pass.

6. **For a customization PR, scope the node-interaction check to the node(s) the diff actually
   touches.** Identify the new/changed node in `CustomizationConstant.cs` and trace only that
   node's own call sites and what runs immediately around them in the same method. Do not also
   audit every *other* pre-existing node that happens to live in the same method/file unless the
   diff changes it too — that's surface area the PR didn't create and isn't responsible for.
   (Learned from PR #10461: first pass flagged a collision with `UD-17209`'s block without
   checking what gated it; it turned out to sit behind a *different* customer's node
   (`JOHN_00160009`), untouched by this diff — not a real finding, just noise from widening the
   check past the node actually being added.) A genuine "last-writer-wins, no merge logic"
   observation about the *shared function's architecture* is still fine to mention as a one-line
   suggestion — just don't present an unrelated pre-existing node's behavior as a finding against
   the new node without first checking what gates that other node.

## Output format

- **File path + line number, then 1-3 sentences maximum** — what the problem is and what could be
  done. No long write-ups, no restating the diff.
- **No filler.** If nothing is wrong with a file, don't mention it — no "no issues found" per file.
- Classify every real finding as:
  - **Suggestion** — safe to ignore, flagged anyway (cosmetic, deviates slightly from convention).
  - **Critical** / **needs confirmation** — could break, regress, mis-post, or silently drop
    something; or a claim that can't be verified and needs the author to confirm it. Explain why
    briefly.
- End with a short **overall verdict** (safe to merge / needs changes / needs a specific
  confirmation) and a **counts summary** for a quick-glance picture — e.g. "2 critical, 3
  suggestions" — before the itemized list. This goes in both the chat report and, if posting, the
  general PR comment (see below) — Krishna's explicit ask (Prompt 26, 2026-10-16): the overview
  comment should let someone see at a glance whether anything critical needs attention, not require
  reading every inline comment first.

## Posting

**Report in chat first. Only post to Bitbucket if Krishna asks.** Once asked:
- One **general PR comment**: overall verdict + counts summary + any cross-cutting/scope notes
  (e.g. an unrelated change bundled in via a merge mix-up) that don't belong on one specific line.
- One **inline comment per specific finding** (`path` + `to` line), not one giant comment.
- **Comments only — no approve/request-changes** — unless Krishna explicitly asks for that too.

## Specific instructions Krishna has given on past reviews — now standing defaults

These started as one-off asks and are now just how this works, so they don't need restating:
- Don't switch/check out the PR branch in the current session — worktree only (see step 2).
- Terse output: file+line, 1-3 sentences (see Output format above).
- Check existing patterns before flagging (step 3).
- Classify Suggestion vs Critical, most severe first.
- Report in chat first; post only when asked, comments only, not approve/request-changes.
- Add the overview comment with counts (this prompt's addition — fold future format tweaks in here
  the same way).

## Related

- `bitbucket-unify-enterprise` skill — Bitbucket auth, clone, branch/PR mechanics; its own
  "Reviewing a PR" section now just points here.
- `wd-core:wd-review` — the agent actually doing the isolated-worktree read-only review.
- `jira-workflow` §4.1 — the matching "don't post Jira comments unless asked" rule this mirrors.
- Memory: `pr-review-style-worktree-terse.md` — origin story (PR #10453), now superseded as the
  living process by this file.

## Addressing review comments on Krishna's own PR (standing, 2026-11-03)

- Read every comment, verify each finding against the code **and against the agreed design** (the ticket's Prompts.txt / Implementation md), then decide. Fix only a **real, critical** miss (wrong behaviour, data integrity, or a gap against the agreed design). An asymmetry the design chose on purpose is not a miss. On UD-33709 #10485 the bot called manual-vs-scheduler Fulfilment accept a divergence; "fixing" it broke the user's Yes/No undo choice and was reverted in Prompt 16.
- Skip suggestions, style/convention nits, performance remarks on non-hot paths, scope/split remarks, "add tests" notes, and anything that matches how the existing code is already written. No edits for low-risk items: the work is already tested.
- For a high-risk fix: test the impacted area myself (real code path, harness against UnifyDB / QBD sandbox) before reporting; record fixed/skipped + why in the ticket's Implementation plan md. Leave the fix uncommitted unless Krishna asks for commit/push.
- Reviewing **someone else's** PR keeps the format above: each finding as its own inline comment plus one consolidated summary comment.

## Verifying that a teammate's PR carries our work (PR #10497 vs #10485, 2026-11-06)

Used when someone re-raises our changes in their own branch/PR (ours was declined as "merge via the other branch").
The method, in order:

1. **Ancestry first, but it only proves commits, not content.** `git merge-base --is-ancestor <our tip> <their tip>` for every branch of
   ours and every sibling branch they merged. A merge resolution can still drop lines.
2. **Then diff our tip against theirs, restricted to the files our PR touched** (`git diff -U0 -w <ours> <theirs> -- <files of ours>`)
   and read every `-` line: those are lines of ours they removed or rewrote. Added-only hunks are other work.
3. **Check whether "extra" commits are really extra.** A diff between our tip and theirs also shows develop's newer commits. Confirm with
   `git merge-base --is-ancestor <commit> origin/develop` and count files in `develop..theirs` before saying the PR bundles other tickets.
4. **Check path symmetry for any new gate.** UI paths (OrderController, AccountingDashboardHelper) and the scheduler (SchedularProfile.vb)
   post the same orders; confirm a new gate exists on, or is already implied by, all three.

Findings worth reusing:
- **"Generalizing a node" can silently remove other gates.** The UD-33832 branch dropped the `ENABLE_SALESORDER_UPDATE` rollout gate
  (UD-32871 modify-in-place) from `IsSupportCartsModifyTransactionOnUpdate`, so the setting becomes visible to every Shopify profile.
  Not in the PR title. When a PR touches a gate helper, list every node/licence check that disappeared and ask the author to confirm each.
- **A file on our never-commit list can legitimately change in a teammate's PR.** `AuthenticationController.cs` carried
  `SALES_ORDER_FULFILLMENT` (licence flag, real feature). Our local-only edit is the single `LicensingMode = "development"` line; check
  the actual hunk, not the filename, before calling it a leak.
- **A node can be kept as a transition while a licence replaces it.** `IsCreateInvoiceForShippedItemsEnabled` still honours the exact-match
  node, so existing node customers keep working; the licence path is additive. Confirm this before assuming a generalization breaks a customer.
- **PR descriptions built from concatenated commit messages leak internal wording** ("Prompt 16", "review-finding-1", repeated
  Co-Authored-By lines, doubled apostrophes). Suggest a rewritten description; non-descriptive subjects ("UD-33832", "QA agent suggestion")
  are worth a one-line mention.

## Lessons from the PR #10497 review (2026-11-06)

- **A node replaced by a settings-driven default is an upgrade-time behaviour flip.** Size the affected population from the code that
  enables the control today (here `ctrlPayoutSettings`: rule-based profiles already had the payout checkbox enabled), then ask the author
  for a prod query, not just "is there an opt-out node". An opt-out node is only added after the customer notices.
- **Lazily filled static registries hide behind node-based QA.** If a licence/settings path reads a per-process dictionary filled at profile
  load, the exact-match node is checked first and masks it. Anchor the comment on a multi-profile loop or data-layer caller and ask for a
  test on a profile with no node.
- **The PR moves while you review.** Re-fetch the source branch before posting inline comments, then confirm the anchors against the commit
  Bitbucket reports as `src_rev` (`git show <src_rev>:<path> | sed -n <line>p`), and diff the old tip against the new one so the verdict is not stale.
