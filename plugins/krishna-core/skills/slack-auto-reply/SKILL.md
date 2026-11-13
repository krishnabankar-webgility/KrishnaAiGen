---
name: slack-auto-reply
description: "Use when: Krishna's Slack DM auto-reply on his behalf - its status, a dry run or a real cycle ('check my DMs', '/slack-autoreply'), pausing or resuming it, switching it live ('go live', 'answers live') or back to proposal mode, explaining what it replied or proposed and why, tuning its persona or rules, its send/send!/correct:/learn:/mute commands in #my-daily-update, Slack scope or admin-approval questions for the KrishnaAiGen app, or setting up its runner (local PC or VM, KrishnaAiGen Slack app tokens)."
---

# Slack auto-reply (on Krishna's behalf)

When someone DMs Krishna and he hasn't replied for 30 minutes, a script running on his machine reads the DM with his
**KrishnaAiGen** app's user token. It builds an evidence pack (the conversation, who the person is, Jira and vault
facts) and asks a sandboxed Claude reasoner what to say: a sourced answer only when certain, otherwise a conditional
answer, references, or "he's away, your ask is noted".
**Until Krishna says `live`, nothing is sent to anyone:** each reply is proposed in #my-daily-update and he delivers it by
replying `send`. Once live it sends **one** clearly labelled reply per conversation. Either way, every action is summarised
in #my-daily-update, where Krishna steers it by replying in the thread.

**Read `reference.md` before taking any action.** This file is a map.

| § | In reference.md |
|---|---|
| §1 | Scope: 1:1 DMs day and night; channel mentions designed, not built |
| §2 | **Hard rules**: label line, no commitments, no wd-context answers, no private data, one message per episode, leadership gets the away note only |
| §3 | Components, runners, cost, AR-STATE modes (live / shadow), private store and config keys |
| §4 | What counts as "unanswered": episodes, 30-min due rule, proposals vs sent, final guard |
| §5 | Evidence the reasoner gets, and what is deliberately left out |
| §6 | Reasoner output: reply types, writing rules, the JSON contract, and what the script does per mode (§6.5) |
| §7 | Policy by DM category and per-person policy, including the leadership rule |
| §8 | Krishna's commands |
| §9 | Summary format |
| §10 | Learnings locked in (IDs, Slack scopes and approval facts, sandbox flags, cost) |
| §11 | Exceptions and standing lines |
| §12 | Fallback: the claude.ai connector (not built) |

Runner: `KrishnaAiGen/scripts/slack-auto-reply/Invoke-SlackAutoReply.ps1`. Setup: `plugins/krishna-core/docs/setup-slack-auto-reply.md`
(including what to do when Slack blocks the reinstall). Operator agent: `slack-auto-responder` (`/slack-autoreply`).

**Privacy:** this repo is public. People, DM text, state and logs live only in `%USERPROFILE%\.claude\slack-auto-reply\`.
