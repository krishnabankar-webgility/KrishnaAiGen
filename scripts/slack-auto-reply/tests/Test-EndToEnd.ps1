<#
.SYNOPSIS
  End-to-end test of Invoke-SlackAutoReply.ps1 with no network and no real data: a fake Slack API (stub-slack.ps1,
  which also serves one fake Jira issue) and a canned reasoner (stub-claude.ps1). It runs real cycles of the runner through
  proposals, commands, live mode, pause/resume, failures, the bot-identity option, the search fallback and summary retry.
  Run after any change to the runner:  pwsh -File Test-EndToEnd.ps1   (about 40 s; needs pwsh and Windows PowerShell)
  All people, IDs and tickets below are fixtures. Uses the runner's test hooks SLACK_AR_STORE and SLACK_API_BASE.
#>
$ErrorActionPreference = 'Stop'
$here   = $PSScriptRoot
$root   = Join-Path ([IO.Path]::GetTempPath()) 'slack-ar-e2e'
$store  = Join-Path $root 'store'
$statef = Join-Path $root 'slack_state.json'
$runner = Join-Path (Split-Path -Parent $here) 'Invoke-SlackAutoReply.ps1'
$port   = 8799
$K = 'U08FTS2SRAP'; $CH = 'C0B0CBW8G03'      # Krishna and #my-daily-update: constants in the runner
$LABEL = 'KrishnaAiGen'
Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $store, "$root\fake-wdctx", "$root\fake-repo" | Out-Null

