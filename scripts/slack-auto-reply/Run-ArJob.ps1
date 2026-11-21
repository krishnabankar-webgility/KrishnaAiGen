<#
.SYNOPSIS
  Runs one slack-auto-reply job (Krishna, Prompt 12): a headless Claude Code session that analyses, or fixes + tests + ships, the ask Krishna
  tagged with "fix KrishnaAiGen" or "Analysis KrishnaAiGen". Started detached by Invoke-SlackAutoReply.ps1; progress is read back from status.jsonl.
  Private files only: job folders live in %USERPROFILE%\.claude\slack-auto-reply\jobs\ (never committed).
#>
param(
  [Parameter(Mandatory)][string]$JobDir,
  [Parameter(Mandatory)][string]$ConfigPath
)
$ErrorActionPreference = 'Stop'
$status = Join-Path $PSScriptRoot 'Write-JobStatus.ps1'
function Get-Cfg($name, $default) { $v = $script:config.$name; if ($null -eq $v -or "$v" -eq '') { $default } else { $v } }
try {
  $script:config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
  $req = Get-Content (Join-Path $JobDir 'request.json') -Raw | ConvertFrom-Json
  $prompt = Get-Content (Join-Path $JobDir 'prompt.md') -Raw
  $claude = if (Test-Path $script:config.claude_path) { $script:config.claude_path } else { (Get-Command claude -ErrorAction Stop).Source }
  $work = [string](Get-Cfg 'job_workdir' 'C:\WG-Agentic'); if (-not (Test-Path $work)) { $work = $JobDir }
  $allowed = [string](Get-Cfg 'job_allowed_tools' 'Bash,PowerShell,Read,Edit,Write,Glob,Grep,Skill,Agent,mcp__claude_ai_Atlassian_MCP,mcp__claude_ai_Slack,mcp__bitbucket,mcp__jenkins,mcp__cis-db,mcp__mssql-winauth,mcp__mssql-sqlauth,mcp__quickbooks-desktop')
  $denied = [string](Get-Cfg 'job_denied_tools' 'Bash(git push --force*),Bash(git push -f*),PowerShell(git push --force*),PowerShell(git push -f*),Bash(git push origin master*),Bash(git push origin develop*),PowerShell(git push origin master*),PowerShell(git push origin develop*),Bash(git reset --hard origin*),Bash(rm -rf*),PowerShell(Remove-Item -Recurse -Force C:*)')
  $cliArgs = @('-p', $prompt, '--permission-mode', 'acceptEdits', '--allowedTools', $allowed, '--disallowedTools', $denied, '--output-format', 'json',
               '--max-turns', [string](Get-Cfg 'job_max_turns' 500), '--effort', [string](Get-Cfg 'job_effort' 'high'))
  foreach ($d in @($script:config.unify_repo, $script:config.wd_context_dir, (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)), $JobDir)) { if ($d -and (Test-Path $d)) { $cliArgs += @('--add-dir', $d) } }
  # Headless sessions ignore a project's .mcp.json and settings until the folder is trusted. Passing the servers explicitly needs no trust,
  # so the job never depends on an edit of ~/.claude.json (the tool allow-list and folders already come from the flags above).
  $mcp = [string](Get-Cfg 'job_mcp_config' (Join-Path $work '.mcp.json')); if ($mcp -and (Test-Path $mcp)) { $cliArgs += @('--mcp-config', $mcp) }
  $model = [string](Get-Cfg 'job_model' ([string]$script:config.model)); if ($model) { $cliArgs += @('--model', $model) }
  Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
  & $status -JobDir $JobDir -Stage started -Note "Session started ($($req.kind)) in $work" | Out-Null
  Push-Location $work
  try { $raw = & $claude @cliArgs 2> (Join-Path $JobDir 'stderr.txt') | Out-String } finally { Pop-Location }
  $raw | Set-Content (Join-Path $JobDir 'stdout.json') -Encoding utf8
  $outer = $null; try { $outer = $raw | ConvertFrom-Json } catch { }
  $res = [ordered]@{ ok = [bool]($outer -and -not $outer.is_error); session_id = [string]$outer.session_id; turns = $outer.num_turns; cost_usd = $outer.total_cost_usd; subtype = [string]$outer.subtype; result = [string]$outer.result }
  $res | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $JobDir 'result.json') -Encoding utf8
  $tail = ([string]$outer.result -replace '\s+', ' ').Trim(); if ($tail.Length -gt 600) { $tail = $tail.Substring(0, 600) + '…' }
  if ($res.ok) { & $status -JobDir $JobDir -Stage finished -Note $tail | Out-Null }
  else { & $status -JobDir $JobDir -Stage failed -Note "The session ended without a result (subtype $($res.subtype)). See stderr.txt in the job folder." | Out-Null }
}
catch {
  try { & $status -JobDir $JobDir -Stage failed -Note "The job could not run: $_" | Out-Null } catch { }
  '{"ok":false}' | Set-Content (Join-Path $JobDir 'result.json') -Encoding utf8
}
