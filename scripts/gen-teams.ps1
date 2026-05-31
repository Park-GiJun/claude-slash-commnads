<#
.SYNOPSIS
  팀 설정으로부터 agents/teams/<slug>/{team.json, <선수>.md} 를 일괄 생성한다.
  맨유 25/26 인물(1군+U21+코칭스태프) 이름의 자문(읽기 전용) 멀티에이전트 팀.
  각 팀원은 역할에 맞는 모델/예상 사용량이 배정되어 토큰·시간을 최적화한다.
.DESCRIPTION
  팀/로스터/모델을 바꾸려면 아래 설정만 고치고 다시 실행한다.
  한 사람 = 한 팀(전역 유일). review-team(손작성)이 선점한 6명은 $Reserved 로 충돌 검사.
  런처(run-team.ps1)는 team.json 만 읽는다.
.EXAMPLE
  powershell -File scripts\gen-teams.ps1
  powershell -File scripts\gen-teams.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
$repoRoot = Split-Path -Parent $PSScriptRoot
$teamsDir = Join-Path $repoRoot 'agents\teams'

# ---- 스쿼드 풀 (25/26): 1군 + U21 + 코칭스태프 ------------------------
$Squad = @{
    # 1군
    bruno='Bruno Fernandes'; shaw='Luke Shaw'; dalot='Diogo Dalot'; casemiro='Casemiro'
    yoro='Leny Yoro'; lammens='Senne Lammens'
    mbeumo='Bryan Mbeumo'; cunha='Matheus Cunha'; amad='Amad Diallo'; sesko='Benjamin Šeško'
    mainoo='Kobbie Mainoo'; dorgu='Patrick Dorgu'; zirkzee='Joshua Zirkzee'; maguire='Harry Maguire'
    mount='Mason Mount'; deligt='Matthijs de Ligt'; martinez='Lisandro Martínez'; ugarte='Manuel Ugarte'
    heaven='Ayden Heaven'; bayindir='Altay Bayındır'; heaton='Tom Heaton'; mazraoui='Noussair Mazraoui'
    leon='Diego León'; kone='Sékou Koné'
    # U21 / 아카데미
    fredricson='Tyler Fredricson'; collyer='Toby Collyer'; mather='Sam Mather'; biancheri='Gabriele Biancheri'
    amass='Harry Amass'; bradbury='Louie Bradbury'; ajayi='Noah Ajayi'; barbosa='Neithan Barbosa'
    obi='Chido Obi'; wheatley='Ethan Wheatley'; gabriel='JJ Gabriel'; kukonki='Godwill Kukonki'
    fitzgerald='Jayce Fitzgerald'; devaney='Jacob Devaney'; armer='Dan Armer'; munro='Reece Munro'
    ogunneye='Habeeb Ogunneye'; aljofree='Sonny Aljofree'; byrnehughes='Cameron Byrne-Hughes'
    harrison='Elyh Harrison'; heath='Fred Heath'; murdock='Will Murdock'; watson='Zachary Watson'
    lacey='Shea Lacey'; jfletcher='Jack Fletcher'; tfletcher='Tyler Fletcher'
    # 코칭 스태프 (Carrick 체제, 25/26 — 2년 재계약)
    carrick='Michael Carrick'; holland='Steve Holland'; woodgate='Jonathan Woodgate'
    evans='Jonny Evans'; binnion='Travis Binnion'; mawson='Craig Mawson'
}

# review-team(손작성)이 선점 — 전역 유일성 검사 대상
$Reserved = @('bruno', 'casemiro', 'yoro', 'shaw', 'dalot', 'lammens')

# ---- 역할 슬롯 (index 0 = 리드) -----------------------------------------
$RoleTitles = @{
    'backend-dev'  = @('아키텍트 · 설계/종합', '구현 · 도메인/서비스 로직', 'API · 계약/인터페이스', '테스트 작성', '리뷰 · 품질/관례')
    'frontend-dev' = @('리드 · 설계/종합', '컴포넌트 · UI 구현', '상태 · 데이터 흐름', '스타일 · UX/반응형', '테스트 작성')
    'infra'        = @('리드 · 설계/종합', 'CI/CD · 파이프라인', '배포 · 컨테이너/IaC', '관측성 · 로깅/모니터링', '보안 · 시크릿/접근제어')
    'design'       = @('리드 · 방향/종합', 'UX · 플로우/정보구조', '비주얼 · 디자인 시스템', '접근성 · WCAG', '콘텐츠 · 카피')
    'planning'     = @('리드 · 종합/우선순위', '요구사항 · AC/수용기준', '시나리오 · 사용자 흐름', '리스크 · 의존성/제약', '지표 · 성공 측정')
}

