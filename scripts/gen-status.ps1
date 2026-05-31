<#
.SYNOPSIS
  agents/teams + .team-runs 를 스캔해 대시보드용 status.json 을 만든다.
  에이전트 이름이 전역 유일이므로 .team-runs 어디서든 <name>.md/<name>.done 으로 상태를 매칭한다.
.PARAMETER OutFile  출력 경로. 기본 dashboard/public/status.json
.PARAMETER Cwd      .team-runs 를 찾을 작업 디렉터리(런이 일어난 곳). 기본 현재 위치.
.PARAMETER Watch    2초마다 갱신 반복(대시보드 라이브용).
.EXAMPLE
  powershell -File scripts\gen-status.ps1
  powershell -File scripts\gen-status.ps1 -Cwd C:\my\project -Watch
#>
[CmdletBinding()]
param(
    [string]$OutFile,
    [string]$Cwd = (Get-Location).Path,
    [switch]$Watch
)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$repoRoot = Split-Path -Parent $PSScriptRoot
$teamsDir = Join-Path $repoRoot 'agents\teams'
if (-not $OutFile) { $OutFile = Join-Path $repoRoot 'dashboard\public\status.json' }
$outDir = Split-Path -Parent $OutFile
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

# 선수 표시 이름 (시각화용)
$Names = @{
    bruno='Bruno Fernandes'; shaw='Luke Shaw'; dalot='Diogo Dalot'; casemiro='Casemiro'; yoro='Leny Yoro'
    lammens='Senne Lammens'; mbeumo='Bryan Mbeumo'; cunha='Matheus Cunha'; amad='Amad Diallo'; sesko='Benjamin Šeško'
    mainoo='Kobbie Mainoo'; dorgu='Patrick Dorgu'; zirkzee='Joshua Zirkzee'; maguire='Harry Maguire'; mount='Mason Mount'
    deligt='Matthijs de Ligt'; martinez='Lisandro Martínez'; ugarte='Manuel Ugarte'; heaven='Ayden Heaven'
    bayindir='Altay Bayındır'; heaton='Tom Heaton'; mazraoui='Noussair Mazraoui'; leon='Diego León'; kone='Sékou Koné'
    fredricson='Tyler Fredricson'; collyer='Toby Collyer'; mather='Sam Mather'; biancheri='Gabriele Biancheri'
    amass='Harry Amass'; bradbury='Louie Bradbury'; ajayi='Noah Ajayi'; barbosa='Neithan Barbosa'; obi='Chido Obi'
    wheatley='Ethan Wheatley'; gabriel='JJ Gabriel'; kukonki='Godwill Kukonki'; fitzgerald='Jayce Fitzgerald'
    devaney='Jacob Devaney'; armer='Dan Armer'; munro='Reece Munro'; ogunneye='Habeeb Ogunneye'; aljofree='Sonny Aljofree'
    byrnehughes='Cameron Byrne-Hughes'; harrison='Elyh Harrison'; heath='Fred Heath'; murdock='Will Murdock'; watson='Zachary Watson'
    lacey='Shea Lacey'; jfletcher='Jack Fletcher'; tfletcher='Tyler Fletcher'
    carrick='Michael Carrick'; holland='Steve Holland'; woodgate='Jonathan Woodgate'; evans='Jonny Evans'
    binnion='Travis Binnion'; mawson='Craig Mawson'
}

function Build-Status {
    $runsRoot = Join-Path $Cwd '.team-runs'
    # .team-runs 의 모든 <name>.md / <name>.done 색인 (이름 전역 유일)
    $mdIndex = @{}; $doneIndex = @{}
    if (Test-Path $runsRoot) {
        Get-ChildItem -Path $runsRoot -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue | ForEach-Object {
            $n = $_.BaseName
            if (-not $n.StartsWith('_')) {
                if (-not $mdIndex.ContainsKey($n) -or $_.LastWriteTime -gt $mdIndex[$n].LastWriteTime) { $mdIndex[$n] = $_ }
            }
        }
        Get-ChildItem -Path $runsRoot -Recurse -File -Filter '*.done' -ErrorAction SilentlyContinue | ForEach-Object {
            $doneIndex[$_.BaseName] = $true
        }
    }

    function Agent-State($name) {
        $st = 'idle'; $lines = 0; $last = ''
        if ($mdIndex.ContainsKey($name)) {
            $f = $mdIndex[$name]
            $content = Get-Content -LiteralPath $f.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
            $lines = @($content).Count
            $nonEmpty = @($content | Where-Object { $_.Trim() })
            if ($nonEmpty.Count) { $last = $nonEmpty[-1].Trim() }
            $st = if ($doneIndex.ContainsKey($name)) { 'done' } elseif ($lines -gt 0) { 'working' } else { 'spawning' }
        } elseif ($doneIndex.ContainsKey($name)) { $st = 'done' }
        return @{ status = $st; lines = $lines; lastLine = $last }
    }

    $teams = @()
    Get-ChildItem -Path $teamsDir -Directory | Sort-Object Name | ForEach-Object {
        $mf = Join-Path $_.FullName 'team.json'
        if (-not (Test-Path $mf)) { return }
        $tc = Get-Content -Raw -Encoding UTF8 $mf | ConvertFrom-Json
        $agents = @()
        $roster = @($tc.lead) + @($tc.members)
        for ($i = 0; $i -lt $roster.Count; $i++) {
            $a = $roster[$i]
            $s = Agent-State $a.name
            $dn = if ($Names.ContainsKey($a.name)) { $Names[$a.name] } else { $a.name }
            $agents += [ordered]@{
                name = $a.name; display = $dn; role = $a.role; model = $a.model; usage = $a.usage
                pos = $a.pos; x = $a.x; y = $a.y; isLead = ($i -eq 0)
                status = $s.status; lines = $s.lines; lastLine = $s.lastLine
            }
        }
        $teams += [ordered]@{ slug = $tc.team; title = $tc.title; stack = $tc.stack; agents = $agents }
    }
    return [ordered]@{ generatedAt = (Get-Date -Format 'o'); cwd = $Cwd; teams = $teams }
}

function Write-Status {
    $obj = Build-Status
    [System.IO.File]::WriteAllText($OutFile, ($obj | ConvertTo-Json -Depth 8), (New-Object System.Text.UTF8Encoding($false)))
    $active = ($obj.teams | ForEach-Object { $_.agents } | Where-Object { $_.status -in 'working', 'spawning' }).Count
    Write-Host ("status.json 갱신 — 활성 에이전트 {0} ({1})" -f $active, (Get-Date -Format 'HH:mm:ss')) -ForegroundColor Cyan
}

if ($Watch) {
    Write-Host "Watch 모드 (2초). 중지: Ctrl-C  →  $OutFile" -ForegroundColor Yellow
    while ($true) { try { Write-Status } catch { Write-Host $_.Exception.Message -ForegroundColor Red }; Start-Sleep -Seconds 2 }
} else { Write-Status; Write-Host "→ $OutFile" }
