<#
.SYNOPSIS
  팀(agents/teams/<team>)을 psmux 분할 패널에서 멀티에이전트로 실행한다.
  각 팀원이 자기 관점으로 동시에 입력(변경분 또는 문서)을 검토하고, 주장(lead)이 종합한다.
.DESCRIPTION
  팀원마다 헤드리스 `claude -p` 프로세스를 별도 psmux 패널에서 띄운다.
  - 각 팀원: 자기 페르소나(시스템 프롬프트) + 배정 모델(--model) + 공통 과제 → out/<name>.md
  - 주장: 모든 팀원 .done 을 기다린 뒤 보고서를 종합 → out/_summary.md → _lead.done
  멀티플렉서는 psmux → pmux → tmux 순으로 자동 탐색(psmux가 셋 다 제공).
.PARAMETER Team        agents/teams/<Team>/team.json 이 있어야 한다.
.PARAMETER Task        팀에 줄 초점/지시.
.PARAMETER InputDoc    이 문서를 입력으로 검토한다(문서 기반). 없으면 git 변경분을 캡처해 입력으로 쓴다.
.PARAMETER Cwd         분석 대상 작업 디렉터리. 기본: 현재 위치.
.PARAMETER OutDir      산출물 디렉터리 강제 지정(파이프라인용). 기본: <Cwd>\.team-runs\<team>-<ts>.
.PARAMETER Wait        세션 생성 후 주장 종합(_lead.done)까지 폴링 대기하고 _summary.md 경로를 반환한다.
.PARAMETER NoAttach    attach 하지 않는다. (-Wait 사용 시 자동 적용)
.PARAMETER DryRun      실제 실행 없이 생성될 러너/명령만 출력.
.EXAMPLE
  powershell -File scripts\run-team.ps1 -Team review-team
  powershell -File scripts\run-team.ps1 -Team planning -InputDoc .\doc\worktree.md -Wait -NoAttach
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Team,
    [string]$Task = '현재 입력을 당신의 전문 관점에서 검토하세요.',
    [string]$InputDoc,
    [string]$Cwd = (Get-Location).Path,
    [string]$OutDir,
    [string]$Mux,
    [string]$AllowedTools = 'Read,Grep,Glob',
    [switch]$Wait,
    [switch]$NoAttach,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
if ($Wait) { $NoAttach = $true }

# ---- 경로/매니페스트 ----------------------------------------------------
$repoRoot = Split-Path -Parent $PSScriptRoot
$teamDir  = Join-Path $repoRoot "agents\teams\$Team"
$manifest = Join-Path $teamDir 'team.json'
if (-not (Test-Path $manifest)) { throw "팀 매니페스트 없음: $manifest" }
$teamCfg = Get-Content -Raw -Encoding UTF8 $manifest | ConvertFrom-Json

# ---- 바이너리 해석 ------------------------------------------------------
function Resolve-Bin([string[]]$cands) { foreach ($c in $cands) { $cmd = Get-Command $c -ErrorAction SilentlyContinue; if ($cmd) { return $cmd.Source } }; return $null }
$muxBin = if ($Mux) { Resolve-Bin @($Mux) } else { Resolve-Bin @('psmux', 'pmux', 'tmux') }
$claudeBin = Resolve-Bin @('claude')
if (-not $DryRun) {
    if (-not $muxBin)    { throw 'psmux/pmux/tmux 없음. psmux 설치 또는 -Mux 지정. (github.com/anthropics/claude-code/issues/34150)' }
    if (-not $claudeBin) { throw 'claude CLI 를 PATH 에서 못 찾음.' }
}

# ---- 산출 디렉터리 ------------------------------------------------------
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$out = if ($OutDir) { $OutDir } else { Join-Path $Cwd ".team-runs\$Team-$stamp" }
$personaDir = Join-Path $out 'personas'
New-Item -ItemType Directory -Path $personaDir -Force | Out-Null

function Get-PersonaBody([string]$path) {
    $raw = Get-Content -Raw -Encoding UTF8 -LiteralPath $path
    return ([regex]::Replace($raw, '(?s)^\s*---.*?\r?\n---\r?\n', '')).Trim()
}