# ---- 역할별 모델 (토큰·시간 최적화): 리드·심층=sonnet, 좁은 역할=haiku ----
$RoleModel = @{
    'backend-dev'  = @('opus', 'sonnet', 'sonnet', 'haiku',  'sonnet')
    'frontend-dev' = @('opus', 'haiku',  'sonnet', 'haiku',  'haiku')
    'infra'        = @('opus', 'haiku',  'sonnet', 'haiku',  'sonnet')
    'design'       = @('opus', 'sonnet', 'haiku',  'sonnet', 'haiku')
    'planning'     = @('opus', 'sonnet', 'sonnet', 'sonnet', 'haiku')
}
function Get-Usage($m) { switch ($m) { 'haiku' { '경량(빠름·저비용)' } 'opus' { '심층(고비용)' } default { '표준' } } }

# ---- 역할별 관찰 항목 ({FW} = 프레임워크 주입) --------------------------
# formation: slot index (0=lead) -> pitch position (x,y normalized 0..1, y: 0=back .. 1=attack)
$Formation = @(
    @{ pos = 'CM'; x = 0.50; y = 0.50 },
    @{ pos = 'ST'; x = 0.50; y = 0.84 },
    @{ pos = 'RB'; x = 0.82; y = 0.56 },
    @{ pos = 'LB'; x = 0.18; y = 0.56 },
    @{ pos = 'GK'; x = 0.50; y = 0.10 }
)

