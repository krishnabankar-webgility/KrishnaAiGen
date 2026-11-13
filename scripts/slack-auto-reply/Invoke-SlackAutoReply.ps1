<#
.SYNOPSIS
  Slack DM auto-reply on Krishna's behalf: local / VM runner, KrishnaAiGen Slack app tokens only.
  Rules: plugins/krishna-core/skills/slack-auto-reply/reference.md. Setup: plugins/krishna-core/docs/setup-slack-auto-reply.md.

.DESCRIPTION
  This script does all Slack, Jira and state work itself:
    SLACK_USER_TOKEN (xoxp, acts as Krishna): find DMs, read conversations, send the reply.
    SLACK_BOT_TOKEN  (xoxb, KrishnaAiGen bot): AR-STATE switchboard, summaries, command threads, alerts.
    JIRA_EMAIL / JIRA_API_TOKEN: ticket facts for the evidence pack.
  Claude is called only for a DM that is due. It runs sandboxed (Read tool only, no MCP or connectors)
  and returns a decision as JSON. It cannot send, post or write anything.
  Every reply starts as a PROPOSAL in #my-daily-update: nothing reaches anyone until Krishna replies `live`
  under AR-STATE (or `send` under one summary).
  Private data: %USERPROFILE%\.claude\slack-auto-reply\ (never committed).
  Test hooks: SLACK_AR_STORE (private folder) and SLACK_API_BASE (Slack API URL).

.EXAMPLE
  pwsh -File Invoke-SlackAutoReply.ps1 -Init              # once: post AR-STATE, write config (needs the bot token only)
  pwsh -File Invoke-SlackAutoReply.ps1 -Shadow            # dry run: decide, but no Slack writes at all
  pwsh -File Invoke-SlackAutoReply.ps1                    # one cycle (what Task Scheduler runs)
  pwsh -File Invoke-SlackAutoReply.ps1 -Status
  pwsh -File Invoke-SlackAutoReply.ps1 -Pause 4h | -Pause on | -Resume | -Mode live | -Answers live | -Away shadow
#>
[CmdletBinding()]
param(
  [ValidateSet('local', 'vm')] [string]$Runner = 'local',
  [switch]$Init,
  [switch]$Shadow,
  [switch]$Status,
  [string]$Pause = '',
  [switch]$Resume,
  [ValidateSet('', 'live', 'shadow')] [string]$Mode = '',
  [ValidateSet('', 'live', 'shadow')] [string]$Answers = '',
  [ValidateSet('', 'live', 'shadow')] [string]$Away = ''
)
$ErrorActionPreference = 'Stop'

$Store      = if ($env:SLACK_AR_STORE) { $env:SLACK_AR_STORE } else { Join-Path $env:USERPROFILE '.claude\slack-auto-reply' }
$SlackApi   = if ($env:SLACK_API_BASE) { $env:SLACK_API_BASE.TrimEnd('/') } else { 'https://slack.com/api' }
$SkillDir   = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'plugins\krishna-core\skills\slack-auto-reply'
$Channel    = 'C0B0CBW8G03'        # #my-daily-update
$Krishna    = 'U08FTS2SRAP'
$SkipUsers  = @('U0AFJGQSR8X', 'U0APDD2PYRX', 'USLACKBOT')   # Claude app, KrishnaAiGen bot, Slackbot
$Disclosure = "🤖 *KrishnaAiGen* · Krishna's AI assistant · auto-reply"
$Closing    = "Your message is noted and he has been informed. He'll get back to you himself."
$MarkerRx   = '_ref AR-D[A-Z0-9]+-\d+\.\d+_'
$WdCtxRx    = '/wd-answer|\[wd-context\]'
$AuthErrRx  = 'invalid_auth|token_revoked|not_authed|account_inactive|missing_scope'
# PM, EM and anything more senior get the away note only (Krishna, 2026-11-05). Override with config leadership_title_regex.
$LeadershipRx = '(?i)\b(director|vice[ -]president|vp|svp|avp|head of|chief|c[etfio]o|president|founder|owner|general manager|manager)\b'

New-Item -ItemType Directory -Force (Join-Path $Store 'logs'), (Join-Path $Store 'runs') | Out-Null
$log = Join-Path $Store ("logs\cycle_{0}.log" -f (Get-Date -Format 'yyyy-MM-dd_HHmmss'))
function Log($msg) { $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $msg; $line | Out-File $log -Append -Encoding utf8; Write-Verbose $line }
function Say($msg) { Log $msg; Write-Host $msg }

# User env vars set after a session started are not in that process's environment, so look in all three places.
function Get-EnvVar($n) { foreach ($s in 'Process', 'User', 'Machine') { $v = [Environment]::GetEnvironmentVariable($n, $s); if ($v) { return $v } } }
$Bot = Get-EnvVar 'SLACK_BOT_TOKEN'; $Usr = Get-EnvVar 'SLACK_USER_TOKEN'
$JiraEmail = Get-EnvVar 'JIRA_EMAIL'; $JiraToken = Get-EnvVar 'JIRA_API_TOKEN'; $JiraBase = Get-EnvVar 'JIRA_BASE_URL'
$controlOnly = $Init -or $Status -or $Pause -or $Resume -or $Mode -or $Answers -or $Away     # these need only the bot token
if (-not $Bot) { Say 'SLACK_BOT_TOKEN is not set (user env var). See setup-slack-auto-reply.md.'; exit 1 }
if (-not $controlOnly -and -not $Usr) { Say 'SLACK_USER_TOKEN is not set (user env var). Add the user scopes, reinstall the KrishnaAiGen app, then set it. See setup-slack-auto-reply.md.'; exit 1 }