# ---- 입력 문서 결정 -----------------------------------------------------
if ($InputDoc) {
    if (-not (Test-Path $InputDoc)) { throw "InputDoc 없음: $InputDoc" }
    $sourceDoc = (Resolve-Path $InputDoc).Path
} else {
    $sourceDoc = Join-Path $out '_diff.txt'
    Push-Location $Cwd; $__eap = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try { $unstaged = (git diff 2>$null | Out-String); $staged = (git diff --staged 2>$null | Out-String) }
    finally { $ErrorActionPreference = $__eap; Pop-Location }
    @('### git diff (unstaged)', $unstaged, '', '### git diff (staged)', $staged) -join "`n" |
        Set-Content -LiteralPath $sourceDoc -Encoding utf8
    if (([string]$unstaged + [string]$staged).Trim().Length -eq 0) {
        Write-Host '경고: git 변경분이 비어 있습니다. -Task 또는 -InputDoc 를 쓰세요.' -ForegroundColor Yellow
    }
}

# ---- 공통 과제 파일 -----------------------------------------------------
$memberTask = @"
입력 문서를 Read 로 읽고, 당신의 전문 관점에서 분석·검토하세요.
- 입력 문서: $sourceDoc
- 추가 맥락이 필요하면 코드베이스를 Read/Grep/Glob 으로 확인하세요. 코드를 절대 수정하지 마세요.
- 사용자 지시(초점): $Task

발견·권고만 간결히, 당신 시스템 프롬프트의 출력 형식대로 보고하세요. 다른 관점은 동료가 맡습니다.
"@
$taskFile = Join-Path $out '_task.txt'
$memberTask | Set-Content -LiteralPath $taskFile -Encoding utf8

$memberNames = @($teamCfg.members | ForEach-Object { $_.name })
$reportList = ($memberNames | ForEach-Object { Join-Path $out "$_.md" }) -join "`n"
$leadTask = @"
팀원 보고서를 종합하세요. 다음 파일들을 Read 로 모두 읽으세요:
$reportList

원래 입력 문서: $sourceDoc
중복을 합치고 우선순위순으로 정렬해, 당신 시스템 프롬프트의 산출 형식대로 단일 결론/계획을 작성하세요.
각 항목에 출처 팀원을 표기하세요.
"@
$leadTaskFile = Join-Path $out '_lead-task.txt'
$leadTask | Set-Content -LiteralPath $leadTaskFile -Encoding utf8

# ---- 러너 스크립트 생성 (BOM 포함 UTF-8) --------------------------------
function New-Runner($person, $isLead) {
    $name = $person.name
    $mdl = if ($person.model) { $person.model } else { 'sonnet' }
    $personaPath = Join-Path $personaDir "$name.txt"
    Get-PersonaBody (Join-Path $teamDir $person.file) | Set-Content -LiteralPath $personaPath -Encoding utf8
    $runner = Join-Path $out "run-$name.ps1"
    $mdPath = Join-Path $out "$name.md"
    $donePath = Join-Path $out "$name.done"
    $tf = if ($isLead) { $leadTaskFile } else { $taskFile }

    $pre = @"
`$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
Write-Host '=== [$name] ($($person.role)) · 모델 $mdl ===' -ForegroundColor Cyan
"@
    if ($isLead) {
        $doneChecks = ($memberNames | ForEach-Object { "'" + (Join-Path $out "$_.done") + "'" }) -join ', '
        $wait = @"
Write-Host '주장 대기: 팀원 완료를 기다립니다...' -ForegroundColor Magenta
`$marks = @($doneChecks)
`$deadline = (Get-Date).AddMinutes(20)
while (`$marks | Where-Object { -not (Test-Path `$_) }) {
    if ((Get-Date) -gt `$deadline) { Write-Host '경고: 일부 팀원 미완료 — 가용 보고서로 종합' -ForegroundColor Yellow; break }
    Start-Sleep -Seconds 3
}
Write-Host '팀원 전원 완료. 종합 시작.' -ForegroundColor Magenta
"@
    } else { $wait = '' }
    $body = @"
