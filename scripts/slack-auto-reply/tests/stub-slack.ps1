# Minimal fake of the Slack Web API (plus one Jira issue route) for testing Invoke-SlackAutoReply.ps1 offline.
# State lives in a JSON file shared with the test driver (Test-EndToEnd.ps1). Fixture data only: no real people.
param([int]$Port = 8799, [Parameter(Mandatory)][string]$StateFile)
$ErrorActionPreference = 'Stop'
# Windows (Defender, the driver) can hold the file for a moment: retry instead of failing the request.
function Load { for ($i = 0; $i -lt 40; $i++) { try { return (Get-Content $StateFile -Raw | ConvertFrom-Json -AsHashtable) } catch { Start-Sleep -Milliseconds 50 } }; throw 'state file locked' }
function Save($s) { $json = $s | ConvertTo-Json -Depth 30; for ($i = 0; $i -lt 40; $i++) { try { [IO.File]::WriteAllText($StateFile, $json, [Text.UTF8Encoding]::new($false)); return } catch { Start-Sleep -Milliseconds 50 } }; throw 'state file locked' }
function Send($ctx, $obj) {
  $b = [Text.Encoding]::UTF8.GetBytes(($obj | ConvertTo-Json -Depth 30 -Compress))
  $ctx.Response.ContentType = 'application/json; charset=utf-8'; $ctx.Response.ContentLength64 = $b.Length
  $ctx.Response.OutputStream.Write($b, 0, $b.Length); $ctx.Response.Close()
}
$l = [Net.HttpListener]::new(); $l.Prefixes.Add("http://127.0.0.1:$Port/"); $l.Start()
while ($l.IsListening) {
  $ctx = $l.GetContext()
  try {
    $req = $ctx.Request
    $method = $req.Url.AbsolutePath.Trim('/')
    if ($method -eq 'ping') { Send $ctx @{ ok = $true }; continue }
    if ($method -like 'rest/api/3/issue/*') {
      Send $ctx @{ fields = @{ summary = 'Fixture ticket'; status = @{ name = 'In Test' }; issuetype = @{ name = 'Bug' }; assignee = @{ displayName = 'Fixture Dev' }; fixVersions = @(); updated = '2026-11-05T10:00:00.000+0000' } }; continue
    }
    $auth = [string]$req.Headers['Authorization']
    $kind = if ($auth -match 'xoxb-test') { 'bot' } elseif ($auth -match 'xoxp-test') { 'user' } else { 'none' }
    $a = @{}
    if ($req.HttpMethod -eq 'POST') { $raw = [IO.StreamReader]::new($req.InputStream, [Text.Encoding]::UTF8).ReadToEnd(); if ($raw) { $a = $raw | ConvertFrom-Json -AsHashtable } }
    else { foreach ($k in $req.QueryString.AllKeys) { $a[$k] = $req.QueryString[$k] } }
    $s = Load
    $s.calls += @(@{ method = $method; token = $kind; channel = [string]$a.channel })
    $userOnly = 'search.messages', 'users.info', 'users.profile.get', 'chat.getPermalink'
    if ($method -in $userOnly -and $kind -ne 'user') { Save $s; Send $ctx @{ ok = $false; error = 'not_allowed_token_type' }; continue }
    if ($kind -eq 'none') { Save $s; Send $ctx @{ ok = $false; error = 'invalid_auth' }; continue }

    switch ($method) {
      'search.messages' {
        if ($s.search_error) { Save $s; Send $ctx @{ ok = $false; error = $s.search_error }; break }
        $cut = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - 172800
        $matches_ = @(foreach ($ch in $s.channels.Keys) { if ($ch -like 'D*') { foreach ($m in $s.channels[$ch]) { if ($m.user -ne 'U08FTS2SRAP' -and [double]$m.ts -gt $cut) { @{ channel = @{ id = $ch }; user = $m.user; ts = $m.ts; text = $m.text } } } } })
        Save $s; Send $ctx @{ ok = $true; messages = @{ matches = $matches_; paging = @{ pages = 1; page = 1 } } }
      }
      { $_ -in 'conversations.history', 'conversations.replies' } {
        $ch = [string]$a.channel
        if ($s.fail_history -contains $ch) { Save $s; Send $ctx @{ ok = $false; error = 'internal_error' }; break }
        if ($ch -like 'D*' -and $kind -ne 'user') { Save $s; Send $ctx @{ ok = $false; error = 'channel_not_found' }; break }
        $msgs = @($s.channels[$ch])
        if ($method -eq 'conversations.replies') {
          $sel = @($msgs | Where-Object { $_.ts -eq $a.ts -or $_.thread_ts -eq $a.ts } | Sort-Object { [double]$_.ts })
        } else {
          $oldest = if ($a.oldest) { [double]$a.oldest } else { 0 }; $latest = if ($a.latest) { [double]$a.latest } else { [double]::MaxValue }
          $incl = $a.inclusive -eq 'true'
          $sel = @($msgs | Where-Object {
              $t = [double]$_.ts
              ((($incl -and $t -ge $oldest) -or (-not $incl -and $t -gt $oldest)) -and (($incl -and $t -le $latest) -or (-not $incl -and $t -lt $latest)) -and (-not $_.thread_ts -or $_.thread_ts -eq $_.ts))
            } | Sort-Object { [double]$_.ts } -Descending | Select-Object -First ([int]$a.limit))
          $sel = @($sel | ForEach-Object { $c = $_.Clone(); $c.reply_count = @($msgs | Where-Object { $_.thread_ts -eq $c.ts -and $_.ts -ne $c.ts }).Count; $c })
        }
        Save $s; Send $ctx @{ ok = $true; messages = $sel }
      }
      'users.info' {
        $u = $s.users[[string]$a.user]
        Save $s
        if ($u) { Send $ctx @{ ok = $true; user = @{ id = $a.user; real_name = $u.real_name; name = $u.name; profile = @{ title = $u.title }; is_bot = [bool]$u.is_bot; deleted = $false } } }
        else { Send $ctx @{ ok = $false; error = 'user_not_found' } }
      }
      'users.profile.get' { Save $s; Send $ctx @{ ok = $true; profile = $s.krishna_status } }
      'chat.getPermalink' { Save $s; Send $ctx @{ ok = $true; permalink = "https://webgility.slack.com/archives/$($a.channel)/p$(([string]$a.message_ts) -replace '\.', '')" } }
      'conversations.open' { Save $s; Send $ctx @{ ok = $true; channel = @{ id = 'DBOTTEST1' } } }
      'chat.postMessage' {
        $ch = [string]$a.channel
        if ($ch -like 'D*' -and $kind -eq 'bot' -and $ch -ne 'DBOTTEST1') { Save $s; Send $ctx @{ ok = $false; error = 'channel_not_found' }; break }
        if ([int]$s.fail_summary_posts -gt 0 -and $kind -eq 'bot' -and $ch -eq 'C0B0CBW8G03' -and -not $a.thread_ts) { $s.fail_summary_posts = [int]$s.fail_summary_posts - 1; Save $s; Send $ctx @{ ok = $false; error = 'internal_error' }; break }
        $s.seq = [int]$s.seq + 1
        $ts = '{0}.{1:000000}' -f [DateTimeOffset]::UtcNow.ToUnixTimeSeconds(), $s.seq
        $m = @{ ts = $ts; text = [string]$a.text }
        if ($kind -eq 'bot') { $m.user = 'U0APDD2PYRX'; $m.bot_id = 'B0AP43PDBL4' } else { $m.user = 'U08FTS2SRAP' }
        if ($a.thread_ts) { $m.thread_ts = [string]$a.thread_ts }
        if (-not $s.channels.ContainsKey($ch)) { $s.channels[$ch] = @() }
        $s.channels[$ch] = @($s.channels[$ch]) + @($m)
        $s.posts += @(@{ token = $kind; channel = $ch; text = [string]$a.text; thread_ts = [string]$a.thread_ts; ts = $ts })
        Save $s; Send $ctx @{ ok = $true; ts = $ts; channel = $ch }
      }
      'chat.update' {
        $ch = [string]$a.channel
        foreach ($m in @($s.channels[$ch])) { if ($m.ts -eq [string]$a.ts) { $m.text = [string]$a.text } }
        $s.updates += @(@{ token = $kind; channel = $ch; ts = [string]$a.ts; text = [string]$a.text })
        Save $s; Send $ctx @{ ok = $true }
      }
      default { Save $s; Send $ctx @{ ok = $false; error = "unknown_method_$method" } }
    }
  } catch {
    try { Send $ctx @{ ok = $false; error = "stub_exception: $($_.Exception.Message)" } } catch { }
  }
}
