# Setup: Slack DM auto-reply (KrishnaAiGen app only)

Turns on the DM auto-reply (skill `slack-auto-reply`, runner `scripts/slack-auto-reply/Invoke-SlackAutoReply.ps1`).
This doc is public; personal files live in `%USERPROFILE%\.claude\slack-auto-reply\`.

**Everything starts as a proposal.** Until you reply `live` under the AR-STATE message, nothing is sent to anyone.

## 0. Scopes and admin approval (read this if Slack blocks the reinstall)

**Add exactly these under *User Token Scopes* (Bot Token Scopes need nothing new) and remove any other user scope you added:**

| Scope | Why |
|---|---|
| `im:history` | read your DM conversations |
| `im:read` | list and inspect your DMs |
| `users:read` | the sender's name and title |
| `users.profile:read` | your Slack status, to word "in a meeting" |
| `search:read` | find DMs with new messages. This legacy scope is the one that unlocks `search.messages`. The newer `search:read.*` scopes only unlock Slack's AI search and need consent in the Slack client, so they **do not** replace it |
| `chat:write` | send the reply in the DM. Skip it if you set `reply_identity` to `bot` (below) |
| `channels:history`, `groups:history`, `mpim:history` | read the thread around an @mention in public channels, private channels and group DMs |
| `channels:read`, `groups:read`, `mpim:read` | channel names and whether a channel is private (for @mentions and research hits) |

The first six are enough for DMs only. The last six add @mention scanning and Slack-search research. All are read-only and none needs an admin. Reinstalling the app with more scopes upgrades the **same** `xoxp` token in place (no new token to copy).

Slack adds `identify` by itself. Extra scopes only give an admin more reasons to say no.

**Does any of these need an admin?** No. Per Slack's scope reference, only the 26 `admin.*` scopes and `auditlogs:read` need an
Enterprise Grid org owner, and Webgility is a single workspace (no Grid org), so they can't be used here at all: never add them.

**The real gate is workspace app approval.** If it is switched on, a Workspace Owner or app manager must approve the app's new scopes first
(Slack → *Manage apps* → requests). Then any member, you, finishes the reinstall from the install link. You can tell it is on when the install
page's button says **Request** or **Submit request** instead of **Allow**. Only owners and app managers can see the setting
(workspace name → *Tools & settings* → *Manage apps* → *Settings*).

**If you get an error rather than a Request button:**
1. Check the Slack tab you are signed in to says *Webgility*. Another workspace gives `invalid_team_for_non_distributed_app`.
2. Ask an owner whether KrishnaAiGen is listed under *Restricted* apps.
3. Retry in a few minutes (a transient Slack error), and copy the exact error text if it persists.

**Message for the workspace owner** (paste into a DM):
> Hi, I'm updating my personal Slack app **KrishnaAiGen** (app ID A0ANJRS1EA3, internal to Webgility, only I use it). It needs these user scopes so it can read my own DMs and reply for me while I'm away:
> `im:history, im:read, users:read, users.profile:read, search:read, chat:write`. Please approve them under Manage apps → Requests. The token stays on my PC, and every message it sends is labelled as coming from an AI assistant.
> If you'd rather not allow `chat:write` as me, I can drop it and have replies come from the app itself.

**If `chat:write` is refused:** drop it, set `"reply_identity": "bot"` in `config.json`, and the reply comes from the KrishnaAiGen app in its own DM with the sender.
**If the user scopes are refused altogether:** see the fallback in `reference.md` §12.

### Scopes to add for the thread monitor, live conversations and reactions (Prompt 11)
Checked against the live tokens' granted scopes (`auth.test` response header), not from memory.
| Token | Add | Why |
|---|---|---|
| **Bot** | `reactions:write` | put a reaction on Krishna's reply under a summary once its command was read (the "no reaction" complaint of Prompt 10) |
| **Bot** | `users:read` | resolve names with the bot token alone, so app DMs still work when the user token is down |
| **User** | *nothing required* | the 13 user scopes granted today already cover threads (`search:read` + the `*:history` scopes) and live DMs |
Optional, off by default: `files:read` (bot or user) to read screenshots in a DM. Not added because an attachment is untrusted input and the reasoner has no tool to open it safely; ask before enabling. `im:write` for the **user** token would let it open a DM to someone who never wrote first: not needed by the auto-reply.
**Deliberately not taken from the Shubhi-Agent list:** `chat:write.public` (post in channels it is not in), `channels:join`, `groups:write` (create or manage private channels), `groups:history`/`groups:read` for the **bot** (it is never in private channels). They would let the app write where Krishna's rule is "never post in a channel".
JSON to paste into the app manifest (Slack → app → *App Manifest*; it keeps every scope already granted and adds only the two above): [slack-app-manifest-scopes.json](slack-app-manifest-scopes.json). Then **Reinstall to Workspace**. If app approval is on, see the owner message above and mention the two new bot scopes.
**Later, only when Krishna allows posting in channels (Prompt 12):** [slack-app-manifest-scopes-channel-posting.json](slack-app-manifest-scopes-channel-posting.json) is the same manifest plus the three bot scopes `chat:write.public`, `channels:join`, `groups:write` (bot: 17 → 20). Do **not** paste it yet: posting in a channel is still blocked in the code (thread suggestions are always hold-full), so these scopes would only widen what the app could do. Note that posting **as Krishna** needs none of them (the user token already has `chat:write`); they matter only if the **bot** posts in channels it is not a member of. `groups:write` is the broadest (create and manage private channels); skip it unless a private channel really needs it.

## 1. Slack app (KrishnaAiGen), once
1. api.slack.com → Your Apps → **KrishnaAiGen** → **OAuth & Permissions**.
2. Under **User Token Scopes**, have exactly the scopes in section 0.
3. **Reinstall to Workspace** (`https://api.slack.com/apps/A0ANJRS1EA3/install-on-team`), then **Allow**. If it says Request instead, see section 0.
4. Copy the **User OAuth Token** (`xoxp-…`) into a Windows user env var (don't paste it anywhere else):
   `[Environment]::SetEnvironmentVariable('SLACK_USER_TOKEN', '<xoxp token>', 'User')`
5. Restart VS Code or the terminal. `SLACK_BOT_TOKEN` and `JIRA_EMAIL`/`JIRA_API_TOKEN`/`JIRA_BASE_URL` must also be set (they already are on Krishna's PC).

## 2. Local PC
1. **Initialise:** `pwsh -File C:\WG-Agentic\KrishnaAiGen\scripts\slack-auto-reply\Invoke-SlackAutoReply.ps1 -Init`.
   This needs only the bot token, so you can do it before the user token exists. It posts the AR-STATE message and its control thread in
   #my-daily-update (proposal mode) and writes the private config.
2. **Check the people file:** `%USERPROFILE%\.claude\slack-auto-reply\persona.md` sets each person's honorific and
   policy (`answers-ok` / `references-ok` / `away-only` / `never`). PM, EM and anyone more senior are `away-only`.
3. **Dry run** (needs the user token): `... Invoke-SlackAutoReply.ps1 -Shadow`. It makes no Slack writes and prints what it would do. Check the
   decisions in `%USERPROFILE%\.claude\slack-auto-reply\runs\`.
4. **Schedule it:** `pwsh -File C:\WG-Agentic\KrishnaAiGen\scripts\slack-auto-reply\Register-SlackAutoReplyTask.ps1`.
   It runs every 5 min by default (`-EveryMinutes 2` in phase 1, `15` in phase 2) with no console window, while you're logged on. Reading Slack costs nothing; Claude runs only for a message that has waited its due time (`dm_due_minutes`, `channel_due_minutes`).
5. **Rollout:** for a few days every reply is only a **proposal**. Each due DM gets a summary in #my-daily-update with the person's message, the exact
   reply it would send, and the evidence. Reply `send` under a summary to deliver it (`send!` if it is over 12 hours old, or you have already written
   to that person). `send: your text`, `correct: …`, `learn: …`, `mute 3d` and `ok` also work. When the proposals look right, reply
   **`live`** in the AR-STATE thread (or `answers live` / `away live` one at a time). `shadow` goes back to proposals.
6. **Stop any time:** reply `pause` in the AR-STATE thread, or run `-Pause on`, or
   `Unregister-ScheduledTask 'Slack Auto-Reply' -Confirm:$false`.

Phase 1 polls every 5 minutes (`Register-SlackAutoReplyTask.ps1 -EveryMinutes 5`); for phase 2 re-run it with `-EveryMinutes 15`. Tuning (private `config.json`): `ignore_before_ts` (DMs older than this are ignored), `dm_due_minutes` (15; a hint or away note waits this long and needs him away everywhere, a correct answer goes out at once), `answer_quiet_seconds` (60), `pc_idle_minutes` (10), `live_user_ids` (live replies only for these Slack IDs), `slack_check_enabled`, `repropose_after_minutes` (120), `reply_identity` (`user` or `bot`), `leadership_title_regex`,
`work_start_ist` / `work_end_ist`. Channels and the app: `channel_mentions_enabled` / `channel_due_minutes` (15, always) / `mention_ignore_before_ts` (nothing is ever posted in a channel), `app_dms_enabled` / `app_dm_poll_minutes`. Research (reference §6.6): `research_enabled`, `research_connectors`, `research_effort`, `research_tools`, `max_research_calls_per_cycle` (1), `max_research_per_day` (10). Wrap-ups: `wrapup_quiet_minutes` (180). Absence and code analysis (reference §6.7): `absent_after_minutes` (30), `analysis_enabled`, `analysis_min_score` (3), `analysis_effort`, `max_analysis_per_cycle` (1), `max_analysis_per_day` (10). Presence needs the `users:read` scope, already granted. Threads Krishna started: `thread_monitor_enabled` (true), `thread_quiet_seconds` (120), `max_threads_per_cycle` (30). Live conversations: `convo_enabled` (true), `convo_window_minutes` (180), `convo_quiet_seconds` (15), `convo_poll_seconds` (20), `convo_burst_seconds` (90), `convo_active_minutes` (10). Models: `model`, `reasoner_effort`.

## 3. VM (optional; only a VM nobody else logs into)
The user token acts as you in Slack, so never put it on a shared machine. Steps: install PowerShell 7, git and the Claude Code CLI
(`/login` with your account); clone KrishnaAiGen (wd-context and unify-enterprise are optional, for better answers); copy the
private folder from the PC (including `config.json`, so both share one AR-STATE); set the env vars from section 1; then run
`Register-SlackAutoReplyTask.ps1 -Runner vm`. The VM stands by while the PC runner is alive. With `reply_identity` set to `bot`, run only one runner.

## 4. When the PC is off (no runner)
Cloud is deferred: it would need the tokens as cloud secrets. In the meantime:
- Replies still work from your phone. Reply in a summary thread (`send`, `send: …`) and the command runs on the next cycle while a runner is up.
- **claude.ai app** (web or phone) has the Slack, Jira and Confluence connectors for ad-hoc questions. A private claude.ai
  Project with a copy of `persona.md` gives it your context.
- **PC on but you're away from it:** `claude remote-control` on the PC lets the phone app drive the full local session.

## 5. Jobs: `fix KrishnaAiGen` / `Analysis KrishnaAiGen`
Reply under a summary (or its Wrap-up post) with `fix KrishnaAiGen` anywhere in a sentence to start a fix job (analysis, fix, test, commit, ship-to-qa), or `Analysis KrishnaAiGen` for a read-only analysis with a draft reply. Each step is reported in that thread; `stop` cancels. Details: `reference.md` §8.1.
- Config keys (private `config.json`, all optional): `jobs_enabled` (true), `job_workdir` (`C:\WG-Agentic`), `job_base_branch` (`develop`), `job_effort` (`high`), `job_max_minutes` (240), `max_concurrent_jobs` (1), `job_allowed_tools`, `job_denied_tools`, `job_model`.
- **Headless trust (no longer needed, Prompt 12):** Claude Code ignores a project's `.mcp.json` and `settings.json` until the folder is trusted (`projects["C:/WG-Agentic"].hasTrustDialogAccepted`). The job runner (`Run-ArJob.ps1`) now passes the project's `.mcp.json` with `--mcp-config` (config key `job_mcp_config`, default `<job_workdir>\.mcp.json`) and the tool allow-list and folders as flags, so Jenkins, Bitbucket and the other servers work with **no edit of `~/.claude.json`**. Verified on 2026-11-21: with the flag, a headless session in `C:\WG-Agentic` lists bitbucket, jenkins, cis-db, mssql-sqlauth and the rest while the folder is still untrusted. Only the project's allow-list is still ignored, which the flags replace. If you ever want the folder trusted anyway, open Claude Code once from `C:\WG-Agentic` with the path typed as `C:\WG-Agentic` and accept the dialog.
- PC off: see `slack-auto-reply-web-jobs.md` (designed, not switched on).

## Troubleshooting
| Symptom | Fix |
|---|---|
| Install page says Request, or an error | Section 0 |
| Bot DM "a Slack token was refused" / `missing_scope` in a log | Check `SLACK_USER_TOKEN`/`SLACK_BOT_TOKEN` and the six user scopes (section 0), then reinstall |
| `search.messages failed` in a log | `search:read` is missing. DMs listed in `persona.md` are still checked, but new senders are not found |
| Bot DM "the reasoning step failed" | Open the newest `runs\…\stderr.txt`; usually the Claude login expired, so run `claude` and `/login` |
| Nothing happens | `Get-ScheduledTaskInfo 'Slack Auto-Reply'`; `-Status`; the newest `logs\cycle_*.log`. In proposal mode a quiet inbox also means nothing was due |
| A reply you didn't like | Reply `correct: …` and `learn: …` under its summary, or set that person to `away-only` in `persona.md` |
| `send` says "not sent" | You have written in that DM since, or the proposal is old. `send!` sends it anyway |
