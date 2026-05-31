<#
.SYNOPSIS
  슬래시 커맨드 실행을 대시보드용 commands.json 에 기록한다.
.DESCRIPTION
  각 commands/*.md 가 시작 시 -Status running, 종료 시 -Status done|error 로 호출한다.
  같은 커맨드의 직전 running 항목을 done/error 로 갱신(없으면 새로 append). 최근 200건 유지.
.EXAMPLE
  powershell -File scripts/log-command.ps1 -Command team -Status running -Note "review-team"
  powershell -File scripts/log-command.ps1 -Command team -Status done
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Command,
    [ValidateSet('running', 'done', 'error')][string]$Status = 'done',
    [string]$Note = '',
    [string]$Cwd = (Get-Location).Path,
    [string]$OutFile = (Join-Path $PSScriptRoot '..\dashboard\public\commands.json')
)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$dir = Split-Path -Parent $OutFile
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

$list = @()
if (Test-Path $OutFile) {
    try { $list = @(Get-Content -Raw -Encoding UTF8 $OutFile | ConvertFrom-Json) } catch { $list = @() }
}

$now = Get-Date -Format 'o'
$found = $false
if ($Status -in 'done', 'error') {
    for ($i = $list.Count - 1; $i -ge 0; $i--) {
        if ($list[$i].command -eq $Command -and $list[$i].status -eq 'running') {
            $list[$i].status = $Status
            if ($Note) { $list[$i].note = $Note }
            $list[$i] | Add-Member -NotePropertyName endedAt -NotePropertyValue $now -Force
            $found = $true
            break
        }
    }
}
if (-not $found) {
    $list += [ordered]@{ ts = $now; command = $Command; status = $Status; note = $Note; cwd = $Cwd }
}

if ($list.Count -gt 200) { $list = $list[($list.Count - 200)..($list.Count - 1)] }

# PowerShell 은 단일 요소 배열을 객체로 직렬화한다 → 항상 JSON 배열이 되도록 강제
if ($list.Count -eq 0) { $json = '[]' }
elseif ($list.Count -eq 1) { $json = '[' + ($list[0] | ConvertTo-Json -Depth 6) + ']' }
else { $json = $list | ConvertTo-Json -Depth 6 }
[System.IO.File]::WriteAllText($OutFile, $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("기록: /{0} [{1}] ({2})" -f $Command, $Status, (Get-Date -Format 'HH:mm:ss')) -ForegroundColor DarkCyan
