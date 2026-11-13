<#
.SYNOPSIS
  Unit checks for the pure logic in Invoke-SlackAutoReply.ps1: safety checks, the send/hold matrix, commands,
  masking, the leadership-title rule and persona lookups (against a fixture persona, never the real one).
  Run after any change to the runner:  pwsh -File Test-Unit.ps1
#>
$src = Join-Path (Split-Path -Parent $PSScriptRoot) 'Invoke-SlackAutoReply.ps1'
$errs = $null; $toks = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($src, [ref]$toks, [ref]$errs)
if ($errs.Count) { Write-Host "PARSE ERRORS: $($errs.Count)" -ForegroundColor Red; $errs | ForEach-Object { "  line $($_.Extent.StartLineNumber): $($_.Message)" }; exit 1 }
$want = 'ConvertTo-Mrkdwn', 'TsNum', 'IstTime', 'Cfg', 'Format-ArState', 'Test-Paused', 'Invoke-StateCommand', 'Resolve-Delivery', 'Test-SafeBody', 'Hide-Secrets', 'Format-Quote', 'Remove-Marker', 'Get-PersonaPolicy', 'Get-PersonaDms'
foreach ($f in $ast.FindAll({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] }, $true)) { if ($f.Name -in $want) { . ([scriptblock]::Create($f.Extent.Text)) } }
foreach ($name in 'MarkerRx', 'LeadershipRx') {   # constants: evaluate the runner's own assignment
  $a = $ast.FindAll({ param($n) $n -is [Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq "`$$name" }, $true) | Select-Object -First 1
  Set-Variable -Name $name -Value (Invoke-Expression $a.Right.Extent.Text)
}
$Store = Join-Path ([IO.Path]::GetTempPath()) 'slack-ar-unit'
New-Item -ItemType Directory -Force $Store | Out-Null
@'
| Person | Slack ID | DM | Relation | Address | Policy | Notes |
|---|---|---|---|---|---|---|
| Alice Answers | UTESTALICE1 | DTESTALICE1 | SDET | Alice | answers-ok | |
| Priya Product | UTESTPRIYA1 | DTESTPRIYA1 | PM | Priya | away-only | |
| Lena Lead | UTESTLENA01 | DTESTLENA01 | Team Lead | Lena | references-ok | |
| Hana HR | UTESTHANA01 | DTESTHANA01 | HR | | never | |
'@ | Set-Content (Join-Path $Store 'persona.md') -Encoding utf8

$script:pass = 0; $script:fail = 0
function Check($ok, $msg) { if ($ok) { $script:pass++ } else { $script:fail++; Write-Host "FAIL: $msg" -ForegroundColor Red } }

# --- Test-SafeBody
Check (Test-SafeBody '') 'empty body is safe'
Check (Test-SafeBody 'UD-10001 is In Test. See https://webgility.atlassian.net/browse/UD-10001') 'allowed Jira link'
Check (-not (Test-SafeBody 'my token: abc')) 'token: rejected'
Check (-not (Test-SafeBody 'xoxp-123-abc')) 'xox token rejected'
Check (-not (Test-SafeBody 'call +91 98765 43210')) 'phone +91 rejected'
Check (-not (Test-SafeBody 'order 1234567890')) '10-digit number rejected'
Check (-not (Test-SafeBody 'see https://evil.example.com/x')) 'foreign URL rejected'
Check (-not (Test-SafeBody 'ref AR-DTESTALICE1-1.2')) 'AR- marker text rejected'
Check (-not (Test-SafeBody ('a' * 701))) '701 chars rejected'
Check (Test-SafeBody ('a' * 700)) '700 chars allowed'
Check (-not (Test-SafeBody 'the password is x')) 'password word rejected'

# --- Resolve-Delivery: (hasAnswer, away, answer) -> plan
$matrix = @(
  @($true, 'live', 'live', 'send-full'), @($true, 'shadow', 'live', 'send-full'), @($true, 'live', 'shadow', 'send-away-hold-answer'), @($true, 'shadow', 'shadow', 'hold-full'),
  @($false, 'live', 'live', 'send-full'), @($false, 'live', 'shadow', 'send-full'), @($false, 'shadow', 'live', 'hold-full'), @($false, 'shadow', 'shadow', 'hold-full'))
foreach ($r in $matrix) { $got = Resolve-Delivery $r[0] $r[1] $r[2]; Check ($got -eq $r[3]) "Resolve-Delivery($($r[0]),$($r[1]),$($r[2])) = $got, expected $($r[3])" }

# --- Invoke-StateCommand
function NewAr { @{ mode_away = 'shadow'; mode_answer = 'shadow'; paused = 'no'; heartbeat = '0'; runner = 'none' } }
$at = 1000000
$ar = NewAr; $res = Invoke-StateCommand 'pause' $ar $at;    Check ($ar.paused -eq 'yes' -and $res) 'pause'
$ar = NewAr; $res = Invoke-StateCommand 'pause 3h' $ar $at; Check ($ar.paused -eq "until=$($at + 10800)") 'pause 3h'
$ar = NewAr; $ar.paused = 'yes'; $res = Invoke-StateCommand 'resume' $ar $at; Check ($ar.paused -eq 'no') 'resume'
foreach ($c in 'live', 'Live', 'go live', 'all live', 'responses live', 'response live') { $ar = NewAr; $res = Invoke-StateCommand $c $ar $at; Check ($ar.mode_away -eq 'live' -and $ar.mode_answer -eq 'live' -and $res) "command '$c' sets both live" }
foreach ($c in 'shadow', 'proposals', 'proposal', 'all shadow') { $ar = NewAr; $ar.mode_away = 'live'; $ar.mode_answer = 'live'; $res = Invoke-StateCommand $c $ar $at; Check ($ar.mode_away -eq 'shadow' -and $ar.mode_answer -eq 'shadow' -and $res) "command '$c' sets both shadow" }
foreach ($c in 'answers live', 'answer live', 'Answers Live') { $ar = NewAr; $res = Invoke-StateCommand $c $ar $at; Check ($ar.mode_answer -eq 'live' -and $ar.mode_away -eq 'shadow') "command '$c' only answers" }
foreach ($c in 'away live', 'away note live', 'away notes live') { $ar = NewAr; $res = Invoke-StateCommand $c $ar $at; Check ($ar.mode_away -eq 'live' -and $ar.mode_answer -eq 'shadow') "command '$c' only away" }
$ar = NewAr; $ar.mode_away = 'live'; $res = Invoke-StateCommand 'away shadow' $ar $at; Check ($ar.mode_away -eq 'shadow') 'away shadow'
foreach ($c in 'hello', 'live now', 'pause 4', 'send', '', 'go') {
  $ar = NewAr; $before = ($ar.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ','
  $res = Invoke-StateCommand $c $ar $at; $after = ($ar.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ','
  Check ($null -eq $res -and $before -eq $after) "unknown command '$c' is ignored and changes nothing"
}

# --- Test-Paused
Check (Test-Paused @{ paused = 'yes' } $at) 'paused yes'
Check (-not (Test-Paused @{ paused = 'no' } $at)) 'paused no'
Check (Test-Paused @{ paused = "until=$($at + 60)" } $at) 'paused until future'
Check (-not (Test-Paused @{ paused = "until=$($at - 60)" } $at)) 'paused until past'

# --- Hide-Secrets / Format-Quote / Remove-Marker / small helpers
$h = Hide-Secrets 'my password is hunter2, call 9876543210 or mail a.b@x.com token=abc123 xoxb-123-abc-def'
Check ($h -notmatch 'hunter2|9876543210|a\.b@x\.com|abc123|xoxb-') "Hide-Secrets left something behind: $h"
Check ((Hide-Secrets 'UD-10001 needs a look at order 12345') -match 'UD-10001.*order 12345') 'Hide-Secrets keeps ordinary text'
$q = Format-Quote "line one <@U123> & more`nline two > x"
Check ($q -eq "> line one &lt;@U123&gt; &amp; more`n> line two &gt; x") "Format-Quote output: $q"
Check ((Remove-Marker "a`nb`n_ref AR-DTESTALICE1-1793170000.123456_") -eq "a`nb") 'Remove-Marker'
Check ((ConvertTo-Mrkdwn 'a & <b>') -eq 'a &amp; &lt;b&gt;') 'ConvertTo-Mrkdwn'
Check ([math]::Abs((TsNum '1793170000.123456') - 1793170000.123456) -lt 0.001) 'TsNum'
Check ((IstTime '1793170000.1') -match '^\d{2}-[A-Za-z]{3} \d{2}:\d{2}$') 'IstTime format'
Check ((Format-ArState @{ mode_away = 'shadow'; mode_answer = 'shadow'; paused = 'no'; heartbeat = 5; runner = 'local' }) -eq 'AR-STATE v2 | mode_away=shadow | mode_answer=shadow | paused=no | heartbeat=5 | runner=local') 'Format-ArState'
$config = [pscustomobject]@{ a = 5; b = ''; c = $false }
Check ((Cfg 'a' 1) -eq 5) 'Cfg present'; Check ((Cfg 'b' 'dflt') -eq 'dflt') 'Cfg empty string -> default'; Check ((Cfg 'c' $true) -eq $false) 'Cfg false kept'; Check ((Cfg 'zzz' 7) -eq 7) 'Cfg missing -> default'

# --- Leadership title rule
$lead = 'Engineering Manager', 'Product Manager', 'Director of Engineering', 'VP Engineering', 'Vice President, Product', 'Head of Support', 'Chief Technology Officer', 'CEO', 'Founder', 'General Manager', 'Senior Manager, QA', 'Manager', 'Customer Success Manager'
$notLead = 'Senior Software Engineer', 'SDET', 'Team Lead', 'Technical Lead', 'Software Engineer II', 'Principal Engineer', 'Sr. Customer Success Specialist', 'Managed Services Engineer', 'QA Engineer', ''
foreach ($t in $lead)    { Check ($t -match $LeadershipRx) "leadership title should match: '$t'" }
foreach ($t in $notLead) { Check (-not ($t -match $LeadershipRx)) "title should NOT match: '$t'" }

# --- Persona lookups (fixture)
$expect = [ordered]@{ UTESTALICE1 = 'answers-ok'; UTESTPRIYA1 = 'away-only'; UTESTLENA01 = 'references-ok'; UTESTHANA01 = 'never'; UNOTLISTED1 = 'answers-ok' }
foreach ($k in $expect.Keys) { $got = Get-PersonaPolicy $k; Check ($got -eq $expect[$k]) "persona policy for $k : got '$got', expected '$($expect[$k])'" }
$pd = Get-PersonaDms
Check ($pd.Count -eq 4) "Get-PersonaDms returned $($pd.Count) DMs, expected 4"
Check ($pd['DTESTALICE1'] -eq 'UTESTALICE1') 'DM -> person mapping'

Remove-Item $Store -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ("unit tests: {0} passed, {1} failed" -f $script:pass, $script:fail)
if ($script:fail) { exit 1 }
