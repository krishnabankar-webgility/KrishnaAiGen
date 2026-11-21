# Stand-in for `claude -p ... --output-format json`: reads evidence.json in the current folder and returns a canned decision.
# The trigger words (WHICHBUILD, ESCALATE, ...) are in the fixture DMs written by Test-EndToEnd.ps1.
param([Parameter(ValueFromRemainingArguments = $true)]$rest)
$joined = $rest -join ' '
if ($joined -match 'private-research step') {   # the second, connector-enabled step (Invoke-Research)
  if ($joined -match 'RESEARCHFAIL') { @{ is_error = $true; subtype = 'error_during_execution'; result = '' } | ConvertTo-Json -Compress; return }
  $r = [ordered]@{ found = $false; exact_body = ''; sources = @(); notes = '' }
  if ($joined -match 'RESEARCHBAD') { $r.found = $true; $r.exact_body = 'The admin password is hunter2.'; $r.sources = @(@{ class = 'gmail'; where = 'a thread' }) }
  elseif ($joined -match 'LEAKME') { $r.found = $true; $r.exact_body = 'Fixture exact answer: the report is in the Q3 folder of the shared drive.'; $r.sources = @(@{ class = 'drive'; where = 'Q3 folder' }) }
  elseif ($joined -match 'RESEARCHME') { $r.found = $true; $r.exact_body = 'Fixture exact answer: the report is in the Q3 folder of the shared drive.'; $r.sources = @(@{ class = 'drive'; where = 'Q3 folder' }, @{ class = 'slack-private'; where = 'a private chat' }); $r.notes = 'medium confidence' }
  @{ is_error = $false; result = ($r | ConvertTo-Json -Compress); session_id = 'stub' } | ConvertTo-Json -Compress; return
}
if ($joined -match 'technical-analysis step') {   # the code-reading analysis step (Invoke-Analysis)
  if ($joined -match 'ANALYSISFAIL') { @{ is_error = $true; subtype = 'error_during_execution'; result = '' } | ConvertTo-Json -Compress; return }
  $r = [ordered]@{ answered = $true; confidence = 'high'; body = 'The posting flow reads the node in the order controller before it builds the lines.'; basis = 'fixture: OrderController.cs' }
  if ($joined -match 'ANALYSISLOW') { $r.confidence = 'low' }
  elseif ($joined -match 'ANALYSISUNKNOWN') { $r.answered = $false; $r.body = '' }
  elseif ($joined -match 'ANALYSISBAD') { $r.body = 'See password hunter2 in the config.' }
  @{ is_error = $false; result = ($r | ConvertTo-Json -Compress); session_id = 'stub' } | ConvertTo-Json -Compress; return
}
if ($joined -match 'slack-auto-reply job: (FIX|ANALYSIS|SHIP)') {   # a Run-ArJob.ps1 session: report stages with the status helper like the real one does
  $kind = $Matches[1]
  $m = [regex]::Match($joined, '-File "([^"]+Write-JobStatus\.ps1)" -JobDir "([^"]+)"'); $ss = $m.Groups[1].Value; $jd = $m.Groups[2].Value
  $reqText = Get-Content (Join-Path $jd 'request.json') -Raw
  if ($reqText -match 'SLEEPLONG') { Start-Sleep 90 }
  if ($kind -eq 'SHIP') {   # a branch the web session pushed: review, build and test, then ship
    & $ss -JobDir $jd -Stage analysis_done -Next building -Note 'Reviewed the pushed branch.' | Out-Null
    Start-Sleep 1
    & $ss -JobDir $jd -Stage fixed_and_tested -Next 'ship-to-qa' -Note 'Built and tested on the PC.' -Refs 'branch UD-777_Krishna' | Out-Null
    & $ss -JobDir $jd -Stage shipped -Next 'QA to test the build' -Note 'Build shared.' -Refs 'build 4321' | Out-Null
  }
  elseif ($kind -eq 'FIX') {
    & $ss -JobDir $jd -Stage analysis_done -Next fixing -Note 'Root cause found in the stub.' | Out-Null
    Start-Sleep 1
    & $ss -JobDir $jd -Stage fixed_and_tested -Next 'ship-to-qa' -Note 'Fixed and tested together.' -Refs 'branch UD-1_Krishna' | Out-Null
    & $ss -JobDir $jd -Stage shipped -Next 'QA to test the build' -Note 'Build shared.' -Refs 'build 1234' | Out-Null
  } else {
    & $ss -JobDir $jd -Stage analysis_done -Next 'reply fix KrishnaAiGen to start the fix' -Note 'The ask is true.' -Reply 'Yes, this is a known case.' -Refs 'UD-1' | Out-Null
  }
  @{ is_error = $false; result = 'stub job finished'; session_id = 'stub'; num_turns = 3; total_cost_usd = 0 } | ConvertTo-Json -Compress; return
}
$ev = Get-Content (Join-Path (Get-Location) 'evidence.json') -Raw | ConvertFrom-Json
$text = (@($ev.conversation | Where-Object { $_.in_episode } | ForEach-Object { $_.text }) -join ' ')
$first = ([string]$ev.partner.name).Split(' ')[0]
$d = [ordered]@{ category = 'stub'; type = 'AWAY_ONLY'; greeting = "Hi $first,"; body = ''; asked = "stub: asked something ($($ev.partner.name))"; evidence = @(); proposed_rule = ''; needs_research = $false; search_terms = @(); needs_slack_check = $false; slack_terms = @(); needs_analysis = $false; analysis_question = ''; urgency = 'low'; importance = 'low'; criticality = 'low' }
if ($text -match 'RESEARCHME|RESEARCHBAD|RESEARCHFAIL|LEAKME') { $d.needs_research = $true; $d.search_terms = @('q3', 'report') }
if ($text -match 'LEAKME') { $d.type = 'ANSWER'; $d.body = 'the report is in the Q3 folder' }
if ($text -match 'TAGCHECK') {
  if ($ev.second_pass) { $names = (@($ev.slack_facts | ForEach-Object { $_.text }) -join ' '); $d.type = 'ANSWER'; $d.body = $(if ($names -match '@Tanay Test') { 'Yes, Tanay is tagged in that post.' } else { 'I could not confirm it.' }); $d.asked = 'was Tanay tagged' }
  else { $d.type = 'AWAY_ONLY'; $d.needs_slack_check = $true; $d.slack_terms = @('uptake', 'ticket'); $d.asked = 'was Tanay tagged' }
}
if ($text -match 'GREETME') { $d.type = 'GREETING'; $d.greeting = "GM $first,"; $d.body = ''; $d.asked = 'a greeting' }
if ($text -match 'ANALYSE') {
  $d.type = 'CONDITIONAL'; $d.body = 'I am not sure; Krishna will confirm.'; $d.needs_analysis = $true; $d.analysis_question = 'how does posting read the node'
  if ($text -match 'URGENT') { $d.urgency = 'high'; $d.importance = 'high' } elseif ($text -match 'CRIT') { $d.criticality = 'high' } elseif ($text -match 'MEDIUMQ') { $d.urgency = 'medium'; $d.importance = 'medium' }
}
if ($text -match 'FAILREASONER') {
  @{ is_error = $true; subtype = 'error_during_execution'; result = '' } | ConvertTo-Json -Compress; return
}
if ($text -match 'PERSONALCHAT') {
  $d.type = 'SILENT'; $d.asked = 'personal matter (no detail)'
}
elseif ($text -match 'WHICHBUILD') {
  $st = if (@($ev.facts.jira).Count) { $ev.facts.jira[0].status } else { 'unknown' }
  $d.type = 'ANSWER'; $d.body = "UD-10001 is '$st' in Jira. https://webgility.atlassian.net/browse/UD-10001"; $d.evidence = @("Jira UD-10001: $st")
}
elseif ($text -match 'WHERENODE') { $d.type = 'ANSWER'; $d.body = 'The node is described in the team memories for that ticket.' }
elseif ($text -match 'ESCALATE')  { $d.type = 'AWAY_ONLY'; $d.body = 'for immediate help please reach night support; otherwise raise a ticket with the DB/log backup and a sample order.' }
elseif ($text -match 'UNSAFE')    { $d.type = 'ANSWER'; $d.body = 'Look here https://evil.example.com/steal and use password hunter2' }
elseif ($text -match 'ETA')       { $d.type = 'ANSWER'; $d.body = 'It will be done by tomorrow.' }
@{ is_error = $false; result = ($d | ConvertTo-Json -Compress); session_id = 'stub' } | ConvertTo-Json -Compress
