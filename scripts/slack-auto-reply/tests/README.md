# slack-auto-reply tests

Offline tests for `Invoke-SlackAutoReply.ps1`. They use fixture people and IDs only (this repo is public) and never touch real Slack or Jira.
Run both after **any** change to the runner (needs PowerShell 7 and Windows PowerShell):

```powershell
pwsh -File KrishnaAiGen\scripts\slack-auto-reply\tests\Test-Unit.ps1        # about 2 s: safety checks, send/hold matrix, commands, masking, title rule, persona lookups
pwsh -File KrishnaAiGen\scripts\slack-auto-reply\tests\Test-EndToEnd.ps1    # about 40 s: real cycles of the runner against a fake Slack
```

| File | What it is |
|---|---|
| `Test-Unit.ps1` | Extracts the runner's pure functions with the PowerShell parser and checks them against a fixture persona |
| `Test-EndToEnd.ps1` | Starts the fake Slack, then runs the runner through 11 scenarios (proposal mode, `send`/`send!`, `live`, pause, failures, bot identity, search fallback, summary retry) |
| `stub-slack.ps1` | The fake Slack Web API (HttpListener on 127.0.0.1:8799, state in a JSON file) plus one fake Jira issue |
| `stub-claude.ps1` | Stands in for `claude -p`: returns a canned decision chosen by trigger words in the fixture DMs |

The runner has two test hooks, both inert unless set: `SLACK_AR_STORE` (private-store folder) and `SLACK_API_BASE` (Slack API URL).
What the tests cannot cover: real Slack API behaviour (`search.messages` with `is:dm`, the user-token calls) and the real `claude -p` reasoner. Check those with `-Shadow` once the user token exists.