$RoleBullets = @{
    'backend-dev:0' = @('작업의 설계를 잡는다: 모듈 경계, 계층, 의존 방향.', '팀원(구현·API·테스트·리뷰) 산출을 종합해 단일 구현 청사진을 만든다.', '트레이드오프·리스크를 명시하고 우선순위를 정한다.')
    'backend-dev:1' = @('도메인/서비스 로직 구현 방안을 설계한다 ({FW} 관례 준수).', '에러 처리·트랜잭션 경계·동시성·부수효과를 짚는다.', '기존 코드 재사용 지점과 새로 만들 부분을 구분한다.')
    'backend-dev:2' = @('공개 인터페이스/엔드포인트 계약을 설계한다: 입출력 스키마, 상태코드, 버전·하위호환.', '검증(validation)과 직렬화 전략 ({FW}).', '호출자 관점의 사용성과 오용 방지.')
    'backend-dev:3' = @('{FW} 로 작성할 테스트 케이스를 설계한다: 정상/경계/실패 경로.', '동작 검증 vs 구현 결합, mock 최소화, 결정성(시간/난수) 확보.', '버그 수정에는 회귀 테스트를 동반한다.')
    'backend-dev:4' = @('변경이 기존 관례·아키텍처를 따르는지 본다 (이웃 파일 인용).', '가독성·명명·응집/결합, 누락된 엣지케이스.', '보안·성능상 명백한 위험.')

    'frontend-dev:0' = @('설계를 잡는다: 컴포넌트 구조, 상태 위치, 라우팅/데이터 흐름.', '팀원 산출을 종합해 단일 UI 구현 청사진을 만든다.', '재사용 가능한 부분과 신규 구현을 구분한다.')
    'frontend-dev:1' = @('컴포넌트 분해와 재사용을 설계한다 ({FW}).', 'props/이벤트 계약, 합성(composition), 접근성 기본(시맨틱/포커스).', '과도한 추상화 없이 최소 단위로.')
    'frontend-dev:2' = @('상태·데이터 흐름을 설계한다 ({FW}).', '서버 상태 vs UI 상태 분리, 캐싱/무효화, 로딩·에러·빈 상태.', '불필요한 리렌더/재계산 회피.')
    'frontend-dev:3' = @('스타일·반응형·UX 를 설계한다 ({FW} 관례).', '디자인 토큰 일관성, 다크모드, 모션(prefers-reduced-motion).', '레이아웃 시프트·반응형 분기.')
    'frontend-dev:4' = @('{FW} 로 작성할 테스트를 설계한다: 컴포넌트/상호작용/E2E.', '구현 세부가 아닌 사용자 동작 검증, 깨지기 쉬운 셀렉터 회피.', '결정성(네트워크/시간) 확보.')

    'infra:0' = @('배포 토폴로지·환경 분리·롤백 전략을 잡는다.', '팀원 산출을 종합해 단일 인프라 계획을 만든다.', '리스크와 단계적 적용 순서를 명시한다.')
    'infra:1' = @('CI/CD 파이프라인을 설계한다 ({FW}).', '빌드/테스트/배포 단계, 캐시, 병렬화, 머지 게이트.', '실패 시 빠른 피드백과 재현성.')
    'infra:2' = @('컨테이너/IaC 를 본다 ({FW}).', '이미지 빌드·헬스체크·무중단/배포 순서·리소스 한계.', '되돌릴 수 있는 배포와 마이그레이션 안전.')
    'infra:3' = @('로깅/지표/추적을 설계한다.', '알람 임계치, 대시보드, 비밀·개인정보 마스킹.', '장애 시 원인 추적 단서 확보.')
    'infra:4' = @('시크릿 관리·최소권한·접근제어를 본다.', '의존성/이미지 취약점, 네트워크 경계, 공급망.', '하드코딩된 비밀·과한 권한 탐지.')

    'design:0' = @('문제를 정의하고 디자인 원칙·방향을 잡는다.', '팀원 산출을 종합해 단일 디자인 방향을 만든다.', '제약(플랫폼/접근성/브랜드)을 명시한다.')
    'design:1' = @('사용자 플로우와 정보 구조를 설계한다.', '엣지/빈/에러 상태, 인지 부하, 단계 최소화.', '주요 흐름과 대안/실패 흐름.')
    'design:2' = @('디자인 시스템·토큰 일관성을 본다 ({FW}).', '컴포넌트 재사용, 시각 위계, 간격/타이포 스케일.', '일회성 스타일 남발 경계.')
    'design:3' = @('접근성을 본다 ({FW}): 키보드, 시맨틱/ARIA, 대비, 포커스, 터치 타깃.', '색만으로 의미 전달 금지, 대체 텍스트.', '정적으로 확정 못 하는 건 확인 필요로.')
    'design:4' = @('카피·마이크로카피를 본다.', '명확성, 톤 일관성, 에러 메시지의 행동 유도.', '국제화/길이 변동 고려.')

    'planning:0' = @('문제·목표를 명확히 하고 범위를 잡는다(포함/비포함).', '팀원 산출을 종합해 단일 명세로 만든다.', '우선순위와 열린 질문을 정리한다.')
    'planning:1' = @('수용 기준(AC)을 검증 가능하게 작성한다: Given/When/Then.', '"잘 동작한다" 류 금지 — 통과/실패를 같게 판정할 수 있게.', '모호한 결정은 합리적 기본값으로 메우고 그렇게 적는다.')
    'planning:2' = @('주요 사용자 시나리오를 단계로 정리한다.', '대안·실패·엣지 흐름을 포함한다.', '관련 기존 동작을 Read/Grep 으로 확인한다.')
    'planning:3' = @('기술적·운영적 리스크와 의존성을 짚는다.', '되돌릴 수 없는 변경·마이그레이션·외부 연동.', '완화책 또는 단계적 접근을 제안한다.')
    'planning:4' = @('성공을 판단할 관찰 가능한 지표를 정의한다.', '측정 방법과 기준선(baseline)을 명시한다.', '과도한 지표 남발 경계 — 핵심만.')
}

