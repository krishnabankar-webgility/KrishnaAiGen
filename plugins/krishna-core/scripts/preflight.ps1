<#
  krishna-core session preflight
  Runs on SessionStart. Read-only, fast, never prints a secret value.
  Its stdout is injected into Claude's context as the session readiness card.
#>

$ErrorActionPreference = 'SilentlyContinue'
$out = [System.Text.StringBuilder]::new()
function W([string]$s) { [void]$out.AppendLine($s) }

# ---------------------------------------------------------------- workspace
$trees = @('C:\WG-Agentic', 'C:\WG-Agentic 2')
$repos = @('KrishnaAiGen', 'unify-enterprise', 'cloud-integration-systems', 'wg-ai-workspace')

W '## Workspace readiness (krishna-core preflight)'
W ''
W '| Tree | Repo | Branch | Dirty |'
W '|---|---|---|---|'
foreach ($t in $trees) {
  if (-not (Test-Path -LiteralPath $t)) { continue }
  foreach ($r in $repos) {
    $p = Join-Path $t $r
    if (-not (Test-Path -LiteralPath (Join-Path $p '.git'))) { continue }
    $br = (& git -C $p rev-parse --abbrev-ref HEAD 2>$null)
    if (-not $br) { $br = '?' }
    $dirty = (& git -C $p status --porcelain 2>$null | Measure-Object -Line).Lines
    $mark = if ($dirty -gt 0) { "$dirty file(s)" } else { 'clean' }
    W ("| {0} | {1} | ``{2}`` | {3} |" -f (Split-Path $t -Leaf), $r, $br, $mark)
  }
}
W ''

# ---------------------------------------------------------------- credentials
# Names only. Values are never read into the report.
$creds = [ordered]@{
  'JIRA_API_TOKEN'              = 'Jira REST (local jira MCP; the Atlassian connector does not need it)'
  'BITBUCKET_TOKEN'             = 'Bitbucket push / PR + fetch-bitbucket.ps1'
  'BITBUCKET_USERNAME'          = 'Bitbucket remote URL (account slug, not the email)'
  'SLACK_BOT_TOKEN'             = 'Slack MCP posting'
  'SLACK_TEAM_ID'               = 'Slack workspace id'
  'KIBANA_WD_AUTH'              = 'Kibana WD HTTPS API (wd-es-kibana)'
  'GOOGLE_OAUTH_CLIENT_ID'      = 'Google Workspace MCP'
  'GOOGLE_OAUTH_CLIENT_SECRET'  = 'Google Workspace MCP'
  'USER_GOOGLE_EMAIL'           = 'Google Workspace default account'
}
$missing = @()
foreach ($k in $creds.Keys) {
  $v = [System.Environment]::GetEnvironmentVariable($k, 'User')
  if (-not $v) { $v = [System.Environment]::GetEnvironmentVariable($k, 'Process') }
  if (-not $v) { $missing += $k }
}

$envFile = 'C:\WG-Agentic\wg-ai-workspace\.env'
$envOk = Test-Path -LiteralPath $envFile

W '## Credentials'
W ''
if ($missing.Count -eq 0) {
  W 'All expected user environment variables are present.'
} else {
  W 'Missing from the user environment (set only if a task needs it):'
  W ''
  foreach ($m in $missing) { W ("- ``{0}`` - {1}" -f $m, $creds[$m]) }
}
W ''
if ($envOk) {
  W "``wg-ai-workspace/.env`` present - the local MCP servers (bitbucket, jenkins, the DB proxies, ES) read their credentials from it."
} else {
  W "**``$envFile`` is missing.** Every local MCP server that takes ``--env-file`` will fail to start until it exists."
}
W ''

# ---------------------------------------------------------------- tooling
$tools = [ordered]@{
  'git'    = 'git'
  'node'   = 'node'
  'dotnet' = 'dotnet'
  'uvx'    = 'uvx'
}
$absent = @()
foreach ($t in $tools.Keys) {
  if (-not (Get-Command $tools[$t] -ErrorAction SilentlyContinue)) { $absent += $t }
}
if ($absent.Count -gt 0) {
  W ('**Not on PATH:** ' + ($absent -join ', ') + ' - MCP servers that need them will not start.')
  W ''
}

# ---------------------------------------------------------------- routing card
W '## Routing'
W ''
W 'Specialist agents are available through the `Agent` tool; skills load themselves by relevance.'
W 'Prefer them over improvising:'
W ''
W '| Work | Agent | Slash command |'
W '|---|---|---|'
W '| Jira UD tickets, RFT, QA comment | `jira-automation` | `/jira` |'
W '| Commit / push / branch sync | `git-automation` | `/git` |'
W '| Bitbucket PR on unify-enterprise | `bitbucket-automation` | `/bitbucket` |'
W '| Customer customization (CIM/FR/CFC) | `dev-customization` | `/customization` |'
W '| Implementation done, ready for QA (build/share/RFT/Slack/QA comment) | `ship-to-qa` | `/ship-to-qa` |'
W '| Kibana / ES log analysis | `wd-es-kibana` | `/kibana` |'
W '| Confluence pages | `confluence-automation` | `/confluence` |'
W '| Slack | `slack-automation` | `/slack` |'
W '| Local SQL Server | `db-automation` | `/db` |'
W '| Daily digest | `daily-work-update` | `/daily-update` |'
W '| Windows / VPN / SMB / VM | `sys-troubleshoot` | `/sys-fix` |'
W '| Persist a correction into the skills | `agent-learning` | `/learn` |'
W '| Build a brand-new skill or agent | `skill-author` | - |'
W '| Archive stale/resolved memory (never deletes) | `memory-gardener` | - |'
W '| See every agent, how to invoke one directly | - | `/agents-list` |'
W ''
W 'In `unify-enterprise`: `wd-lead` (plan) -> `wd-dev` (implement) -> `wd-qa` (verify) -> `wd-review` (review),'
W 'plus `wd-scout` for read-only questions and the 16 `wd-*` domain agents for module work.'
W ''
W 'Starting work on a ticket: load the `ticket-context` skill first - it reads'
W '`C:\WG-Agentic\Reference\<TICKET>\` and the `memories/` notes before any code is touched.'

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
Write-Output $out.ToString()
