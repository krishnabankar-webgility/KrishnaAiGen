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
