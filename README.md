# claude-slash-commands

도메인에 종속되지 않는 범용 Claude Code 자산 모음 — slash commands, skills, subagents.
특정 언어·프레임워크·프로젝트에 묶이지 않고 어떤 코드베이스에서도 동작하도록 설계합니다.

## 구조

```
commands/   슬래시 커맨드 (.md, 프롬프트 템플릿). /이름 으로 호출
skills/     스킬 (<이름>/SKILL.md). 다단계·점진적 공개가 필요한 작업
agents/     서브에이전트 (.md). 독립 시스템 프롬프트를 가진 전문 에이전트
scripts/    설치/동기화·팀 생성·실행·상태 방출 스크립트
dashboard/  Compose Multiplatform(Wasm) 축구 전술 보드 — 에이전트 시각화
```

## scripts

- `sync.ps1` — `~/.claude` 로 자산 복사
- `gen-teams.ps1` — 팀 생성기 (설정 → team.json + 페르소나, 전역 유일성 검증)
- `run-team.ps1` — 단일 팀 psmux 실행 (`--model`, `-InputDoc`, `-Wait`)
- `run-pipeline.ps1` — 문서 기반 파이프라인 (planning 먼저 → 후속 팀 → 종합)
- `gen-status.ps1` — `.team-runs` 스캔 → `status.json` (대시보드용, `-Watch`)

## dashboard

축구 경기장(포메이션) 위에 spawn된 에이전트를 배치해 상태·업무를 실시간 시각화.
자세한 실행법은 [`dashboard/README.md`](dashboard/README.md). 요약:
`setup.ps1`(wrapper 부트스트랩) → `gen-status.ps1 -Watch`(상태 갱신) → `gradlew wasmJsBrowserDevelopmentRun`.
JDK/Gradle은 wrapper + foojay 툴체인으로 자동 조달.

## 카테고리

| 태그 | 의미 |
|------|------|
| `code`   | 코드 작업 보조 (리팩터링, 설명, 정리) |
| `git`    | Git/PR 워크플로 |
| `docs`   | 문서·글쓰기 |
| `think`  | 사고·계획 보조 |
| `arch`   | 아키텍처 정합성 |
| `test`   | 테스트 코드 작성 |
| `learn`  | 학습 보조 |

## 설치

개발은 이 저장소에서 하고, `scripts/sync.ps1`로 `~/.claude/`에 복사합니다.

```powershell
# 미리보기 (변경 사항만 출력)
powershell -File scripts\sync.ps1 -WhatIf

# 실제 복사
powershell -File scripts\sync.ps1
```

`commands/`, `skills/`, `agents/` 내용이 각각 `~/.claude/commands`, `~/.claude/skills`,
`~/.claude/agents` 로 들어갑니다. 기존 같은 이름 파일은 덮어씁니다.

## 자산 목록

### commands
- `eli5.md` — `/eli5` · `learn` · 코드/개념을 3단계 깊이로 설명
- `commit.md` — `/commit` · `git` · 변경분 분석 → Conventional Commit (기본 브랜치면 브랜치 먼저 생성)
- `branch.md` — `/branch` · `git` · 작업 성격에 맞는 프리픽스 브랜치 생성
- `pr.md` — `/pr` · `git` · 푸시 + 커밋 내역으로 PR 생성 (`gh` 우선, 자동 머지 없음)
- `sync-docs.md` — `/sync-docs` · `docs` · README/CLAUDE.md 를 코드 상태와 대조해 드리프트만 갱신
- `team.md` — `/team` · `arch` · 단일 멀티에이전트 팀을 psmux 패널에서 실행
- `squad.md` — `/squad` · `arch` · 문서 기반 팀 파이프라인 (planning 먼저 → 후속 팀 → 종합)

### skills
- `seed-data/` — `test` · 스키마 제약을 지키는 멱등 시드/픽스처 데이터 생성

### agents/teams — psmux 멀티에이전트 팀 (11팀 · 56명)
맨유 25/26 인물(1군+U21+Carrick 코칭스태프) 이름의 자문 에이전트가 psmux 분할 패널에서
**동시에** 돌고 주장이 종합한다. **한 사람 = 한 팀**(전역 유일). 팀원마다 모델/사용량 배정
(sonnet=심층, haiku=경량)으로 토큰·시간 최적화. 자세한 로스터·동작은
[`agents/teams/README.md`](agents/teams/README.md).

- **단일 팀**: `/team <팀> [초점]` → `scripts/run-team.ps1`
- **파이프라인**: `/squad <작업> -- <팀들|all>` → `scripts/run-pipeline.ps1`
  (working tree 문서화 → **planning 먼저** → 후속 팀 문서 기반 → `90-summary.md` 종합)
- 팀 생성기: `scripts/gen-teams.ps1` (설정만 고쳐 재생성)
- 팀: review-team, planning, backend-dev-{kotlin,java,typescript},
  frontend-dev-{compose,svelte,vue,react}, infra, design

> 인코딩 주의: `scripts/*.ps1` 은 **UTF-8 with BOM** 으로 저장한다 (Windows PowerShell 5.1 이
> BOM 없는 UTF-8 의 한글을 CP949 로 오독해 파싱이 깨지기 때문). 런처는 `.md`/`.json` 을
> `-Encoding UTF8` 로 읽는다.