# --- Slack Web API ---------------------------------------------------------------------------
function Invoke-Slack($token, $method, [hashtable]$args_, [switch]$Post) {
  for ($try = 1; $try -le 3; $try++) {
    try {
      if ($Post) {
        $json = $args_ | ConvertTo-Json -Depth 10 -Compress
        $r = Invoke-RestMethod -Method Post -Uri "$SlackApi/$method" -ContentType 'application/json; charset=utf-8' `
               -Headers @{ Authorization = "Bearer $token" } -Body ([Text.Encoding]::UTF8.GetBytes($json))
      } else {
        $qs = ($args_.GetEnumerator() | ForEach-Object { "{0}={1}" -f $_.Key, [uri]::EscapeDataString([string]$_.Value) }) -join '&'
        $r = Invoke-RestMethod -Uri "$SlackApi/$method`?$qs" -Headers @{ Authorization = "Bearer $token" }
      }
      if (-not $r.ok) { throw "Slack $method failed: $($r.error)" }
      return $r
    } catch {
      $resp = $_.Exception.Response
      if ($resp -and [int]$resp.StatusCode -eq 429 -and $try -lt 3) {
        $wait = 5; try { $wait = [int]($resp.Headers.GetValues('Retry-After') | Select-Object -First 1) } catch { }
        Start-Sleep -Seconds ([Math]::Min($wait, 60)); continue
      }
      throw
    }
  }
}
function ConvertTo-Mrkdwn([string]$s) { if (-not $s) { return '' }; $s.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;') }
function TsNum($ts) { [double]::Parse([string]$ts, [Globalization.CultureInfo]::InvariantCulture) }
function IstTime($ts) { [DateTimeOffset]::FromUnixTimeSeconds([long](TsNum $ts)).ToOffset([TimeSpan]::FromHours(5.5)).ToString('dd-MMM HH:mm') }
function Cfg($name, $default) { $v = $config.$name; if ($null -eq $v -or "$v" -eq '') { $default } else { $v } }

# --- AR-STATE (reference §3.2a) --------------------------------------------------------------
function Format-ArState([hashtable]$st) {
  'AR-STATE v2 | mode_away={0} | mode_answer={1} | paused={2} | heartbeat={3} | runner={4}' -f `
    $st.mode_away, $st.mode_answer, $st.paused, $st.heartbeat, $st.runner
}
function Get-ArState($ts) {
  $r = Invoke-Slack $Bot 'conversations.history' @{ channel = $Channel; latest = $ts; oldest = $ts; inclusive = 'true'; limit = 1 }
  if (-not $r.messages) { throw "AR-STATE message $ts not found in $Channel" }
  $st = @{ mode_away = 'shadow'; mode_answer = 'shadow'; paused = 'no'; heartbeat = '0'; runner = 'none' }   # a missing key fails safe: nothing is sent
  foreach ($part in ($r.messages[0].text -split '\|')) { if ($part -match '^\s*([a-z_]+)=([a-z0-9=_]*)\s*$') { $st[$Matches[1]] = $Matches[2] } }
  $st
}
function Set-ArState($ts, [hashtable]$st) { Invoke-Slack $Bot 'chat.update' @{ channel = $Channel; ts = $ts; text = (Format-ArState $st) } -Post | Out-Null }
function Test-Paused([hashtable]$st, $at) { ($st.paused -eq 'yes') -or ($st.paused -match '^until=(\d+)$' -and [long]$Matches[1] -gt $at) }

# Commands Krishna types in the AR-STATE thread. Mutates $ar and returns the acknowledgement, or $null if not understood.
function Invoke-StateCommand([string]$cmd, [hashtable]$ar, $at) {
  switch -Regex ($cmd.Trim()) {
    '^(?i)pause\s+(\d+)h$'  { $ar.paused = "until=$($at + 3600 * [int]$Matches[1])"; return "paused for $($Matches[1])h" }
    '^(?i)pause$'           { $ar.paused = 'yes'; return 'paused until you reply resume' }
    '^(?i)resume$'          { $ar.paused = 'no'; return 'resumed' }
    '^(?i)(?:go\s+|all\s+|responses?\s+)?live$'                { $ar.mode_away = 'live'; $ar.mode_answer = 'live'; return 'live: away notes and answers now go to people' }
    '^(?i)(?:all\s+|responses?\s+)?(?:shadow|proposals?)$'     { $ar.mode_away = 'shadow'; $ar.mode_answer = 'shadow'; return 'proposal mode: nothing is sent to anyone, replies are proposed here' }
    '^(?i)answers?\s+(live|shadow)$'                           { $ar.mode_answer = $Matches[1].ToLower(); return "answers: $($ar.mode_answer)" }
    '^(?i)away(?:\s+notes?)?\s+(live|shadow)$'                 { $ar.mode_away = $Matches[1].ToLower(); return "away notes: $($ar.mode_away)" }
  }
  $null
}
# What happens to a reply in each mode (reference §6.5): send everything, send the away note and hold the answer, or hold everything.
function Resolve-Delivery([bool]$hasAnswer, [string]$modeAway, [string]$modeAnswer) {
  if (($hasAnswer -and $modeAnswer -eq 'live') -or (-not $hasAnswer -and $modeAway -eq 'live')) { return 'send-full' }
  if ($modeAway -eq 'live') { return 'send-away-hold-answer' }
  'hold-full'
}

function Send-KrishnaAlert($text, $state) {
  $at = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  if ($state.alert_last -and ($at - [long]$state.alert_last) -lt 7200) { Log "Alert throttled: $text"; return }
  try {
    $im = Invoke-Slack $Bot 'conversations.open' @{ users = $Krishna } -Post
    Invoke-Slack $Bot 'chat.postMessage' @{ channel = $im.channel.id; text = ":warning: *Slack auto-reply:* $text" } -Post | Out-Null
    $state.alert_last = $at
  } catch { Log "Alert failed: $_" }
}

$configPath = Join-Path $Store 'config.json'
$statePath  = Join-Path $Store 'state.json'
$settingsPath = Join-Path $Store 'agent-settings.json'
$emptyMcp   = Join-Path $Store 'empty-mcp.json'

# --- -Init -----------------------------------------------------------------------------------
if ($Init) {
  if (Test-Path $configPath) { Say "Already initialised: $configPath (delete it to re-init)."; exit 0 }
  $st = @{ mode_away = 'shadow'; mode_answer = 'shadow'; paused = 'no'; heartbeat = 0; runner = 'none' }
  $post = Invoke-Slack $Bot 'chat.postMessage' @{ channel = $Channel; text = (Format-ArState $st) } -Post
  Invoke-Slack $Bot 'chat.postMessage' @{ channel = $Channel; thread_ts = $post.ts; text = 'Control thread for the DM auto-reply. Everything starts as a proposal: nothing is sent to anyone until you reply `live`. Reply here with: `live` · `shadow` · `pause` · `pause 4h` · `resume` · `answers live` · `answers shadow` · `away live` · `away shadow`' } -Post | Out-Null
  [ordered]@{
    state_message_ts = $post.ts
    claude_path      = (Join-Path $env:USERPROFILE '.local\bin\claude.exe')
    wd_context_dir   = 'C:\WG-Agentic\wd-context'
    unify_repo       = 'C:\WG-Agentic\unify-enterprise'
    work_start_ist   = '10:30'
    work_end_ist     = '22:30'
    dm_due_minutes   = 30          # a DM waits this long for Krishna before the auto-reply considers it
    poll_minutes     = 15          # informational: Register-SlackAutoReplyTask.ps1 sets the real interval (reading Slack costs nothing)
    repropose_after_minutes = 120  # while a proposal is pending, don't propose again for new messages sooner than this
    reply_identity   = 'user'      # user: reply in the DM as Krishna with the KrishnaAiGen label line. bot: from the KrishnaAiGen app, in its own DM
    channel_mentions_enabled = $false   # reserved: channels come after DMs are trusted
    channel_due_minutes      = 60       # reserved: a channel mention waits this long
    max_claude_calls_per_cycle = 5
    max_turns        = 25
    model            = ''
  } | ConvertTo-Json | Set-Content $configPath -Encoding utf8
  [ordered]@{ permissions = [ordered]@{ deny = @('Read(**/.env*)', 'Read(**/.credentials.json)', 'Read(**/*.pfx)', 'Read(**/*token*)', 'Read(**/state.json)', 'Read(**/config.json)') } } |
    ConvertTo-Json -Depth 5 | Set-Content $settingsPath -Encoding utf8
  '{"mcpServers":{}}' | Set-Content $emptyMcp -Encoding utf8
  foreach ($f in 'persona.md', 'exceptions.md') { $p = Join-Path $Store $f; if (-not (Test-Path $p)) { "# $f (private)`n" | Set-Content $p -Encoding utf8 } }
  Say "Initialised. AR-STATE ts $($post.ts) in #my-daily-update. Everything starts as a proposal: nothing is sent to anyone until you reply 'live' there."
  exit 0
}

if (-not (Test-Path $configPath)) { Say 'Not initialised; run with -Init first.'; exit 1 }
$config = Get-Content $configPath -Raw | ConvertFrom-Json
$state  = if (Test-Path $statePath) { Get-Content $statePath -Raw | ConvertFrom-Json -AsHashtable } else { @{} }
foreach ($k in 'handled', 'mutes', 'users') { if (-not $state.ContainsKey($k)) { $state[$k] = @{} } }
if (-not $state.ContainsKey('done_cmds')) { $state['done_cmds'] = @() }
function Save-State { $state | ConvertTo-Json -Depth 8 | Set-Content $statePath -Encoding utf8 }
$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

# --- Control switches (no Claude) ------------------------------------------------------------
if ($Status -or $Pause -or $Resume -or $Mode -or $Answers -or $Away) {
  $ar = Get-ArState $config.state_message_ts
  if ($Pause)   { $ar.paused = if ($Pause -match '^(\d+)h$') { "until=$($now + 3600 * [int]$Matches[1])" } else { 'yes' } }
  if ($Resume)  { $ar.paused = 'no' }
  if ($Mode)    { $ar.mode_away = $Mode; $ar.mode_answer = $Mode }
  if ($Answers) { $ar.mode_answer = $Answers }
  if ($Away)    { $ar.mode_away = $Away }
  if (-not $Status) { Set-ArState $config.state_message_ts $ar }
  Say (Format-ArState $ar)
  Say ('Proposals waiting for you: {0} · a DM waits {1} min · replies go out as: {2}' -f @($state.handled.Values | Where-Object { $_.pending_msg }).Count, (Cfg 'dm_due_minutes' 30), (Cfg 'reply_identity' 'user'))
  if ($Status) {
    $state.handled.GetEnumerator() | Sort-Object { $_.Value.at } -Descending | Select-Object -First 10 |
      ForEach-Object { Say ("  {0}  {1,-22} {2,-11} {3}{4}" -f (IstTime $_.Value.at), $_.Value.partner_name, $_.Value.type, $_.Value.asked, $(if ($_.Value.pending_msg) { '  [proposal waiting]' } else { '' })) }
  }
  exit 0
}

# --- Helpers for the cycle -------------------------------------------------------------------
function Get-UserInfo($uid) {
  $c = $state.users[$uid]
  if ($c -and ($now - [long]$c.at) -lt 86400) { return $c }
  $u = (Invoke-Slack $Usr 'users.info' @{ user = $uid }).user
  $c = @{ at = $now; name = $(if ($u.real_name) { $u.real_name } else { $u.name }); title = [string]$u.profile.title; is_bot = [bool]($u.is_bot -or $u.deleted -or $u.is_app_user) }
  $state.users[$uid] = $c; $c
}
function Get-PersonaPolicy($uid) {
  $p = Join-Path $Store 'persona.md'
  if (-not (Test-Path $p)) { return 'answers-ok' }
  $row = Get-Content $p | Where-Object { $_ -match "\|\s*$uid\s*\|" } | Select-Object -First 1
  if (-not $row) { return 'answers-ok' }
  $cells = $row.Split('|') | ForEach-Object { $_.Trim() }
  foreach ($c in $cells) { if ($c -in 'answers-ok', 'references-ok', 'away-only', 'never') { return $c } }
  'answers-ok'
}
# DM channel -> person, from the persona table. A safety net so a DM is still found if Slack search is unavailable.
function Get-PersonaDms {
  $m = @{}
  $p = Join-Path $Store 'persona.md'
  if (Test-Path $p) {
    foreach ($row in @(Get-Content $p | Where-Object { $_ -match '^\|[^|]*\|\s*U[A-Z0-9]{6,}\s*\|\s*D[A-Z0-9]{6,}\s*\|' })) {
      $c = $row.Split('|') | ForEach-Object { $_.Trim() }
      $m[$c[3]] = $c[2]
    }
  }
  $m
}
function Get-DmTimeline($dm) {
  $h = Invoke-Slack $Usr 'conversations.history' @{ channel = $dm; oldest = ($now - 172800); limit = 200 }
  $all = [Collections.Generic.List[object]]::new()
  foreach ($m in $h.messages) {
    $all.Add($m)
    if ([int]$m.reply_count -gt 0) {
      $rep = Invoke-Slack $Usr 'conversations.replies' @{ channel = $dm; ts = $m.ts; oldest = ($now - 172800); limit = 200 }
      foreach ($r in $rep.messages) { if ($r.ts -ne $m.ts) { $all.Add($r) } }
    }
  }
  @($all | Where-Object { $_.subtype -notin 'channel_join', 'message_deleted' } | Sort-Object { TsNum $_.ts })
}
function Get-Permalink($dm, $ts) { try { (Invoke-Slack $Usr 'chat.getPermalink' @{ channel = $dm; message_ts = $ts }).permalink } catch { '' } }
function Get-AwayReason {
  try {
    $p = (Invoke-Slack $Usr 'users.profile.get' @{ user = $Krishna }).profile
    $exp = [long]$p.status_expiration
    if ($p.status_text -and ($exp -eq 0 -or $exp -gt $now)) {
      if ($p.status_text -match '(?i)leave|vacation|holiday|ooo|out of office|sick') { return 'on leave' }
      if ($p.status_text -match '(?i)meeting|call|zoom|meet|discord') { return 'in a meeting right now' }
      return 'away from Slack right now'
    }
  } catch { Log "profile read failed: $_" }
  $ist = [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(5.5)).TimeOfDay
  if ($ist -lt [TimeSpan]::Parse((Cfg 'work_start_ist' '10:30')) -or $ist -gt [TimeSpan]::Parse((Cfg 'work_end_ist' '22:30'))) { return "offline for the day; he'll see this in the morning" }
  'away from Slack right now'
}
function Get-Evidence($texts) {
  $keys = @(([regex]::Matches(($texts -join ' '), '(?i)\bUD[-_ ]?(\d{4,6})\b') | ForEach-Object { "UD-$($_.Groups[1].Value)" }) | Select-Object -Unique -First 5)
  $jira = @(); $branches = @(); $vault = @()
  foreach ($k in $keys) {
    if ($JiraToken -and $JiraBase) {
      try {
        $h = @{ Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${JiraEmail}:$JiraToken")) }
        $i = Invoke-RestMethod -Uri "$JiraBase/rest/api/3/issue/$k`?fields=summary,status,assignee,fixVersions,updated,issuetype" -Headers $h
        $jira += [ordered]@{ key = $k; url = "$JiraBase/browse/$k"; type = $i.fields.issuetype.name; summary = $i.fields.summary; status = $i.fields.status.name
                             assignee = $i.fields.assignee.displayName; fix_versions = @($i.fields.fixVersions | ForEach-Object name); updated = $i.fields.updated }
      } catch { Log "Jira $k failed: $_" }
    }
    $num = $k.Substring(3)
    try { $branches += @(git -C $config.unify_repo for-each-ref --format='%(refname:short)' refs/remotes/origin 2>$null | Where-Object { $_ -match "UD[-_]$num" }) } catch { }
    $idx = Join-Path $config.wd_context_dir "tickets\$k\index.md"
    if (Test-Path $idx) { $t = Get-Content $idx -Raw; $vault += [ordered]@{ key = $k; file = $idx; excerpt = $t.Substring(0, [Math]::Min(4000, $t.Length)) } }
  }
  [ordered]@{ ticket_keys = $keys; jira = $jira; branches_as_of_last_fetch = @($branches | Select-Object -Unique); wd_context = $vault }
}
function Invoke-Reasoner($evidence, $runDir) {
  $evidence | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $runDir 'evidence.json') -Encoding utf8
  $claude = if (Test-Path $config.claude_path) { $config.claude_path } else { (Get-Command claude -ErrorAction Stop).Source }
  $ref = Join-Path $SkillDir 'reference.md'
  $prompt = "You are the reasoning step of the slack-auto-reply system. Read $ref sections 2, 5, 6 and 7, then $Store\persona.md and $Store\exceptions.md, then evidence.json in the current folder. You may read files under the extra directories to check facts. Your final message must be only the JSON object defined in reference section 6.4."
  $cliArgs = @('-p', $prompt, '--tools', 'Read', '--strict-mcp-config', '--mcp-config', $emptyMcp, '--permission-mode', 'dontAsk',
               '--settings', $settingsPath, '--output-format', 'json', '--max-turns', [string](Cfg 'max_turns' 25),
               '--add-dir', $Store, '--add-dir', $SkillDir)
  foreach ($d in @((Join-Path $config.wd_context_dir 'tickets'), (Join-Path $config.unify_repo 'memories'))) { if (Test-Path $d) { $cliArgs += @('--add-dir', $d) } }
  if ($config.model) { $cliArgs += @('--model', $config.model) }
  Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
  Push-Location $runDir
  try { $raw = & $claude @cliArgs 2> (Join-Path $runDir 'stderr.txt') | Out-String } finally { Pop-Location }
  $raw | Set-Content (Join-Path $runDir 'stdout.json') -Encoding utf8
  $outer = $null; try { $outer = $raw | ConvertFrom-Json } catch { }
  if (-not $outer -or $outer.is_error -or -not $outer.result) { throw "reasoner failed (subtype=$($outer.subtype))" }
  $t = [string]$outer.result; $i = $t.IndexOf('{'); $j = $t.LastIndexOf('}')
  if ($i -lt 0 -or $j -le $i) { throw 'reasoner returned no JSON' }
  $t.Substring($i, $j - $i + 1) | ConvertFrom-Json
}
function Test-SafeBody([string]$s) {
  if (-not $s) { return $true }
  if ($s.Length -gt 700) { return $false }
  if ($s -match '(?i)xox[abprs]-|password|passwd|api[_ -]?key|secret|token\s*[:=]|\+91[\s-]?\d{5}[\s-]?\d{5}|(?<!\d)\d{10}(?!\d)|AR-D[A-Z0-9]+') { return $false }
  foreach ($u in [regex]::Matches($s, 'https?://[^\s>|]+')) {
    if ($u.Value -notmatch '^https://(webgility\.atlassian\.net|bitbucket\.org/webgility|webgility\.slack\.com|github\.com/krishnabankar-webgility)/') { return $false }
  }
  $true
}
# For the summary: it quotes people, so strip anything credential-like or personal first.
function Hide-Secrets([string]$s) {
  if (-not $s) { return '' }
  $s = [regex]::Replace($s, 'xox[abprs]-[A-Za-z0-9-]+', '[token]')
  $s = [regex]::Replace($s, '(?i)\b(password|passwd|pwd|secret|token|api[_ -]?key)\b(\s*(?:is|:|=)\s*)\S+', '${1}${2}[hidden]')
  $s = [regex]::Replace($s, '(?<!\d)\d{10,}(?!\d)', '[number]')
  [regex]::Replace($s, '[\w.+-]+@[\w-]+\.[\w.-]+', '[email]')
}
function Format-Quote([string]$s) { (($s -split "\r?\n") | ForEach-Object { '> ' + (ConvertTo-Mrkdwn $_) }) -join "`n" }
function Remove-Marker([string]$s) { (($s -split "\r?\n") | Where-Object { $_ -notmatch '^_ref AR-' }) -join "`n" }
# reply_identity user: in the DM as Krishna (the label line says it is the assistant). bot: from the KrishnaAiGen app, in its own DM with that person.
function Send-Reply($dm, $partner, $text, $threadTs) {
  $a = @{ text = $text; unfurl_links = $false; unfurl_media = $false }
  if ((Cfg 'reply_identity' 'user') -eq 'bot') {
    $a.channel = (Invoke-Slack $Bot 'conversations.open' @{ users = $partner } -Post).channel.id
    return (Invoke-Slack $Bot 'chat.postMessage' $a -Post).ts
  }
  $a.channel = $dm
  if ($threadTs) { $a.thread_ts = $threadTs }
  (Invoke-Slack $Usr 'chat.postMessage' $a -Post).ts
}
function Send-Summary($lines, $threadTs) {
  $a = @{ channel = $Channel; text = ($lines -join "`n"); unfurl_links = $false; unfurl_media = $false }
  if ($threadTs) { $a.thread_ts = $threadTs }
  (Invoke-Slack $Bot 'chat.postMessage' $a -Post).ts
}
# Record the episode first (so a reply is never sent twice), then post its summary. If the post fails, the text stays in
# state and is re-posted next cycle, so a proposal or a sent reply never goes unreported.
function Save-WithSummary($key, $entry, $lines) {
  $entry.summary_ts = ''; $entry.summary_text = ($lines -join "`n")
  $state.handled[$key] = $entry; Save-State
  try { $entry.summary_ts = Send-Summary $lines; $entry.summary_text = '' } catch { Log "Summary for $key not posted yet ($_); it will be retried next cycle." }
  Save-State
}
# A proposal is stale when it is old or Krishna has written in that DM since: `send` then asks for `send!`.
function Test-StaleProposal($ep) {
  if (($now - [long]$ep.at) -gt 43200) { return 'the proposal is over 12 hours old' }
  $firstTs = if ($ep.first_ts) { TsNum $ep.first_ts } else { 0 }
  if (Get-DmTimeline $ep.dm | Where-Object { $_.user -eq $Krishna -and $_.text -notmatch $MarkerRx -and (TsNum $_.ts) -gt $firstTs }) { return 'you have already written in that DM' }
  ''
}

# --- Cycle -----------------------------------------------------------------------------------
$lock = Join-Path $Store 'run.lock'
if ((Test-Path $lock) -and ((Get-Date) - (Get-Item $lock).LastWriteTime).TotalMinutes -lt 50) { Log 'Previous cycle still running; skip.'; exit 0 }
Set-Content $lock $PID
try {
  $ar = Get-ArState $config.state_message_ts
  if ($Runner -eq 'vm' -and $ar.runner -eq 'local' -and ($now - [long]$ar.heartbeat) -lt 1800) { Log 'Local runner is active; vm stands by.'; return }

  # 1. Krishna's commands (reference §8): handled by this script, even while paused.
  if (-not $Shadow) {
    $threads = @(@{ ts = $config.state_message_ts; key = '' })
    $state.handled.GetEnumerator() | Where-Object { $_.Value.summary_ts -and ($now - [long]$_.Value.at) -lt 172800 } |
      ForEach-Object { $threads += @{ ts = $_.Value.summary_ts; key = $_.Key } }
    foreach ($th in $threads) {
      $rep = Invoke-Slack $Bot 'conversations.replies' @{ channel = $Channel; ts = $th.ts; oldest = ($now - 604800); limit = 100 }
      foreach ($m in @($rep.messages | Where-Object { $_.ts -ne $th.ts })) {
        if ($m.user -ne $Krishna -or $m.bot_id -or $m.text -match 'Sent using' -or $state.done_cmds -contains $m.ts) { continue }
        $cmd = ([string]$m.text).Trim(); $result = $null
        $state.done_cmds = @($state.done_cmds + $m.ts | Select-Object -Last 1000); Save-State   # ledger first: a crash never resends
        if (-not $th.key) {
          $result = Invoke-StateCommand $cmd $ar $now
          if ($result) { Set-ArState $config.state_message_ts $ar }
          else { $result = 'not understood. Commands: live · shadow · pause · pause 4h · resume · answers live|shadow · away live|shadow' }
        } else {
          $ep = $state.handled[$th.key]; if (-not $ep) { continue }
          switch -Regex ($cmd) {
            '^(?i)send(!)?$' {
              if (-not $ep.pending_msg) { $result = 'nothing to send for this one'; break }
              $why = if ($Matches[1]) { '' } else { Test-StaleProposal $ep }
              if ($why) { $result = "not sent: $why. Reply ``send!`` to send it anyway."; break }
              $ep.sent_ts = Send-Reply $ep.dm $ep.partner $ep.pending_msg $ep.thread_ts; $ep.pending_msg = ''; $result = 'sent'
              break
            }
            '^(?i)send:\s*([\s\S]+)$' {
              $t = $Matches[1].Trim(); if ((Cfg 'reply_identity' 'user') -eq 'bot') { $t = "From Krishna: $t" }
              $ep.sent_ts = Send-Reply $ep.dm $ep.partner $t $ep.thread_ts; $ep.pending_msg = ''; $result = 'your text was sent'
              break
            }
            '^(?i)correct:\s*([\s\S]+)$' {
              $ep.sent_ts = Send-Reply $ep.dm $ep.partner ("Correction from Krishna: " + $Matches[1].Trim()) $ep.thread_ts; $ep.pending_msg = ''; $result = 'correction sent'
              break
            }
            '^(?i)learn:\s*([\s\S]+)$' { "- $(Get-Date -Format 'yyyy-MM-dd') [learn] $($ep.partner_name): $($Matches[1].Trim())" | Out-File (Join-Path $Store 'exceptions.md') -Append -Encoding utf8; $result = 'rule saved' ; break }
            '^(?i)mute(\s+(\d+)d)?$'   { $state.mutes[$ep.partner] = $(if ($Matches[2]) { $now + 86400 * [int]$Matches[2] } else { 4102444800 }); $result = "muted $($ep.partner_name)" ; break }
            '^(?i)unmute$'             { $state.mutes.Remove($ep.partner); $result = "unmuted $($ep.partner_name)" ; break }
            '^(?i)(ok|skip)$'          { $result = 'ok' ; break }
          }
          if (-not $result) { $result = 'not understood. Commands: send · send! · send: text · correct: text · learn: rule · mute [Nd] · unmute · ok' }
        }
        Send-Summary @("✅ $result") $th.ts | Out-Null
        Log "Command '$cmd' -> $result"
      }
    }
    Save-State
  }

  if (Test-Paused $ar $now) {
    Log "Paused ($($ar.paused))."
    $ar.heartbeat = $now; $ar.runner = $Runner; Set-ArState $config.state_message_ts $ar
    return
  }

  # Summaries that failed to post earlier (Slack hiccup): post them now.
  foreach ($e in @($state.handled.Values | Where-Object { $_.summary_text -and -not $_.summary_ts })) {
    try { $e.summary_ts = Send-Summary @($e.summary_text); $e.summary_text = ''; Save-State } catch { Log "Summary repost failed: $_" }
  }

  # Fresh shared context (best effort).
  try { & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $config.wd_context_dir 'scripts\ctx.ps1') pull 2>&1 | Out-File $log -Append -Encoding utf8 } catch { Log "wd-context pull failed: $_" }
  if (-not $state.last_fetch -or ($now - [long]$state.last_fetch) -gt 21600) {
    try { git -C $config.unify_repo fetch origin --quiet 2>&1 | Out-File $log -Append -Encoding utf8; $state.last_fetch = $now } catch { Log "git fetch failed: $_" }
  }

  # 2. Discover DMs with recent messages: Slack search, plus the DMs listed in persona.md as a safety net (reference §4.1).
  $since = [DateTimeOffset]::UtcNow.AddDays(-2).ToOffset([TimeSpan]::FromHours(5.5)).ToString('yyyy-MM-dd')
  $dms = @{}
  try {
    $page = 1
    do {
      $s = Invoke-Slack $Usr 'search.messages' @{ query = "is:dm after:$since"; sort = 'timestamp'; sort_dir = 'desc'; count = 100; page = $page }
      foreach ($m in $s.messages.matches) { if ($m.channel.id -like 'D*' -and $m.user -and $m.user -ne $Krishna) { $dms[$m.channel.id] = $m.user } }
      $page++
    } while ($page -le [Math]::Min(5, [int]$s.messages.paging.pages))
  } catch { Log "search.messages failed ($_); falling back to the DMs in persona.md." }
  foreach ($kv in (Get-PersonaDms).GetEnumerator()) { if (-not $dms.ContainsKey($kv.Key)) { $dms[$kv.Key] = $kv.Value } }

  $awayReason = $null; $claudeCalls = 0
  $dueSec  = 60 * [int](Cfg 'dm_due_minutes' 30)
  $coolSec = 60 * [int](Cfg 'repropose_after_minutes' 120)
  $leadRx  = [string](Cfg 'leadership_title_regex' $LeadershipRx)
  $maxCalls = [int](Cfg 'max_claude_calls_per_cycle' 5)
  foreach ($dm in @($dms.Keys)) {
    try {   # one bad DM must not stop the others
      $partner = $dms[$dm]
      if ($partner -in $SkipUsers -or $partner -eq $Krishna) { continue }
      $pu = Get-UserInfo $partner
      if ($pu.is_bot) { continue }

      $tl = Get-DmTimeline $dm
      $lastGenuine = @($tl | Where-Object { $_.user -eq $Krishna -and $_.text -notmatch $MarkerRx } | Select-Object -Last 1)
      $g = if ($lastGenuine) { TsNum $lastGenuine[0].ts } else { 0 }
      $after = @($tl | Where-Object { (TsNum $_.ts) -gt $g })
      if ($after | Where-Object { $_.user -eq $Krishna -and $_.text -match $MarkerRx }) { continue }       # already auto-replied this episode
      if ($after | Where-Object { $_.subtype -eq 'huddle_thread' -or ($_.user -eq 'USLACKBOT' -and $_.text -match '(?i)huddle') }) { continue }   # they talked live
      $pm = @($after | Where-Object { $_.user -eq $partner })
      if (-not $pm) { continue }
      $key = 'AR-{0}-{1}' -f $dm, $pm[0].ts
      $prev = $state.handled[$key]
      if ($prev -and $prev.sent_ts) { continue }                                                         # something already went out for this episode
      if ($prev -and $prev.silent_policy) { continue }                                                   # never/muted: one summary per episode
      if ($prev -and (TsNum $prev.last_ts) -ge (TsNum $pm[-1].ts)) { continue }                          # nothing new since the last decision
      if ($prev -and $prev.type -ne 'SILENT' -and ($now - [long]$prev.at) -lt $coolSec) { continue }     # a proposal is already waiting: don't re-propose every few minutes
      if ($now - (TsNum $pm[-1].ts) -lt 300) { continue }                                                # still typing
      $trig = @($pm | Where-Object { $_.text -notmatch $WdCtxRx })
      $due = [bool]$trig -and ($now - (TsNum $trig[0].ts)) -ge $dueSec

      $policy = Get-PersonaPolicy $partner
      if ($policy -in 'answers-ok', 'references-ok' -and $pu.title -match $leadRx) { $policy = 'away-only' }   # PM, EM and above, even if not listed
      $muted = $state.mutes[$partner] -and [long]$state.mutes[$partner] -gt $now
      $entry = @{ at = $now; dm = $dm; partner = $partner; partner_name = $pu.name; first_ts = $pm[0].ts; last_ts = $pm[-1].ts; permalink = ''
                  thread_ts = $(if ($trig -and $trig[-1].thread_ts -and $trig[-1].thread_ts -ne $trig[-1].ts) { $trig[-1].thread_ts } else { '' })
                  sent_ts = ''; pending_msg = '' }

      # Silent cases decided without Claude: wd-context-only, muted, or a 'never' person.
      if (-not $trig -or $muted -or $policy -eq 'never') {
        $why = if (-not $trig) { 'wd-context question; answer it with /wd-answer' } elseif ($muted) { 'muted' } else { 'private / no-reply person' }
        $entry.type = 'SILENT'; $entry.asked = $why; $entry.silent_policy = [bool]($muted -or $policy -eq 'never')
        if ($Shadow) { Say "[dry run] $($pu.name): SILENT ($why)"; continue }
        $entry.permalink = Get-Permalink $dm $pm[0].ts
        Save-WithSummary $key $entry @(":robot_face: *DM recorded, no reply sent* · $(ConvertTo-Mrkdwn $pu.name) · $(IstTime $pm[0].ts) IST", "_Reason: $why._ · <$($entry.permalink)|open DM>")
        continue
      }
      if (-not $due) { continue }
      if ($claudeCalls -ge $maxCalls) { Log "Call cap reached; $key waits for the next cycle."; continue }

      # 3. Evidence pack + sandboxed reasoner (reference §5-§7).
      if (-not $awayReason) { $awayReason = Get-AwayReason }
      $conv = @($tl | Select-Object -Last 30 | ForEach-Object {
        [ordered]@{ who = $(if ($_.user -eq $Krishna) { 'Krishna' } elseif ($_.user -eq $partner) { $pu.name } else { 'other' }); time_ist = (IstTime $_.ts)
                    in_episode = ((TsNum $_.ts) -gt $g); thread_reply = [bool]($_.thread_ts -and $_.thread_ts -ne $_.ts)
                    text = [string]$_.text; files = @($_.files | ForEach-Object { $_.name }) } })
      $runDir = Join-Path $Store ("runs\{0}_{1}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $dm); New-Item -ItemType Directory -Force $runDir | Out-Null
      $evidence = [ordered]@{
        runner = $Runner; now_ist = (IstTime $now); away_reason = $awayReason; mode_away = $ar.mode_away; mode_answer = $ar.mode_answer
        partner = [ordered]@{ id = $partner; name = $pu.name; slack_title = $pu.title; persona_policy = $policy }
        conversation = $conv
        facts = (Get-Evidence @($conv | ForEach-Object text))
      }
      $claudeCalls++
      try { $d = Invoke-Reasoner $evidence $runDir }
      catch { Log "Reasoner failed for ${key}: $_"; Send-KrishnaAlert "the reasoning step failed for a DM from $($pu.name), so it got no reply. Log: $log" $state; continue }

      # 4. Validate, compose, final guard, deliver or propose (reference §6).
      $type = [string]$d.type
      if ($type -notin 'ANSWER', 'CONDITIONAL', 'REFERENCES', 'AWAY_ONLY', 'SILENT') { $type = 'AWAY_ONLY' }
      if ($policy -eq 'away-only' -and $type -ne 'SILENT') { $type = 'AWAY_ONLY' }
      if ($policy -eq 'references-ok' -and $type -in 'ANSWER', 'CONDITIONAL') { $type = 'REFERENCES' }
      $body = [string]$d.body
      if (-not (Test-SafeBody $body)) { Log "Body failed safety checks for $key; downgraded."; $body = ''; $type = 'AWAY_ONLY' }
      if ($policy -eq 'away-only') { $body = '' }                                       # PM, EM, leadership and away-only people get the bare away note
      $greet = ([string]$d.greeting) -replace '[\r\n]', ' '; if ($greet.Length -gt 40 -or $greet -match '[<>*_`]') { $greet = '' }
      $hasAnswer = [bool]($type -in 'ANSWER', 'CONDITIONAL', 'REFERENCES' -and $body)
      $standing  = [bool]($type -eq 'AWAY_ONLY' -and $body)                              # Krishna's own standing line from exceptions.md, e.g. night support

      $marker   = '_ref {0}_' -f $key
      $awayLine = ("$greet Krishna is $awayReason.").Trim()
      $bodyLine = @(); if ($hasAnswer -or $standing) { $bodyLine = @($body) }
      $standLine = @(); if ($standing) { $standLine = @($body) }
      $full     = @($Disclosure, $awayLine) + $bodyLine + @($Closing, $marker)
      $awayOnly = @($Disclosure, $awayLine) + $standLine + @($Closing, $marker)
      $followUp = @($Disclosure, $body, $marker)

      $plan = if ($type -eq 'SILENT') { 'none' } else { Resolve-Delivery $hasAnswer $ar.mode_away $ar.mode_answer }
      $sentMsg = ''; $pending = ''
      switch ($plan) {
        'send-full'             { $sentMsg = $full -join "`n" }
        'send-away-hold-answer' { $sentMsg = $awayOnly -join "`n"; $pending = $followUp -join "`n" }
        'hold-full'             { $pending = $full -join "`n" }
      }

      $entry.type = $type; $entry.asked = [string]$d.asked
      if ($Shadow) {
        Say ("[dry run] {0}: {1} · plan {2}`n  asked: {3}`n  would send: {4}`n  would hold as proposal: {5}" -f $pu.name, $type, $plan, $d.asked, ($sentMsg -replace "`n", ' | '), ($pending -replace "`n", ' | '))
        continue
      }
      if ($sentMsg) {
        $chk = Get-DmTimeline $dm      # final guard: if Krishna wrote meanwhile, send nothing
        if ($chk | Where-Object { (TsNum $_.ts) -gt $g -and $_.user -eq $Krishna }) { Log "Krishna replied meanwhile; $key aborted."; continue }
        $entry.sent_ts = Send-Reply $dm $partner $sentMsg $entry.thread_ts
      }
      $entry.pending_msg = $pending
      $entry.permalink = Get-Permalink $dm $pm[0].ts

      $headline = switch ($plan) { 'send-full' { 'sent' } 'send-away-hold-answer' { 'away note sent, answer proposed' } 'hold-full' { 'proposal, nothing sent' } default { 'no reply' } }
      $theirs = Hide-Secrets (($pm | ForEach-Object { [string]$_.text }) -join ' / ')
      if ($theirs.Length -gt 400) { $theirs = $theirs.Substring(0, 400) + '…' }
      $where = if ($entry.permalink) { "DM · <$($entry.permalink)|open DM>" } else { 'DM' }
      $lines = @(":robot_face: *DM auto-reply · $headline* · $(ConvertTo-Mrkdwn $pu.name) · $(IstTime $pm[0].ts) IST", "*Where:* $where")
      if ($type -ne 'SILENT') { $lines += @('*Their message:*', (Format-Quote $theirs)) }     # SILENT means personal/HR/FYI: never quote it into the channel
      $lines += @("*Asked:* $(ConvertTo-Mrkdwn $d.asked)", "*Did:* $type")
      if ($sentMsg) { $lines += @('*Sent:*', (Format-Quote (Remove-Marker $sentMsg))) }
      if ($pending) { $lines += @('*Proposed reply (not sent). Reply `send` to deliver it:*', (Format-Quote (Remove-Marker $pending))) }
      if ($d.evidence) { $lines += "*Evidence:* $(ConvertTo-Mrkdwn ((@($d.evidence)) -join '; '))" }
      if ($d.proposed_rule) { $lines += "*Suggested rule:* $(ConvertTo-Mrkdwn $d.proposed_rule) (reply ``learn: …`` to keep it)" }
      $lines += "_reply here: ``send`` · ``send!`` · ``send: text`` · ``correct: text`` · ``learn: rule`` · ``mute 3d`` · ``ok``_"
      Save-WithSummary $key $entry $lines
      Say "Handled $($pu.name): $type · $plan"
    }
    catch {
      if ("$_" -match $AuthErrRx) { throw }
      Log "DM $dm failed: $_"
    }
  }

  if (-not $Shadow) { $ar.heartbeat = $now; $ar.runner = $Runner; Set-ArState $config.state_message_ts $ar }
  # Keep state small: forget episodes older than 14 days.
  foreach ($k in @($state.handled.Keys)) { if (($now - [long]$state.handled[$k].at) -gt 1209600) { $state.handled.Remove($k) } }
  Log "Cycle done ($claudeCalls reasoner call(s))."
}
catch {
  Log "ERROR: $_"
  if ("$_" -match $AuthErrRx) { Send-KrishnaAlert "a Slack token was refused ($_). Check SLACK_USER_TOKEN / SLACK_BOT_TOKEN and the app scopes." $state }
}
finally {
  Save-State
  Remove-Item $lock -ErrorAction SilentlyContinue
  Get-ChildItem (Join-Path $Store 'logs') -Filter 'cycle_*.log' | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-14) } | Remove-Item -Force
  Get-ChildItem (Join-Path $Store 'runs') -Directory | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-14) } | Remove-Item -Recurse -Force
}
