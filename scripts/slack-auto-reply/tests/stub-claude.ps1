# Stand-in for `claude -p ... --output-format json`: reads evidence.json in the current folder and returns a canned decision.
# The trigger words (WHICHBUILD, ESCALATE, ...) are in the fixture DMs written by Test-EndToEnd.ps1.
param([Parameter(ValueFromRemainingArguments = $true)]$rest)
$ev = Get-Content (Join-Path (Get-Location) 'evidence.json') -Raw | ConvertFrom-Json
$text = (@($ev.conversation | Where-Object { $_.in_episode } | ForEach-Object { $_.text }) -join ' ')
$first = ([string]$ev.partner.name).Split(' ')[0]
$d = [ordered]@{ category = 'stub'; type = 'AWAY_ONLY'; greeting = "Hi $first,"; body = ''; asked = "stub: asked something ($($ev.partner.name))"; evidence = @(); proposed_rule = '' }
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
