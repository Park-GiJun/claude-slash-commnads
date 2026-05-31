<#
.SYNOPSIS
  문서 기반 팀 파이프라인: working tree → 문서화 → planning 팀 먼저 → 문서 기반 후속 팀 → 산출물 종합.
.DESCRIPTION
  1) working tree 를 문서(00-worktree.md)로 스냅샷한다.
  2) planning 팀이 그 문서를 입력으로 계획을 세운다 → 10-plan.md.
  3) 후속 팀들이 '계획 문서'를 입력으로 각자 분석한다(문서 기반) → 20-<team>.md.
  4) 모든 산출물을 하나로 종합한다 → 90-summary.md.
  각 단계는 run-team.ps1 을 호출(헤드리스, 완료 대기)한다. 순차 실행.
.PARAMETER Task   파이프라인 전체에 줄 작업 지시.
.PARAMETER Teams  planning 이후 돌릴 팀 슬러그 목록. 'all' = planning 제외 전체. 기본 review-team.
.PARAMETER Cwd    대상 작업 디렉터리(git 저장소).
.PARAMETER DryRun 실제 실행 없이 흐름만 점검(각 팀은 run-team -DryRun).
.EXAMPLE
  powershell -File scripts\run-pipeline.ps1 -Task "결제 모듈 추가" -Teams review-team,backend-dev-kotlin
  powershell -File scripts\run-pipeline.ps1 -Task "리팩터링" -Teams all
#>
[CmdletBinding()]
param(
    [string]$Task = '현재 작업을 계획하고 검토한다.',
    [string[]]$Teams = @('review-team'),
    [string]$Cwd = (Get-Location).Path,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$scriptDir = $PSScriptRoot
$runTeam   = Join-Path $scriptDir 'run-team.ps1'
$repoRoot  = Split-Path -Parent $scriptDir
$teamsDir  = Join-Path $repoRoot 'agents\teams'

if ($Teams.Count -eq 1 -and $Teams[0] -eq 'all') {
    $Teams = Get-ChildItem $teamsDir -Directory | Where-Object { $_.Name -ne 'planning' } | ForEach-Object { $_.Name }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$pipe = Join-Path $Cwd ".team-runs\pipeline-$stamp"
New-Item -ItemType Directory -Path $pipe -Force | Out-Null
Write-Host "파이프라인 출력: $pipe" -ForegroundColor Cyan
if ($DryRun) { Write-Host '[DryRun] 실행 없이 단계 순서/명령만 미리보기. 실제 실행은 planning 완료(_lead.done) 후 후속 팀이 순차로 돕니다(-Wait).' -ForegroundColor Yellow }

# ---- 1) working tree → 문서 --------------------------------------------
$wtDoc = Join-Path $pipe '00-worktree.md'
Push-Location $Cwd; $__eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
try {
    $status = (git status --short 2>$null | Out-String)
    $diff   = (git diff 2>$null | Out-String)
    $staged = (git diff --staged 2>$null | Out-String)
    $files  = (git ls-files 2>$null | Select-Object -First 300 | Out-String)
} finally { $ErrorActionPreference = $__eap; Pop-Location }
@(
    '# Working Tree 스냅샷', "생성: $stamp  |  대상: $Cwd", '',
    '## 작업 지시', $Task, '',
    '## git status (short)', '```', $status.TrimEnd(), '```', '',
    '## 변경 diff (unstaged)', '```diff', $diff.TrimEnd(), '```', '',
    '## 변경 diff (staged)', '```diff', $staged.TrimEnd(), '```', '',
    '## 추적 파일 (상위 300)', '```', $files.TrimEnd(), '```'
) -join "`n" | Set-Content -LiteralPath $wtDoc -Encoding utf8
Write-Host "  [1/4] working tree 문서화 → 00-worktree.md" -ForegroundColor Green

# ---- 헬퍼: run-team 호출 ------------------------------------------------
function Invoke-Team($slug, $inputDoc, $outName) {
    $to = Join-Path $pipe $outName
    $sum = & $runTeam -Team $slug -Task $Task -InputDoc $inputDoc -OutDir $to -Cwd $Cwd -Wait:(-not $DryRun) -NoAttach -DryRun:$DryRun |
        Select-Object -Last 1
    return $sum
}

# ---- 2) planning 먼저 ---------------------------------------------------
Write-Host "  [2/4] planning 팀 (문서 기반 계획)" -ForegroundColor Green
$planSummary = Invoke-Team 'planning' $wtDoc 'planning'
$planDoc = Join-Path $pipe '10-plan.md'
if ($DryRun) { '# (dry-run) 계획 문서 placeholder' | Set-Content -LiteralPath $planDoc -Encoding utf8 }
elseif (Test-Path $planSummary) { Copy-Item -LiteralPath $planSummary -Destination $planDoc -Force }
else { throw 'planning 팀이 계획 산출물을 만들지 못했습니다.' }

# ---- 3) 후속 팀 (계획 문서 기반) ---------------------------------------
Write-Host "  [3/4] 후속 팀 $($Teams.Count)개 (계획 문서 기반)" -ForegroundColor Green
$teamDocs = @()
foreach ($tm in $Teams) {
    if (-not (Test-Path (Join-Path $teamsDir $tm))) { Write-Host "    건너뜀(없음): $tm" -ForegroundColor Yellow; continue }
    Write-Host "    → $tm" -ForegroundColor Green
    $sum = Invoke-Team $tm $planDoc $tm
    $td = Join-Path $pipe "20-$tm.md"
    if (-not $DryRun -and (Test-Path $sum)) { Copy-Item -LiteralPath $sum -Destination $td -Force; $teamDocs += @{ team = $tm; doc = $td } }
}

# ---- 4) 산출물 종합 -----------------------------------------------------
Write-Host "  [4/4] 산출물 종합 → 90-summary.md" -ForegroundColor Green
$final = Join-Path $pipe '90-summary.md'
$S = New-Object System.Collections.Generic.List[string]
$S.Add("# 파이프라인 종합 ($stamp)")
$S.Add(""); $S.Add("작업: $Task")
$S.Add(""); $S.Add("## 산출물 색인")
$S.Add("- 00-worktree.md — working tree 스냅샷")
$S.Add("- 10-plan.md — planning 팀 계획")
foreach ($d in $teamDocs) { $S.Add("- 20-$($d.team).md — $($d.team) 팀 결론") }
$S.Add(""); $S.Add("## 계획 (planning)")
if (Test-Path $planDoc) { $S.Add((Get-Content -Raw -Encoding UTF8 $planDoc)) }
foreach ($d in $teamDocs) {
    $S.Add(""); $S.Add("## $($d.team) 결론")
    $S.Add((Get-Content -Raw -Encoding UTF8 $d.doc))
}
($S -join "`n") | Set-Content -LiteralPath $final -Encoding utf8

Write-Host "`n파이프라인 완료. 종합: $final" -ForegroundColor Cyan
return $final