$script:pass = 0; $script:fail = 0; $script:seq = 0
function Check($ok, $msg) { if ($ok) { $script:pass++ } else { $script:fail++; Write-Host "  FAIL: $msg" -ForegroundColor Red } }
function Section($t) { Write-Host "`n== $t" -ForegroundColor Cyan }
function LoadS { for ($i = 0; $i -lt 40; $i++) { try { return (Get-Content $statef -Raw | ConvertFrom-Json -AsHashtable) } catch { Start-Sleep -Milliseconds 50 } }; throw 'slack_state.json locked' }
function SaveS($s) { $json = $s | ConvertTo-Json -Depth 30; for ($i = 0; $i -lt 40; $i++) { try { [IO.File]::WriteAllText($statef, $json, [Text.UTF8Encoding]::new($false)); return } catch { Start-Sleep -Milliseconds 50 } }; throw 'slack_state.json locked' }
function NowS { [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
function AddMsg($s, $ch, $user, $text, $ageSec, $threadTs = $null, $extra = @{}) {
  $script:seq++
  $m = @{ ts = ('{0}.{1:000000}' -f ((NowS) - $ageSec), (900000 + $script:seq)); user = $user; text = $text }
  if ($threadTs) { $m.thread_ts = $threadTs }
  foreach ($k in $extra.Keys) { $m[$k] = $extra[$k] }
  if (-not $s.channels.ContainsKey($ch)) { $s.channels[$ch] = @() }
  $s.channels[$ch] = @($s.channels[$ch]) + @($m)
  $m.ts
}
function AddUser($s, $p) { $s.users[$p.u] = @{ real_name = $p.n; name = ($p.n -replace ' ', '.').ToLower(); title = $p.t; is_bot = $false } }
function LoadState { Get-Content "$store\state.json" -Raw | ConvertFrom-Json -AsHashtable }
function SaveState($st) { $st | ConvertTo-Json -Depth 8 | Set-Content "$store\state.json" -Encoding utf8 }
function RunRunner([string[]]$a = @(), [switch]$NoUserToken) {
  $env:SLACK_AR_STORE = $store; $env:SLACK_API_BASE = "http://127.0.0.1:$port"; $env:SLACK_BOT_TOKEN = 'xoxb-test'
  $env:JIRA_EMAIL = 'fixture@example.com'; $env:JIRA_API_TOKEN = 'fixture'; $env:JIRA_BASE_URL = "http://127.0.0.1:$port"
  $env:SLACK_USER_TOKEN = if ($NoUserToken) { '' } else { 'xoxp-test' }
  $out = & pwsh -NoProfile -ExecutionPolicy Bypass -File $runner @a 2>&1 | Out-String
  [pscustomobject]@{ out = $out; code = $LASTEXITCODE }
}
function UserPosts($s, $chLike = '*') { @($s.posts | Where-Object { $_.token -eq 'user' -and $_.channel -like $chLike }) }
function BotPosts($s, $chLike = '*') { @($s.posts | Where-Object { $_.token -eq 'bot' -and $_.channel -like $chLike }) }
function RunDirs { @(Get-ChildItem "$store\runs" -Directory -ErrorAction SilentlyContinue).Count }
function AllLogs { (Get-ChildItem "$store\logs" -Filter 'cycle_*.log' | Sort-Object Name | ForEach-Object { Get-Content $_.FullName -Raw }) -join "`n" }
function EpisodeFor($st, $dmId) { $e = $st.handled.GetEnumerator() | Where-Object { $_.Value.dm -eq $dmId } | Select-Object -First 1; if ($e) { [pscustomobject]@{ key = $e.Key; entry = $e.Value } } }
function SummaryFor($s, $st, $dmId) {   # the summary text for a DM's tracked episode
  $e = EpisodeFor $st $dmId
  if (-not $e) { return $null }
  $m = @($s.channels[$CH] | Where-Object { $_.ts -eq $e.entry.summary_ts }) | Select-Object -First 1
  [pscustomobject]@{ key = $e.key; entry = $e.entry; text = $m.text }
}

# ---------- fixtures: fake people (u = Slack user ID, d = DM ID, t = Slack title, p = persona policy; no p = not in persona.md) ----------
$ppl = @{
  alice  = @{ n = 'Alice Answers'; u = 'UTESTALICE1'; d = 'DTESTALICE1'; t = 'SDET'; p = 'answers-ok' }
  bob    = @{ n = 'Bob Standing'; u = 'UTESTBOB001'; d = 'DTESTBOB001'; t = 'Software Engineer'; p = 'answers-ok' }
  priya  = @{ n = 'Priya Product'; u = 'UTESTPRIYA1'; d = 'DTESTPRIYA1'; t = 'Product Manager'; p = 'away-only' }
  lena   = @{ n = 'Lena Lead'; u = 'UTESTLENA01'; d = 'DTESTLENA01'; t = 'Team Lead'; p = 'references-ok' }
  eve    = @{ n = 'Eve Engmgr'; u = 'UTESTEVE001'; d = 'DTESTEVE001'; t = 'Engineering Manager'; p = 'away-only' }
  sam    = @{ n = 'Sam Senior'; u = 'UTESTSAM001'; d = 'DTESTSAM001'; t = 'Senior Engineer'; p = 'away-only' }
  rita   = @{ n = 'Rita Release'; u = 'UTESTRITA01'; d = 'DTESTRITA01'; t = 'Release Coordinator'; p = 'answers-ok' }
  hana   = @{ n = 'Hana HR'; u = 'UTESTHANA01'; d = 'DTESTHANA01'; t = 'HR'; p = 'never' }
  fay    = @{ n = 'Fay Fails'; u = 'UTESTFAY001'; d = 'DTESTFAY001'; t = ''; p = 'answers-ok' }
  una    = @{ n = 'Una Unsafe'; u = 'UTESTUNA001'; d = 'DTESTUNA001'; t = ''; p = 'answers-ok' }
  pat    = @{ n = 'Pat Personal'; u = 'UTESTPAT001'; d = 'DTESTPAT001'; t = ''; p = 'answers-ok' }
  dan    = @{ n = 'Dan Director'; u = 'UTESTDAN001'; d = 'DTESTDAN001'; t = 'Director of Engineering' }
  newbie = @{ n = 'Newbie Test'; u = 'UTESTNEW001'; d = 'DTESTNEW001'; t = '' }
  paula  = @{ n = 'Paula Pause'; u = 'UTESTPAU001'; d = 'DTESTPAU001'; t = '' }
  bo     = @{ n = 'Bo Bot'; u = 'UTESTBOT001'; d = 'DTESTBOT001'; t = '' }
  dee    = @{ n = 'Dee Dry'; u = 'UTESTDEE001'; d = 'DTESTDEE001'; t = '' }
  cy     = @{ n = 'Cy Cool'; u = 'UTESTCY0001'; d = 'DTESTCY0001'; t = '' }
  rey    = @{ n = 'Rey Retry'; u = 'UTESTREY001'; d = 'DTESTREY001'; t = '' }
}
$rows = foreach ($p in $ppl.Values) { if ($p.p) { "| $($p.n) | $($p.u) | $($p.d) | fixture | | $($p.p) | |" } }
Set-Content "$store\persona.md" (@('# Persona map (TEST FIXTURE: fake people)', '| Person | Slack ID | DM | Relation | Address | Policy | Notes |', '|---|---|---|---|---|---|---|') + $rows) -Encoding utf8
Set-Content "$store\exceptions.md" "# exceptions (fixture)`n" -Encoding utf8
$s0 = @{ seq = 0; channels = @{}; users = @{}; posts = @(); updates = @(); calls = @(); fail_history = @(); search_error = ''; krishna_status = @{ status_text = ''; status_expiration = 0 } }
$s0.channels[$CH] = @()
foreach ($p in $ppl.Values) { AddUser $s0 $p }
SaveS $s0
Copy-Item (Join-Path $here 'stub-claude.ps1') "$root\stub-claude.ps1"

$stub = Start-Process pwsh -ArgumentList '-NoProfile', '-File', (Join-Path $here 'stub-slack.ps1'), '-Port', $port, '-StateFile', $statef -PassThru -WindowStyle Hidden
try {
  $ok = $false
  for ($i = 0; $i -lt 40; $i++) { try { if ((Invoke-RestMethod "http://127.0.0.1:$port/ping").ok) { $ok = $true; break } } catch { Start-Sleep -Milliseconds 250 } }
  if (-not $ok) { throw 'stub Slack did not start' }

  Section '0. -Init and control switches (bot token only)'
  $r = RunRunner @('-Init'); Check ($r.code -eq 0) "-Init exit code $($r.code): $($r.out)"
  $cfgPath = "$store\config.json"; Check (Test-Path $cfgPath) 'config.json written'
  $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
  Check ($cfg.dm_due_minutes -eq 30 -and $cfg.reply_identity -eq 'user' -and $cfg.channel_due_minutes -eq 60 -and $cfg.channel_mentions_enabled -eq $false -and $cfg.repropose_after_minutes -eq 120) 'config defaults'
  $s = LoadS; $arMsg = $s.channels[$CH][0]
  Check ($arMsg.text -match 'mode_away=shadow' -and $arMsg.text -match 'mode_answer=shadow') "AR-STATE starts in proposal mode: $($arMsg.text)"
  Check ($s.channels[$CH][1].text -match '`live`') 'control thread lists the live command'
  $cfg.claude_path = "$root\stub-claude.ps1"; $cfg.wd_context_dir = "$root\fake-wdctx"; $cfg.unify_repo = "$root\fake-repo"; $cfg.max_claude_calls_per_cycle = 10
  $cfg | ConvertTo-Json | Set-Content $cfgPath -Encoding utf8
  $r = RunRunner @('-Status') -NoUserToken; Check ($r.code -eq 0 -and $r.out -match 'mode_away=shadow') "-Status works without the user token: $($r.out)"
  $r = RunRunner @() -NoUserToken; Check ($r.code -eq 1 -and $r.out -match 'SLACK_USER_TOKEN is not set') 'a normal cycle without the user token stops with a clear message'
  $baseline = (LoadS).posts.Count

  Section '1. First cycle, proposal mode'
  $s = LoadS
  AddMsg $s $ppl.alice.d $ppl.alice.u 'WHICHBUILD has the UD-10001 fix? mail me at alice.test@example.com' 2700 | Out-Null
  AddMsg $s $ppl.bob.d $ppl.bob.u 'ESCALATE the customer call is urgent' 2700 | Out-Null
  AddMsg $s $ppl.priya.d $ppl.priya.u 'ETA for UD-10001?' 2700 | Out-Null
  AddMsg $s $ppl.lena.d $ppl.lena.u 'WHERENODE for the shipped items?' 3000 | Out-Null
  AddMsg $s $ppl.eve.d $ppl.eve.u 'hi' 120 | Out-Null                                              # still typing
  AddMsg $s $ppl.rita.d $ppl.rita.u 'hello (not due yet)' 600 | Out-Null                           # not due
  AddMsg $s $ppl.sam.d $ppl.sam.u '[wd-context] Q-sam-1 please answer' 3000 | Out-Null
  AddMsg $s $ppl.hana.d $ppl.hana.u 'reminder: submit your timesheet' 3000 | Out-Null
  AddMsg $s $ppl.dan.d $ppl.dan.u 'Hi Krishna, ESCALATE: can you join the customer call now' 2700 | Out-Null   # not in persona; Director title
  AddMsg $s $ppl.fay.d $ppl.fay.u 'hello (history will fail)' 2700 | Out-Null
  AddMsg $s $ppl.una.d $ppl.una.u 'UNSAFE question' 2700 | Out-Null
  AddMsg $s $ppl.pat.d $ppl.pat.u 'PERSONALCHAT my appraisal rating has me stressed' 2700 | Out-Null   # reasoner says SILENT: must not be quoted
  $s.fail_history = @($ppl.fay.d); SaveS $s
  $r = RunRunner; Check ($r.code -eq 0) "cycle exit $($r.code): $($r.out)"
  $s = LoadS; $st = LoadState
  Check ((UserPosts $s).Count -eq 0) 'nothing sent as Krishna in proposal mode'
  Check (@($s.posts | Where-Object { $_.channel -like 'D*' }).Count -eq 0) 'no post went to any DM'
  Check ((RunDirs) -eq 7) "7 reasoner calls expected (Alice, Bob, Priya, Lena, Dan, Una, Pat), got $(RunDirs)"
  $newBot = @(BotPosts $s $CH).Count - $baseline
  Check ($newBot -eq 9) "9 summaries expected (6 proposals + reasoner-SILENT + wd-context + never), got $newBot"
  Check ($st.handled.Count -eq 9) "9 tracked episodes, got $($st.handled.Count)"
  Check (@($st.handled.Values | Where-Object { $_.pending_msg }).Count -eq 6) '6 proposals waiting'
  $ali = SummaryFor $s $st $ppl.alice.d
  Check ($ali.text -match 'proposal, nothing sent' -and $ali.text -match 'Proposed reply \(not sent\)' -and $ali.text -match $LABEL) 'Alice summary shows the proposal'
  Check ($ali.text -match "UD-10001 is 'In Test'") 'the Jira fact reached the evidence and the proposed answer'
  Check ($ali.text -match '\[email\]' -and $ali.text -notmatch 'alice\.test@example\.com') 'summary redacts the email in the quoted message'
  Check ($ali.entry.pending_msg -match '_ref AR-DTESTALICE1-' -and $ali.entry.pending_msg -match "He'll get back to you himself") 'pending message carries marker and closing'
  $bob = SummaryFor $s $st $ppl.bob.d
  Check ($bob.entry.pending_msg -match 'night support') 'answers-ok person gets the standing night-support line'
  $pri = SummaryFor $s $st $ppl.priya.d
  Check ($pri.entry.type -eq 'AWAY_ONLY' -and $pri.entry.pending_msg -notmatch 'tomorrow' -and $pri.entry.pending_msg -match 'Krishna is') 'PM (away-only): answer cut, bare away note'
  $len = SummaryFor $s $st $ppl.lena.d
  Check ($len.entry.type -eq 'REFERENCES' -and $len.entry.pending_msg -match 'team memories') 'references-ok person: ANSWER cut to REFERENCES'
  $dan = SummaryFor $s $st $ppl.dan.d
  Check ($dan.entry.type -eq 'AWAY_ONLY' -and $dan.entry.pending_msg -notmatch 'night support') 'unlisted Director (title rule) gets the bare away note'
  $una = SummaryFor $s $st $ppl.una.d
  Check ($una.entry.type -eq 'AWAY_ONLY' -and $una.entry.pending_msg -notmatch 'evil\.example\.com|hunter2') 'unsafe body is dropped and downgraded'
  $sam = SummaryFor $s $st $ppl.sam.d; Check ($sam.entry.type -eq 'SILENT' -and $sam.text -match 'wd-context') 'wd-context DM is SILENT'
  $hana = SummaryFor $s $st $ppl.hana.d; Check ($hana.entry.type -eq 'SILENT' -and $hana.text -match 'no-reply person' -and $hana.entry.silent_policy) 'never-person is SILENT'
  $pat = SummaryFor $s $st $ppl.pat.d
  Check ($pat.entry.type -eq 'SILENT' -and -not $pat.entry.pending_msg -and $pat.text -notmatch 'Their message' -and $pat.text -notmatch 'appraisal') 'a personal DM the reasoner calls SILENT is recorded without quoting it'
  Check ($null -eq (SummaryFor $s $st $ppl.eve.d) -and $null -eq (SummaryFor $s $st $ppl.rita.d)) 'typing and not-yet-due DMs are left alone'
  Check ((AllLogs) -match "DM $($ppl.fay.d) failed") 'a failing DM is logged and does not stop the others'
  Check (@($s.updates | Where-Object { $_.text -match 'heartbeat=\d{9,}' }).Count -ge 1) 'heartbeat written to AR-STATE'

  Section '2. Second cycle immediately: no duplicates'
  $callsBefore = (LoadS).posts.Count; $dirsBefore = RunDirs
  $r = RunRunner; $s = LoadS
  Check ($s.posts.Count -eq $callsBefore) "no new posts, got $($s.posts.Count - $callsBefore)"
  Check ((RunDirs) -eq $dirsBefore) 'no new reasoner calls'

  Section '3. Commands: send / send! / stale / live / noise'
  $s = LoadS; $st = LoadState
  $arTs = $cfg.state_message_ts
  $sumAli = (SummaryFor $s $st $ppl.alice.d).entry.summary_ts; $sumLen = (SummaryFor $s $st $ppl.lena.d).entry.summary_ts
  $sumPri = (SummaryFor $s $st $ppl.priya.d).entry.summary_ts; $sumBob = (SummaryFor $s $st $ppl.bob.d).entry.summary_ts
  AddMsg $s $CH $K 'send' 5 $sumAli | Out-Null
  AddMsg $s $ppl.lena.d $K 'Hey, looking at it now' 600 | Out-Null                    # Krishna wrote in Lena's DM after the ask
  AddMsg $s $CH $K 'send' 5 $sumLen | Out-Null
  AddMsg $s $CH $K 'send!' 4 $sumLen | Out-Null
  AddMsg $s $CH $K 'send' 5 $sumPri | Out-Null
  AddMsg $s $CH $K 'live' 5 $arTs | Out-Null
  AddMsg $s $CH $K 'bogus command' 4 $arTs | Out-Null
  AddMsg $s $CH $K 'send' 5 $sumBob -extra @{ bot_id = 'B123' } | Out-Null            # from a bot: ignored
  AddMsg $s $CH $ppl.alice.u 'send' 5 $sumBob | Out-Null                              # someone else: ignored
  AddMsg $s $CH $K "send`n`n_Sent using_ Claude" 5 $sumBob | Out-Null                 # AI-posted footer: ignored
  AddMsg $s $ppl.rita.d $ppl.rita.u 'WHICHBUILD please, it is urgent' 2700 | Out-Null    # live auto-send target
  SaveS $s
  $st.handled[(SummaryFor $s $st $ppl.priya.d).key].at = (NowS) - 13 * 3600; SaveState $st     # make Priya's proposal 13 h old
  $r = RunRunner; Check ($r.code -eq 0) "cycle exit $($r.code): $($r.out)"
  $s = LoadS; $st = LoadState
  $up = UserPosts $s
  $aliPost = @($up | Where-Object { $_.channel -eq $ppl.alice.d }); Check ($aliPost.Count -eq 1 -and $aliPost[0].text -match $LABEL -and $aliPost[0].text -match 'UD-10001') 'send: Alice got exactly the proposed reply'
  $lenPost = @($up | Where-Object { $_.channel -eq $ppl.lena.d }); Check ($lenPost.Count -eq 1 -and $lenPost[0].text -match 'team memories') 'send! delivered Lena proposal after the "already wrote" warning'
  Check (@($up | Where-Object { $_.channel -eq $ppl.priya.d }).Count -eq 0) 'stale (13 h) proposal not sent by plain send'
  Check (@($up | Where-Object { $_.channel -eq $ppl.bob.d }).Count -eq 0) 'bot / other-user / "Sent using" commands ignored'
  $rit = @($up | Where-Object { $_.channel -eq $ppl.rita.d }); Check ($rit.Count -eq 1 -and $rit[0].text -match 'UD-10001' -and $rit[0].text -match $LABEL -and $rit[0].text -match '_ref AR-DTESTRITA01-') 'live mode: Rita got the full reply (away note + answer + marker) automatically'
  $acks = @(BotPosts $s $CH | Where-Object { $_.thread_ts } | ForEach-Object text)
  Check (($acks -match 'not sent: you have already written in that DM').Count -eq 1) 'ack: not sent because Krishna already wrote'
  Check (($acks -match 'not sent: the proposal is over 12 hours old').Count -eq 1) 'ack: not sent because the proposal is stale'
  Check (($acks -match 'not understood').Count -ge 1) 'ack: unknown command is reported'
  Check (($acks -match 'live: away notes and answers now go to people').Count -eq 1) 'ack: live'
  $arNow = @($s.channels[$CH] | Where-Object { $_.ts -eq $arTs })[0].text
  Check ($arNow -match 'mode_away=live' -and $arNow -match 'mode_answer=live') "AR-STATE is live: $arNow"
  Check (-not (SummaryFor $s $st $ppl.alice.d).entry.pending_msg -and (SummaryFor $s $st $ppl.alice.d).entry.sent_ts) 'sent proposal is cleared and marked sent'
  Check ((SummaryFor $s $st $ppl.priya.d).entry.pending_msg) 'stale proposal stays pending'
  Check ((SummaryFor $s $st $ppl.dan.d).entry.pending_msg -and -not (SummaryFor $s $st $ppl.dan.d).entry.sent_ts) 'old proposals are not auto-sent when switching to live'
  $ritSum = SummaryFor $s $st $ppl.rita.d; Check ($ritSum.text -match '\*DM auto-reply · sent\*' -and $ritSum.text -match '\*Sent:\*') 'summary for the automatic send says sent'

  Section '4. Re-run: nothing is sent twice'
  $up1 = (UserPosts (LoadS)).Count; $dirs1 = RunDirs
  $r = RunRunner; $s = LoadS
  Check ((UserPosts $s).Count -eq $up1) 'no duplicate sends'
  Check ((RunDirs) -eq $dirs1) 'no new reasoner calls'

  Section '5. Reasoner failure: alert once, no send, retried later'
  $s = LoadS; AddMsg $s $ppl.newbie.d $ppl.newbie.u 'FAILREASONER hello' 2700 | Out-Null; SaveS $s
  $r = RunRunner; $s = LoadS
  $alerts = @($s.posts | Where-Object { $_.text -match 'reasoning step failed' }); Check ($alerts.Count -eq 1) "one alert, got $($alerts.Count)"
  Check (@(UserPosts $s $ppl.newbie.d).Count -eq 0) 'nothing sent when the reasoner fails'
  $r = RunRunner; $s = LoadS
  Check (@($s.posts | Where-Object { $_.text -match 'reasoning step failed' }).Count -eq 1) 'alert is throttled'
  Check ($null -eq (EpisodeFor (LoadState) $ppl.newbie.d)) 'a failed episode is not recorded, so it is retried'
  $s = LoadS; AddMsg $s $ppl.newbie.d $K 'sorry, will check' 5 | Out-Null; SaveS $s    # Krishna answers himself: episode over

  Section '6. Pause and resume from the AR-STATE thread'
  $s = LoadS; AddMsg $s $CH $K 'pause' 3 $arTs | Out-Null; AddMsg $s $ppl.paula.d $ppl.paula.u 'WHICHBUILD while paused' 2700 | Out-Null; SaveS $s
  $dirs1 = RunDirs; $r = RunRunner; $s = LoadS
  Check ((RunDirs) -eq $dirs1 -and @(UserPosts $s $ppl.paula.d).Count -eq 0) 'nothing happens while paused'
  Check ((@($s.channels[$CH] | Where-Object { $_.ts -eq $arTs })[0].text) -match 'paused=yes') 'AR-STATE shows paused'
  $s = LoadS; AddMsg $s $CH $K 'resume' 3 $arTs | Out-Null; SaveS $s
  $r = RunRunner; $s = LoadS
  Check (@(UserPosts $s $ppl.paula.d).Count -eq 1) 'after resume the waiting DM is handled'

  Section '7. reply_identity = bot'
  $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json; $cfg.reply_identity = 'bot'; $cfg | ConvertTo-Json | Set-Content $cfgPath -Encoding utf8
  $s = LoadS; AddMsg $s $ppl.bo.d $ppl.bo.u 'WHICHBUILD via the app' 2700 | Out-Null; SaveS $s
  $r = RunRunner; $s = LoadS
  Check (@(UserPosts $s $ppl.bo.d).Count -eq 0) 'bot identity: nothing posted as Krishna in the original DM'
  $viaBot = @(BotPosts $s 'DBOTTEST1' | Where-Object { $_.text -match $LABEL }); Check ($viaBot.Count -eq 1 -and $viaBot[0].text -match 'UD-10001') 'bot identity: reply came from the app in its own DM'
  $r = RunRunner; $s = LoadS
  Check (@(BotPosts $s 'DBOTTEST1' | Where-Object { $_.text -match $LABEL }).Count -eq 1) 'bot identity: no second send (state, not the marker, closes the episode)'
  $cfg.reply_identity = 'user'; $cfg | ConvertTo-Json | Set-Content $cfgPath -Encoding utf8

  Section '8. -Shadow dry run makes no Slack writes'
  $s = LoadS; AddMsg $s $ppl.dee.d $ppl.dee.u 'WHICHBUILD dry run' 2700 | Out-Null; SaveS $s
  $s = LoadS; $p1 = $s.posts.Count; $u1 = $s.updates.Count
  $r = RunRunner @('-Shadow'); $s = LoadS
  Check ($s.posts.Count -eq $p1 -and $s.updates.Count -eq $u1) 'no posts and no AR-STATE updates in a dry run'
  Check ($r.out -match "\[dry run\] $($ppl.dee.n)") "dry run prints what it would do: $($r.out)"

  Section '9. Slack search unavailable: persona DMs are still checked'
  $pp = Get-Content "$store\persona.md" -Raw; Set-Content "$store\persona.md" ($pp.TrimEnd() + "`n| $($ppl.dee.n) | $($ppl.dee.u) | $($ppl.dee.d) | fixture | | answers-ok | |`n") -Encoding utf8
  $s = LoadS; $s.search_error = 'missing_scope'; SaveS $s
  $r = RunRunner; $s = LoadS
  Check ((AllLogs) -match 'search\.messages failed') 'search failure is logged and does not stop the cycle'
  Check (@(UserPosts $s $ppl.dee.d).Count -eq 1) 'the DM listed in persona.md was still found and answered'
  $s.search_error = ''; SaveS $s

  Section '10. Proposal cooling, -Mode and -Pause/-Resume switches'
  $r = RunRunner @('-Mode', 'shadow') -NoUserToken; Check ($r.code -eq 0 -and $r.out -match 'mode_away=shadow \| mode_answer=shadow') "-Mode shadow: $($r.out)"
  $s = LoadS; AddMsg $s $ppl.cy.d $ppl.cy.u 'WHICHBUILD cooling' 2700 | Out-Null; SaveS $s
  $r = RunRunner; $s = LoadS; $st = LoadState
  $cool = SummaryFor $s $st $ppl.cy.d; Check ($cool.entry.pending_msg -and -not $cool.entry.sent_ts) 'proposal posted, nothing sent'
  $b1 = @(BotPosts $s $CH).Count; $d1 = RunDirs
  $s = LoadS; AddMsg $s $ppl.cy.d $ppl.cy.u 'any update?' 400 | Out-Null; SaveS $s
  $r = RunRunner; $s = LoadS
  Check (@(BotPosts $s $CH).Count -eq $b1 -and (RunDirs) -eq $d1) 'a new message right after a proposal does not trigger another proposal'
  $st = LoadState; $st.handled[(SummaryFor $s $st $ppl.cy.d).key].at = (NowS) - 3 * 3600; SaveState $st
  $r = RunRunner; $s = LoadS
  Check (@(BotPosts $s $CH).Count -eq $b1 + 1 -and (RunDirs) -eq $d1 + 1) 'after the cooling period a new proposal is made'
  $r = RunRunner @('-Pause', '2h') -NoUserToken; Check ($r.out -match 'paused=until=\d+') "-Pause 2h: $($r.out)"
  $r = RunRunner @('-Resume') -NoUserToken; Check ($r.out -match 'paused=no') "-Resume: $($r.out)"
  $r = RunRunner @('-Status') -NoUserToken; Check ($r.out -match 'Proposals waiting for you: \d+' -and $r.out -match 'replies go out as: user') "-Status summary line: $($r.out)"

  Section '11. A summary that fails to post is retried (nothing is lost)'
  $s = LoadS; AddMsg $s $ppl.rey.d $ppl.rey.u 'WHICHBUILD retry' 2700 | Out-Null; $s.fail_summary_posts = 1; SaveS $s
  $d1 = RunDirs; $r = RunRunner; $s = LoadS; $st = LoadState
  $ret = (EpisodeFor $st $ppl.rey.d).entry
  Check ($ret -and $ret.summary_text -and -not $ret.summary_ts) 'episode recorded with its summary text pending'
  Check ((AllLogs) -match 'not posted yet') 'the failed post is logged'
  Check (@(BotPosts $s $CH | Where-Object { $_.text -match $ppl.rey.n }).Count -eq 0) 'no summary yet'
  $r = RunRunner; $s = LoadS; $st = LoadState
  $ret = (EpisodeFor $st $ppl.rey.d).entry
  Check (@(BotPosts $s $CH | Where-Object { $_.text -match $ppl.rey.n }).Count -eq 1) 'summary posted on the next cycle'
  Check ($ret.summary_ts -and -not $ret.summary_text) 'summary_ts stored, pending text cleared'
  Check ((RunDirs) -eq $d1 + 1) 'the reasoner was not called a second time'
}
finally {
  if ($stub -and -not $stub.HasExited) { Stop-Process -Id $stub.Id -Force }
  Remove-Item Env:SLACK_AR_STORE, Env:SLACK_API_BASE, Env:SLACK_BOT_TOKEN, Env:SLACK_USER_TOKEN, Env:JIRA_EMAIL, Env:JIRA_API_TOKEN, Env:JIRA_BASE_URL -ErrorAction SilentlyContinue
}
Write-Host ("`nE2E: {0} passed, {1} failed" -f $script:pass, $script:fail) -ForegroundColor $(if ($script:fail) { 'Red' } else { 'Green' })
if ($script:fail) { Write-Host "Kept for inspection: $root"; exit 1 }
Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