# ---- 팀 설정 (roster = 리드 포함 5명, 역할 슬롯 순서, 전역 유일) --------
$Teams = @(
    @{ slug='planning';               type='planning';     title='기획/계획 팀';                  fw='도메인 무관 · AC/시나리오/리스크/지표';                            roster=@('carrick','mainoo','cunha','collyer','fredricson') }
    @{ slug='backend-dev-kotlin';     type='backend-dev';  title='백엔드 개발 팀 (Kotlin)';        fw='Kotlin · Spring Boot/Ktor · Gradle · JUnit5/MockK';               roster=@('holland','kone','leon','mather','biancheri') }
    @{ slug='backend-dev-java';       type='backend-dev';  title='백엔드 개발 팀 (Java)';          fw='Java · Spring Boot · Maven/Gradle · JUnit5/Mockito';              roster=@('woodgate','mazraoui','amass','bradbury','ajayi') }
    @{ slug='backend-dev-typescript'; type='backend-dev';  title='백엔드 개발 팀 (TypeScript)';    fw='TypeScript · NestJS/Express · Node · Jest/Vitest';                roster=@('evans','mbeumo','amad','barbosa','obi') }
    @{ slug='frontend-dev-compose';   type='frontend-dev'; title='프론트엔드 팀 (Kotlin Compose)'; fw='Kotlin · Jetpack Compose · StateFlow/Coroutines · Compose UI Test'; roster=@('binnion','wheatley','sesko','gabriel','kukonki') }
    @{ slug='frontend-dev-svelte';    type='frontend-dev'; title='프론트엔드 팀 (Svelte)';         fw='Svelte 5 runes/SvelteKit · Vite · stores · Vitest/Playwright';    roster=@('maguire','fitzgerald','zirkzee','devaney','armer') }
    @{ slug='frontend-dev-react';     type='frontend-dev'; title='프론트엔드 팀 (React)';          fw='React 19 · hooks · Vite/Next · Vitest/RTL/Playwright';            roster=@('deligt','munro','dorgu','ogunneye','aljofree') }
    @{ slug='frontend-dev-vue';       type='frontend-dev'; title='프론트엔드 팀 (Vue)';            fw='Vue 3 Composition API · Pinia · Vite · Vitest/Playwright';        roster=@('mount','bayindir','ugarte','byrnehughes','watson') }
    @{ slug='infra';                  type='infra';        title='인프라 팀';                     fw='Docker · CI(GitHub Actions/GitLab) · IaC · 모니터링';              roster=@('mawson','heaton','harrison','heath','murdock') }
    @{ slug='design';                 type='design';       title='디자인 팀';                     fw='WCAG 2.1 AA · 디자인 시스템/토큰 · 프로토타입';                     roster=@('martinez','heaven','lacey','jfletcher','tfletcher') }
)

# ---- 전역 유일성 검증 ---------------------------------------------------
$allPicked = @($Reserved) + @($Teams | ForEach-Object { $_.roster })
$dups = $allPicked | Group-Object | Where-Object { $_.Count -gt 1 }
if ($dups) { throw "전역 중복 인물: $(($dups | ForEach-Object { $_.Name }) -join ', ')" }
$unknown = $allPicked | Where-Object { -not $Squad.ContainsKey($_) } | Select-Object -Unique
if ($unknown) { throw "스쿼드 풀에 없는 인물: $($unknown -join ', ')" }

