# AGENT PITCH — 멀티에이전트 전술 보드

맨유 4-3-3 포메이션으로 멀티에이전트 팀의 작업 상태를 시각화하는 대시보드.
의존성 0개. Node 표준 라이브러리만 사용한다.

## 실행

```bash
cd dashboard
node server.js          # http://localhost:5173
# 또는
npm start
```

포트 변경: `PORT=8080 node server.js`

## 화면 (상단 내비)

- **메인** — 전체 형상. 집계 통계(팀/에이전트/활성/완료/에러)와 팀 그리드.
  팀 카드를 누르면 해당 팀이 선택된 채 **실행 중** 뷰로 이동한다.
- **실행 중** — 피치(전술 보드). 좌측 팀 레일 · 중앙 포메이션 · 우측 업무 현황.
  각 선수(에이전트)가 지금 어떤 상태로 무슨 일을 하는지 실시간 표시(2초 폴링).
- **커맨드** — `commands/` 의 모든 슬래시 커맨드 실행 기록(최신순). 시각·커맨드명·메모·
  상태(running/done/error). 실행 중인 커맨드는 주황으로 점멸.
- **히스토리** — 완료된 런 기록(최신순). 팀이 "전원 done"이 되는 순간 서버가 적립.
  항목을 펼치면 에이전트별 산출 줄수·마지막 줄을 본다.

뷰는 `#main` / `#running` / `#commands` / `#history` 해시로 기억되어 새로고침해도 유지된다.

## 커맨드 추적

`commands/*.md` 의 모든 슬래시 커맨드는 정의 안에 **로깅 단계**를 갖는다. 실행을 시작·종료할 때
`scripts/log-command.ps1` 을 호출해 `public/commands.json` 에 기록한다(running→done/error 갱신,
최근 200건 유지). 대시보드의 **커맨드** 탭이 이 파일을 폴링해 보여준다.

```powershell
powershell -File scripts/log-command.ps1 -Command team -Status running -Note "review-team"
powershell -File scripts/log-command.ps1 -Command team -Status done
```

> 로깅은 cwd가 이 저장소일 때 동작한다(상대경로 `scripts/...`). 다른 저장소에서 슬래시 커맨드를
> 쓰면 스크립트를 못 찾아 조용히 건너뛴다 — 커맨드 본 기능은 영향받지 않는다.

## 데이터 소스

`public/status.json` 을 2초마다 fetch 한다. 생성은 `scripts/gen-status.ps1` 이 담당:
`agents/teams/*/team.json`(팀 매니페스트)과 `.team-runs/<slug>/` 런 산출물을 합쳐
각 선수(에이전트)의 상태·현재 업무·출력 줄수를 채운다.

라이브 갱신:
```powershell
powershell -File scripts\gen-status.ps1 -Cwd <팀을 돌린 저장소> -Watch
```

## 히스토리 적립

`.team-runs/<slug>/` 는 런마다 덮어써져 과거 기록이 사라진다. 그래서 **서버가 보존한다**:
`server.js` 가 `status.json` 변화를 감시하다가, 한 팀이 "전원 done"으로 **새로 전이**하는
순간 그 스냅샷(시각·팀·에이전트별 줄수/마지막 줄)을 `public/history.json` 에 append 한다
(최근 300건 유지). 별도 DB·의존성 없음.

## 구조

- `server.js` — 정적 파일 서버 + 히스토리 적립기 (의존성 0개)
- `public/index.html` — UI 전체 (메인/실행중/히스토리 3개 뷰 + 폴링 JS)
- `public/status.json` — 현재 상태 (샘플 포함, gen-status.ps1 이 덮어씀)
- `public/history.json` — 완료 런 누적 (서버가 자동 적립, 샘플 시드 포함)
- `public/commands.json` — 슬래시 커맨드 실행 기록 (log-command.ps1 이 적립)
- `scripts/gen-status.ps1` — status.json 생성기
- `scripts/log-command.ps1` — 커맨드 실행 로거

## 좌표

선수 위치는 각 에이전트의 `x`/`y`(정규화 0..1)를 그대로 쓴다 — 피치는 세로 방향.
y: 0(위=GK) → 1(아래=공격), x: 0(왼쪽) → 1(오른쪽). 좌표는 `agents/teams/*/team.json`
의 포메이션 값에서 온다.

## 상태 색상

| 상태 | 색 |
|------|----|
| working | `#FFB300` |
| spawning | `#42A5F5` |
| done | `#43A047` |
| error | `#E53935` |
| idle | `#8A8F98` |

> 빌드가 무거운 Compose-for-Web(Kotlin/Wasm) 버전은 폐기하고 이 Node 버전으로 대체했다.