$pre
$wait
`$persona = Get-Content -Raw -Encoding UTF8 -LiteralPath '$personaPath'
`$task    = Get-Content -Raw -Encoding UTF8 -LiteralPath '$tf'
& '$claudeBin' -p `$task --model '$mdl' --append-system-prompt `$persona --allowedTools '$AllowedTools' 2>&1 |
    Tee-Object -FilePath '$mdPath'
(Get-Content -Raw -LiteralPath '$mdPath') | Set-Content -Encoding UTF8 -LiteralPath '$mdPath'
New-Item -ItemType File -Path '$donePath' -Force | Out-Null
"@
    if ($isLead) {
        $body += "`nCopy-Item -LiteralPath '$mdPath' -Destination '$(Join-Path $out '_summary.md')' -Force"
        $body += "`nNew-Item -ItemType File -Path '$(Join-Path $out '_lead.done')' -Force | Out-Null"
    }
    $body += "`nWrite-Host '=== [$name] 완료 ===' -ForegroundColor Green"
    [System.IO.File]::WriteAllText($runner, $body, (New-Object System.Text.UTF8Encoding($true)))
    return $runner
}

$leadRunner = New-Runner $teamCfg.lead $true
$memberRunners = @($teamCfg.members | ForEach-Object { New-Runner $_ $false })

# ---- mux 세션 구성 ------------------------------------------------------
$session = "team-$Team-$stamp"
function Mux([string[]]$a) { if ($DryRun) { Write-Host "[dry] $muxBin $($a -join ' ')" -ForegroundColor DarkGray } else { $pe=$ErrorActionPreference; $ErrorActionPreference='Continue'; $ps=$env:PSMUX_SESSION; $env:PSMUX_SESSION=$null; try { & $muxBin @a 2>&1 | Out-Null } finally { $ErrorActionPreference=$pe; $env:PSMUX_SESSION=$ps }; Start-Sleep -Milliseconds 250 } }
function PaneCmd([string]$r) { "powershell -NoProfile -ExecutionPolicy Bypass -File `"$r`"" }

Write-Host "팀: $($teamCfg.title)  |  세션: $session  |  입력: $sourceDoc" -ForegroundColor Cyan
Write-Host "출력: $out" -ForegroundColor Cyan
Mux @('new-session', '-d', '-s', $session, '-c', $Cwd)
Mux @('send-keys', '-t', $session, (PaneCmd $leadRunner), 'Enter')
foreach ($r in $memberRunners) {
    Mux @('split-window', '-t', $session, '-c', $Cwd)
    Mux @('send-keys', '-t', $session, (PaneCmd $r), 'Enter')
}
Mux @('select-layout', '-t', $session, 'tiled')

# ---- attach / wait / 안내 ----------------------------------------------
$summaryPath = Join-Path $out '_summary.md'
if ($DryRun) {
    Write-Host "[dry] attach: $muxBin attach -t $session" -ForegroundColor DarkGray
    Write-Host "[dry] summary → $summaryPath" -ForegroundColor DarkGray
    return $summaryPath
}
if ($Wait) {
    $leadDone = Join-Path $out '_lead.done'
    Write-Host '대기: 주장 종합(_lead.done)까지...' -ForegroundColor Cyan
    $deadline = (Get-Date).AddMinutes(30)
    while (-not (Test-Path $leadDone)) {
        if ((Get-Date) -gt $deadline) { Write-Host '경고: 30분 타임아웃.' -ForegroundColor Yellow; break }
        Start-Sleep -Seconds 5
    }
    if (Test-Path $summaryPath) { Write-Host "종합 완료 → $summaryPath" -ForegroundColor Green }
    return $summaryPath
}
if ($NoAttach) {
    Write-Host "세션 생성됨. 관찰: " -NoNewline; Write-Host "$muxBin attach -t $session" -ForegroundColor Yellow
    Write-Host "종합 결과: $summaryPath"
    return $summaryPath
}
Write-Host "attach 합니다 (분리: Ctrl-b d)..." -ForegroundColor Cyan
& $muxBin attach -t $session
return $summaryPath
