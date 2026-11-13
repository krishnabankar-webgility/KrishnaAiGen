# Slack auto-reply: full procedure (v2.1, KrishnaAiGen app only)

This system answers Slack **1:1 DMs** sent to Krishna (U08FTS2SRAP) when he hasn't replied for 30 minutes.
Until Krishna says `live`, **nothing is sent to anyone**: every reply is only *proposed* in #my-daily-update, and he
delivers it with one word. Once live, it sends **one** clearly labelled reply per conversation episode and posts a summary.
Everything runs through Krishna's own **KrishnaAiGen** Slack app. There is no other Slack app, and the claude.ai
connector is only a documented fallback (§12).

This file is in a **public** GitHub repo. It holds generic procedure only. People, DM text, state and logs
live in the private store (§3.3).

---

## §1 Scope

| In scope (v1) | Out of scope (v1, later on Krishna's say-so) |
|---|---|
| 1:1 DMs from humans, day and night | Group DMs, Slack Connect / external users, bots and apps (Claude app, KrishnaAiGen, Slackbot, Jira, Calendar, HubSpot) |
| Krishna's commands in #my-daily-update threads (§8) | **Channel @mentions**: designed, not built. A mention will wait 60 min (`channel_due_minutes`) and stay off (`channel_mentions_enabled=false`) until Krishna says so |

---

## §2 Hard rules

1. **Always disclose.** Every AI-written message starts with the fixed label line
   `🤖 *KrishnaAiGen* · Krishna's AI assistant · auto-reply` (wording chosen by Krishna, 2026-11-05: bot icon plus the app name).
   The script adds it; it is never translated or dropped. Anthropic's usage policy forbids passing AI text off as a
   real person's own words. Exempt: Krishna's own `send: <text>` and `correct: <text>` words (§8).
2. **Never commit Krishna to anything:** no ETA, estimate, story points, priority, release scope, "will do",
   "done", accepting a call or meeting, PR approval or merge, sharing an installer or build.
3. **Never take a position** in a design, code, ownership, blame or product discussion.
4. **Never answer a wd-context question or bug DM** (`[wd-context]` / `/wd-answer`). The script skips those
   messages, because a DM reply there is recorded as Krishna's real answer.
5. **Never reveal private things:** credentials, env values, personal phone number, leave reason, HR or
   performance topics, meeting details, customer data. Don't relay what Krishna said in **other** private
   conversations. The only evidence allowed is what §5 lists.
6. **One auto-message per episode** (§4.2). Never treat a message with the `_ref AR-…_` marker as Krishna's own.
7. **If unsure, downgrade:** ANSWER → CONDITIONAL → REFERENCES → AWAY_ONLY.
8. **PM, EM and anyone more senior get the away note only** (Krishna, 2026-11-05, "for some days"). See §7.

Hard rules 1, 4, 6 and 8, the safety checks and the per-person policy are **enforced by the script**, not just
asked of the reasoner.

---

## §3 How it runs

### §3.1 Components
| Part | Does |
|---|---|
| `scripts/slack-auto-reply/Invoke-SlackAutoReply.ps1` | Every Slack, Jira and state step: find DMs, build timelines, decide what's due, build the evidence pack, call the reasoner, validate, send or propose, summarise, run commands, alert |
| Reasoner: one `claude -p` call per due DM | Reads this file (§2, §5–§7), `persona.md`, `exceptions.md` and `evidence.json`, and returns the §6.4 JSON. **Sandboxed:** `--tools Read`, `--strict-mcp-config` with an empty config (so no MCP servers and no connectors), `--permission-mode dontAsk`, and secret files denied. It **cannot** send, post or write anything |
| KrishnaAiGen **user token** `SLACK_USER_TOKEN` (xoxp) | Acts as Krishna: `search.messages`, `conversations.history/replies`, `users.info`, `users.profile.get`, `chat.getPermalink`, and `chat.postMessage` to the DM (`reply_identity=user`) |
| KrishnaAiGen **bot token** `SLACK_BOT_TOKEN` (xoxb) | AR-STATE, summaries, command threads and acknowledgements in #my-daily-update, alert DMs to Krishna, and replies when `reply_identity=bot` |
| `JIRA_EMAIL` / `JIRA_API_TOKEN` | Ticket facts in the evidence pack |

`-Init`, `-Status`, `-Pause`, `-Resume`, `-Mode`, `-Answers` and `-Away` need only the bot token, so the control side can be set up before the user token exists.

### §3.2 Runners
| Runner | Trigger | Notes |
|---|---|---|
| `local` | Windows Task Scheduler every 15 min (`Register-SlackAutoReplyTask.ps1`) | Primary. A DM is considered 30–45 min after it was sent (day and night) |
| `vm` | Same script with `-Runner vm` | Stands by while `local` has a heartbeat younger than 30 min. **Only on a VM nobody else logs into**, because the user token acts as Krishna |
| `interactive` | Krishna asks in a Claude Code session (`/slack-autoreply …`) | The agent runs the script (`-Status`, `-Shadow`, one cycle, `-Pause`/`-Resume`/`-Mode`/`-Answers`/`-Away`) |
| cloud | Deferred | Would need the tokens as cloud secrets and a non-PowerShell port. Not built |

**Cost:** reading Slack is plain API calls and costs nothing, so polling every 15 min is free. Claude runs **only when a DM is due**
(at most 5 per cycle), about 55k tokens of startup context each. A quiet cycle never starts Claude. The PC must be on and logged in; with it off, nothing runs.

### §3.2a AR-STATE (switchboard message in #my-daily-update, posted once by `-Init`)
`AR-STATE v2 | mode_away=shadow | mode_answer=shadow | paused=no | heartbeat=<unix> | runner=local`

| Key | Values | Meaning |
|---|---|---|
| `mode_away` | `live` / `shadow` | `live`: the away note is sent. `shadow`: it is only proposed |
| `mode_answer` | `live` / `shadow` | `live`: an answer goes out with the away note. `shadow`: it is only proposed |
| `paused` | `no` / `yes` / `until=<unix>` | Kill switch. Commands still work while paused, including `resume` |

A missing or unreadable key counts as `shadow`: it fails safe. **Default rollout (Krishna, 2026-11-05): both `shadow` ("proposal mode") for a few days.**
Krishna replies `live` under AR-STATE when he trusts the proposals (`answers live` / `away live` switch them one at a time; `shadow` goes back).

### §3.3 Private store: `%USERPROFILE%\.claude\slack-auto-reply\` (never in git)
`config.json`, `state.json` (episodes handled, pending proposals, command ledger, mutes, user cache), `persona.md`, `exceptions.md`,
`agent-settings.json`, `empty-mcp.json`, `logs\` (14 days), `runs\<time>_<dm>\` (evidence.json, stdout.json and stderr.txt per reasoner call, 14 days).

`config.json` keys (all optional except the first three; defaults in brackets): `state_message_ts`, `claude_path`, `wd_context_dir`, `unify_repo`,
`dm_due_minutes` (30), `repropose_after_minutes` (120), `reply_identity` (`user`; `bot` sends from the KrishnaAiGen app in its own DM instead),
`leadership_title_regex` (§7), `work_start_ist` / `work_end_ist` (10:30 / 22:30, only used to word the away reason),
`max_claude_calls_per_cycle` (5), `max_turns` (25), `model`, and reserved for channels: `channel_mentions_enabled` (false), `channel_due_minutes` (60).

---

## §4 What counts as "unanswered" (enforced by the script)

### §4.1 Discover
`search.messages` with `query="is:dm after:<today−2d>"` (up to 5 pages) finds DM channels that have partner messages, and the DMs listed in
`persona.md` are always added, so a DM is still found if search is unavailable (Slack calls `search:read` a legacy scope).
Each DM's **timeline** is then built from `conversations.history` (last 48 h) plus `conversations.replies` for every thread.
Search is used only to find channels; decisions always come from the timeline. One DM failing is logged and does not stop the others.

### §4.2 Episode
- **Genuine Krishna message**: authored by U08FTS2SRAP and **without** the `_ref AR-…_` marker.
- **Episode**: the partner's messages after Krishna's last genuine message. Its key is `AR-<DM id>-<ts of the first partner message>`.
- **Closed**: something was actually sent for it (the marker is in the DM, and `sent_ts` is in state), **or** a huddle happened in the DM.
  Nothing more is sent until Krishna writes himself.
- **A proposal does not close the episode.** New partner messages re-propose at most every `repropose_after_minutes` (120).
- **SILENT does not use up the episode.** If a new partner message arrives later, the episode is evaluated again, except for `never`/muted people (one summary per episode).

### §4.3 Due
The first non-wd-context partner message is ≥ `dm_due_minutes` (30) old, **and** the partner has been quiet for ≥ 5 min (they may still be typing).
At most `max_claude_calls_per_cycle` (5) reasoner calls per cycle; the rest wait for the next cycle.

### §4.4 Decided by the script without the reasoner
- Only wd-context messages in the episode → SILENT ("answer it with /wd-answer").
- The person is muted, or their policy is `never` → SILENT (summary says "private / no-reply person", with no quote).

### §4.5 Final guard
Right before sending, the script re-reads the timeline. If Krishna has replied in the meantime, it aborts.
The same check protects `send` (§8).

---

## §5 Evidence (what the reasoner may use)

| Source | How it reaches the reasoner |
|---|---|
| The DM itself: last 30 messages, with `in_episode` and `thread_reply` flags | `evidence.json` → `conversation` |
| Partner identity: name, Slack title, `persona_policy` | `evidence.json` → `partner`, plus `persona.md` |
| Jira facts for every `UD-n` mentioned (summary, type, status, assignee, fix versions, updated) | `evidence.json` → `facts.jira` (live REST) |
| unify-enterprise branches that mention those keys | `facts.branches_as_of_last_fetch` (local refs, fetched every 6 h) |
| wd-context ticket summary (`tickets/<UD>/index.md`, first 4000 chars) | `facts.wd_context`; the reasoner may also Read under `wd-context/tickets/` |
| Lasting product knowledge (customization nodes, module rules) | The reasoner may Read `unify-enterprise/memories/` (working-tree copy) |
| Krishna's away reason and the current modes | `evidence.json` → `away_reason`, `mode_away`, `mode_answer`; the reason is computed by the script from his Slack status and working hours (10:30–22:30 IST) |

**Deliberately not used:**
- `Reference/` folders and DBs, Kibana and CIS: customer data.
- Personal memory: mixes in HR and personal notes.
- Krishna's DMs with other people: §2.5.
- Gmail and HubSpot: customer and personal mail.

**Allowed by Krishna but not wired in yet:** the history of #my-daily-update (his personal channel; today only his command replies are read from it).

Ask Krishna before adding any other source.

---

## §6 The reasoner's job

### §6.1 Reply types
| Type | When |
|---|---|
| `ANSWER` | The category allows it (§7), a fact in the evidence states the answer directly, nothing conflicts, and it isn't a §2 case. Cite the source |
| `CONDITIONAL` | The evidence mostly answers it, but it depends on something unknown. "As per <source>, X. If <condition>, Y. Krishna will confirm." |
| `REFERENCES` | Only related material: 1–3 links, saying it may not fully answer |
| `AWAY_ONLY` | Nothing reliable, or a Krishna-only topic (§7). This includes image- or file-only messages ("I can't see the attachment"). **Exception:** if `exceptions.md` has Krishna's standing line for this situation, put that line in `body` |
| `SILENT` | No question at all (FYI, thanks, "ok"), or HR or personal. Nothing is sent |

### §6.2 Writing the body (the script adds the label, away line, closing and marker)
- 1–3 short lines, under 600 characters. No greeting inside the body.
- Mirror the asker's language. If they wrote in Roman Hinglish, write clean, polite Roman Hinglish (no
  SMS shorthand such as "h", "m", "ky"); otherwise use English. Professional and warm, no emojis.
- Links only to webgility.atlassian.net, bitbucket.org/webgility, webgility.slack.com or Krishna's GitHub.
  Anything else fails the script's safety check, and the reply becomes AWAY_ONLY.
- Never include tokens, passwords, phone numbers or `AR-` text.

### §6.3 Greeting
A short address line such as "Hi Alex bhai," or "Hello Priya,", using the honorific `persona.md` gives (sir, mam, bhai).
40 characters at most, plain text.

### §6.4 Output: only this JSON object, nothing else
```json
{
  "category": "<§7 category>",
  "type": "ANSWER|CONDITIONAL|REFERENCES|AWAY_ONLY|SILENT",
  "greeting": "Hi Alex bhai,",
  "body": "<the answer lines (or the standing line for AWAY_ONLY), or empty>",
  "asked": "<one-line neutral paraphrase of what they asked, ≤120 chars, no secrets, no customer names>",
  "evidence": ["Jira UD-33832: In Progress (https://webgility.atlassian.net/browse/UD-33832)"],
  "proposed_rule": "<optional: a rule you think Krishna should teach, or empty>"
}
```

### §6.5 What the script does with the decision (by AR-STATE mode)
The full message is: label line, `<greeting> Krishna is <away reason>.`, the body, the closing line, and the `_ref` marker.
An *answer* is a body on ANSWER, CONDITIONAL or REFERENCES. A *standing line* is the body of an AWAY_ONLY reply: it is Krishna's own text, so it travels with the away note and is not held back as an answer.

| `mode_away` | `mode_answer` | A reply with an answer | An away note only (with or without a standing line) |
|---|---|---|---|
| `shadow` | `shadow` | Proposed in the summary, nothing sent | Proposed, nothing sent |
| `live` | `shadow` | Away note sent; the answer is proposed as a follow-up | Sent |
| `shadow` | `live` | Full message sent | Proposed, nothing sent |
| `live` | `live` | Full message sent | Sent |

Krishna delivers a proposal with `send` (§8). `reply_identity=user` posts in the DM as Krishna (the label line says it is the assistant);
`bot` posts from the KrishnaAiGen app in its own DM with the person.

---

## §7 Policy by category (from analysis of Krishna's real DM traffic)

| Category | Policy |
|---|---|
| Call or availability ping: "call?", "join", meet/zoom/discord link, "ping me", a bare "Hi" | AWAY_ONLY |
| Design or code debate | AWAY_ONLY (at most REFERENCES to Krishna's own written analysis in the vault) |
| Status / "did you look at X" | CONDITIONAL with recorded facts only ("UD-x is In Progress in Jira"). **Never an ETA** |
| PR review / approve / merge | AWAY_ONLY |
| Factual lookup: which node, which branch, which build or PR, fix version, Jira link | ANSWER when the evidence states it exactly. Otherwise CONDITIONAL or REFERENCES |
| Customer escalation / join the customer call | AWAY_ONLY. Plus, if `exceptions.md` has Krishna's standing line for it, use that line as the body |
| Tooling / setup how-to | REFERENCES to the doc (never token or env values) |
| Estimates, story points, release scope, priority | AWAY_ONLY |
| FYI / thanks / "ok" | SILENT |
| HR, personal, social | SILENT. "Are you on leave?" → AWAY_ONLY |
| Customer-data requests, running Krishna's tools for someone | AWAY_ONLY |

**Per-person policy** (in `persona.md`, enforced by the script after the reasoner):
- `answers-ok`: the table above applies.
- `references-ok`: ANSWER and CONDITIONAL are cut to REFERENCES.
- `away-only`: always AWAY_ONLY, with the bare away note (no body, not even a standing line).
- `never`: always SILENT.

**Leadership rule (Krishna, 2026-11-05, for some days):** PM, EM and anyone more senior are `away-only`. The script also applies it by Slack
title to people who are not listed, or are listed as `answers-ok`/`references-ok`: a title matching `leadership_title_regex`
(default: director, vice president, VP/SVP/AVP, head of, chief, CEO/CTO/CFO/COO/CIO, president, founder, owner, general manager, manager) becomes `away-only`.
A person can only be made *more* restricted this way, never less.

Rules in `exceptions.md` (newest at the bottom; a later rule wins) override the table.

---

## §8 Krishna's commands

Krishna replies in a thread in #my-daily-update. The script acts only on messages that are:
- from U08FTS2SRAP;
- not from a bot;
- without the "Sent using" footer;
- not already in its command ledger, which is written **before** acting, so a command never runs twice.

Each command is acknowledged with ✅. Summaries accept commands for 48 hours.

| Thread | Command | Effect |
|---|---|---|
| A summary | `send` | Deliver the proposal (the exact text shown). Refused if Krishna has written in that DM since, or the proposal is over 12 hours old |
| | `send!` | Same, ignoring those two checks |
| | `send: <text>` | Send your text exactly as written (your words, no label) |
| | `correct: <text>` | Send "Correction from Krishna: <text>" |
| | `learn: <rule>` | Append the rule to `exceptions.md` |
| | `mute` / `mute 3d` / `unmute` | No replies to that person (forever or for N days), or undo that |
| | `ok` / `skip` | Acknowledge only |
| AR-STATE | `live` / `shadow` | Switch **both** modes (`go live`, `all live`, `responses live`, `proposals` also work) |
| | `answers live\|shadow` / `away live\|shadow` | Switch one mode |
| | `pause` / `pause 4h` / `resume` | Kill switch |

The reasoner's `proposed_rule` is only **shown** in the summary. It becomes a rule only when Krishna replies `learn: …`.

---

## §9 Summary format (bot, in #my-daily-update)

#my-daily-update is Krishna's **personal channel** (his word, 2026-11-05: no need for it to be private). A summary therefore holds:
a headline (`sent`, `proposal, nothing sent`, or `away note sent, answer proposed`), the person's name (no @-mention) and time, where
(the DM, with a link), **their message quoted** (up to 400 characters; credentials, long numbers and email addresses masked), a one-line
paraphrase, the type, the text that was sent, the proposed text, the evidence and a suggested rule. **SILENT summaries never quote** (people who are `never`
or muted, wd-context DMs, and DMs the reasoner calls SILENT because they are personal, HR or FYI): they show only the reason or a neutral paraphrase.
The summary text is stored with the episode and re-posted next cycle if Slack failed, so nothing is lost.

---

## §10 Learnings locked in
| Item | Value |
|---|---|
| Krishna | `U08FTS2SRAP`, Asia/Kolkata, active about 10:30–22:30 IST; the auto-reply runs day and night |
| Summary channel | #my-daily-update `C0B0CBW8G03` (personal use; the bot is a member) |
| Skip users | `U0AFJGQSR8X` (Claude app), `U0APDD2PYRX` (KrishnaAiGen bot), `USLACKBOT` |
| Workspace | Webgility `T7XA2G1MW`, a single workspace (no Enterprise Grid org), so only a workspace owner or app manager can approve apps |
| User token scopes needed | `im:history`, `im:read`, `users:read`, `users.profile:read`, `chat:write`, `search:read`. None is admin-gated. `search:read` is the one that unlocks `search.messages`; the granular `search:read.*` scopes only unlock Slack's AI search and need per-user consent, so they do not substitute |
| Scopes that need an org owner | The 26 `admin.*` scopes and `auditlogs:read`, Enterprise Grid only. Never add them |
| Bot token scopes used | `chat:write`, `channels:history`, `im:write` (already present) |
| Rate limits | Slack's 2025 limits on `conversations.history`/`replies` (1 request/min, 15 messages) apply only to commercially distributed non-Marketplace apps. An internal app like KrishnaAiGen keeps the normal limits |
| Headless sandbox | `--tools Read` + `--strict-mcp-config --mcp-config <empty>` removes MCP **and** claude.ai connectors (verified 2026-11-05, v2.1.221) |
| Base cost | Every `claude -p` run loads ~55k tokens of startup context, so the script calls Claude only for due DMs |
| `--agent <plugin agent>` | Not used headless. The reasoner prompt points at this file directly |
| Tests | An offline harness (a fake Slack API plus a canned reasoner) ran the whole cycle on 2026-11-05: proposals, `send`/`send!`, live, pause, failures, identity switch, search fallback |

## §11 Exceptions (generic only; per-person rules go in the private `exceptions.md`)
- A DM whose only content is a meet, zoom or discord link counts as a call ping → AWAY_ONLY.
- Krishna's standing line for a situation (for example night support on escalations) is allowed as the body of an AWAY_ONLY reply, except for `away-only` people.

## §12 Fallback: the claude.ai connector (only if the user token cannot be had)
Use it only if the workspace will not approve the user scopes. Not built.
- The bot token alone still gives AR-STATE, summaries, command threads, alerts and bot-identity replies (`reply_identity=bot`). It cannot read Krishna's DMs.
- Reading DMs would then need a scheduled `claude -p` session with the Slack connector. Every poll is a Claude run (about 55k tokens), so it would poll hourly in working hours, not every 15 min.
- Sending as Krishna through the connector would have to be gated by a PreToolUse hook that allows only the exact approved text to the exact DM, so a crafted DM can't steer it.
