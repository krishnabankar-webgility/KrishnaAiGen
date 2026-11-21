<#
.SYNOPSIS
  Progress line for a slack-auto-reply job (Krishna, Prompt 12). The job's Claude session calls this after each stage; the runner
  posts the line in the Slack thread under the summary and tells Krishna what the next step is.
.EXAMPLE
  pwsh -File Write-JobStatus.ps1 -JobDir <dir> -Stage analysis_done -Next fixing -Note "Root cause: the gate misses X (CommonUtility.cs)"
#>
param(
  [Parameter(Mandatory)][string]$JobDir,
  [Parameter(Mandatory)][ValidateSet('started', 'progress', 'analysis_done', 'fixing_done', 'fixed_and_tested', 'tested', 'shipped', 'question', 'blocked', 'failed', 'finished')][string]$Stage,
  [string]$Next = '',
  [string]$Note = '',
  [string]$Reply = '',     # analysis jobs: a draft answer Krishna can send to the colleague
  [string]$Refs = ''       # branch, commit, build path, Jira or file references
)
$line = [ordered]@{ t = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds(); stage = $Stage; next = $Next; note = $Note; reply = $Reply; refs = $Refs } | ConvertTo-Json -Compress
for ($i = 1; $i -le 8; $i++) { try { Add-Content -Path (Join-Path $JobDir 'status.jsonl') -Value $line -Encoding utf8 -ErrorAction Stop; break } catch { if ($i -eq 8) { throw }; Start-Sleep -Milliseconds (150 * $i) } }
Write-Host "status recorded: $Stage"