# ---- 페르소나 본문 생성 -------------------------------------------------
function New-Persona($slug, $player, $teamTitle, $roleTitle, $bullets, $isLead, $fw, $model, $usage) {
    $name = $Squad[$player]
    $L = New-Object System.Collections.Generic.List[string]
    $L.Add('---')
    $L.Add("name: $slug-$player")
    $L.Add("description: ${teamTitle}의 ${roleTitle}. $fw 기준. psmux 팀 멤버(읽기 전용 자문).")
    $L.Add('tools: Read, Grep, Glob')
    $L.Add("model: $model")
    $L.Add('---')
    $L.Add('')
    $bulletText = ($bullets | ForEach-Object { "- " + ($_ -replace '\{FW\}', $fw) }) -join "`n"
    if ($isLead) {
        $L.Add("너는 $name — ${teamTitle}의 주장이다. 팀원들의 산출물을 모아 하나로 종합한다.")
        $L.Add('스스로 처음부터 다 하지 않는다 — 종합이 네 일이다.')
    } else {
        $L.Add("너는 $name — ${teamTitle}의 ${roleTitle}다.")
        $L.Add("$fw 기준. 코드를 직접 수정하지 않는다 — 네 관점의 분석·계획·리뷰를 낸다.")
    }
    $L.Add("> 모델 ``$model`` · 예상 사용량 $usage — 토큰·시간 효율을 위해 역할에 맞춰 배정됨.")
    if ($isLead) {
        $L.Add(''); $L.Add('## 한다'); $L.Add($bulletText)
        $L.Add(''); $L.Add('## 종합 산출')
        $L.Add('지정된 경로의 팀원 보고서를 모두 Read 로 읽고, 중복을 합쳐 단일 계획/결론을 만든다.')
        $L.Add('충돌하는 의견은 양쪽을 제시하고 판단 근거를 댄다. 각 항목에 출처 팀원을 표기한다. 코드를 직접 수정하지 않는다.')
        $L.Add(''); $L.Add('## 규율')
        $L.Add('- 팀원 근거에 기반한다. 검증을 위해서만 코드를 Read/Grep 한다.')
        $L.Add('- 억지로 문제를 만들지 않는다. 깔끔하면 그렇게 말한다.')
    } else {
        $L.Add(''); $L.Add('## 본다 / 한다'); $L.Add($bulletText)
        $L.Add(''); $L.Add('## 산출')
        $L.Add('역할 관점의 권고/계획을 항목으로 정리한다. 관련 코드는 file_path:line 으로 인용한다.')
        $L.Add("확신이 안 서면 '확인 필요'로 표시한다. 다른 facet 은 동료 몫이니 침범하지 않는다.")
        $L.Add(''); $L.Add('## 규율')
        $L.Add('- 추측 금지 — 실제 코드를 Read/Grep/Glob 으로 확인한다.')
        $L.Add('- 기존 관례 > 내 선호. 한 프로젝트의 일관성이 우선.')
    }
    $L.Add('')
    return ($L -join "`n")
}

function Write-Utf8($path, $content) {
    if ($PSCmdlet.ShouldProcess($path, 'write')) {
        [System.IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "  $($path.Replace($repoRoot + '\', ''))" -ForegroundColor Green
    }
}

# ---- 생성 루프 ----------------------------------------------------------
foreach ($t in $Teams) {
    if (($t.roster | Select-Object -Unique).Count -ne $t.roster.Count) { throw "[$($t.slug)] 팀 내 중복." }
    $titles = $RoleTitles[$t.type]
    $models = $RoleModel[$t.type]
    $dir = Join-Path $teamsDir $t.slug
    if (Test-Path $dir) { if ($PSCmdlet.ShouldProcess($dir, 'clean')) { Remove-Item -Recurse -Force $dir } }
    if ($PSCmdlet.ShouldProcess($dir, 'mkdir')) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Write-Host "[$($t.slug)] $($t.title)" -ForegroundColor Cyan

    $members = @()
    for ($i = 0; $i -lt $t.roster.Count; $i++) {
        $player = $t.roster[$i]
        $model  = $models[$i]
        $usage  = Get-Usage $model
        $isLead = ($i -eq 0)
        $bullets = $RoleBullets["$($t.type):$i"]
        $md = New-Persona $t.slug $player $t.title $titles[$i] $bullets $isLead $t.fw $model $usage
        Write-Utf8 (Join-Path $dir "$player.md") $md
        if (-not $isLead) {
            $members += [ordered]@{ name=$player; file="$player.md"; role=$titles[$i]; model=$model; usage=$usage; pos=$Formation[$i].pos; x=$Formation[$i].x; y=$Formation[$i].y }
        }
    }

    $leadModel = $models[0]
    $manifest = [ordered]@{
        team = '' + $t.slug; title = $t.title; stack = $t.fw; mode = 'advisory'
        lead = [ordered]@{ name=$t.roster[0]; file="$($t.roster[0]).md"; role=$titles[0]; model=$leadModel; usage=(Get-Usage $leadModel); pos=$Formation[0].pos; x=$Formation[0].x; y=$Formation[0].y }
        members = $members
    }
    Write-Utf8 (Join-Path $dir 'team.json') ($manifest | ConvertTo-Json -Depth 6)
}

Write-Host "`n생성 완료. 팀 $($Teams.Count)개, 인물 $(($Teams | ForEach-Object { $_.roster }).Count)명 (전역 유일)." -ForegroundColor Cyan
