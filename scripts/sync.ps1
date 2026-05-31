<#
.SYNOPSIS
  이 저장소의 commands/skills/agents 를 ~/.claude 로 복사한다.
.PARAMETER WhatIf
  실제 복사 없이 어떤 파일이 바뀌는지만 출력한다.
.EXAMPLE
  pwsh scripts/sync.ps1 -WhatIf
  pwsh scripts/sync.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$repoRoot   = Split-Path -Parent $PSScriptRoot
$claudeRoot = Join-Path $env:USERPROFILE '.claude'
$folders    = @('commands', 'skills', 'agents', 'scripts')

# 자기 배포 방지: ~/.claude 로 복사된 sync.ps1 을 거기서 실행하면 원본=대상이 되어 자신을 덮어쓴다.
if ($repoRoot.TrimEnd('\') -ieq $claudeRoot.TrimEnd('\')) {
    throw "원본=대상($claudeRoot) — 저장소의 scripts\sync.ps1 에서 실행하세요 (~/.claude 복사본 실행 금지)."
}

foreach ($folder in $folders) {
    $src = Join-Path $repoRoot $folder
    if (-not (Test-Path $src)) { continue }

    $dst = Join-Path $claudeRoot $folder
    if (-not (Test-Path $dst)) {
        if ($PSCmdlet.ShouldProcess($dst, 'create directory')) {
            New-Item -ItemType Directory -Path $dst -Force | Out-Null
        }
    }

    Get-ChildItem -Path $src -Recurse -File | ForEach-Object {
        $relative = $_.FullName.Substring($src.Length).TrimStart('\', '/')
        $target   = Join-Path $dst $relative
        $targetDir = Split-Path -Parent $target

        $changed = $true
        if (Test-Path $target) {
            $changed = (Get-FileHash $_.FullName).Hash -ne (Get-FileHash $target).Hash
        }

        if (-not $changed) { return }

        if ($PSCmdlet.ShouldProcess($target, 'copy')) {
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }
            Copy-Item -Path $_.FullName -Destination $target -Force
            Write-Host "copied  $folder/$relative" -ForegroundColor Green
        } else {
            Write-Host "would copy  $folder/$relative" -ForegroundColor Yellow
        }
    }
}

Write-Host 'sync 완료.' -ForegroundColor Cyan
