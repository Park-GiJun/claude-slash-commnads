---
description: 변경분을 분석해 Conventional Commit 메시지를 만들고 커밋한다. 기본 브랜치에 있으면 먼저 적절한 프리픽스 브랜치를 만든다.
argument-hint: [추가 맥락/지시] (선택)
allowed-tools: Bash, Read, Grep
---

`$ARGUMENTS` 는 커밋에 반영할 추가 맥락이 있으면 쓴다. 없으면 변경분만으로 판단한다.

### 0. 브랜치 가드
`git branch --show-current` 와 `git status` 를 확인한다. 현재가 기본 브랜치
(`main`/`master`)이면 커밋 전에 작업 성격에 맞는 프리픽스 브랜치를 만들어 옮긴다:
`feat|fix|refactor|perf|test|docs|chore|build/<kebab-slug>`. 이미 작업 브랜치면 그대로 둔다.

### 1. 변경 분석
`git status` 와 `git diff`(스테이징/언스테이징 모두)를 본다. 무엇이 왜 바뀌었는지 파악한다.
- 자격증명·`.env`·키 파일이 포함돼 있으면 스테이징에서 제외하고 사용자에게 알린다.
- 서로 무관한 변경이 섞여 있으면 한 번에 묶지 말고 논리 단위로 나눌지 제안한다.

### 2. 메시지 작성
Conventional Commits 형식:
```
<type>(<scope>): <명령형 한 줄 요약>

<무엇을·왜 — 변경 이유. how 가 아니라 why>
```
- `type`: feat/fix/refactor/perf/test/docs/chore/build 중 변경 성격에 맞게.
- `scope`: 영향받은 모듈/영역 (불명확하면 생략).
- 요약은 명령형, 마침표 없이. 본문은 필요할 때만.
- 저장소에 기존 커밋 컨벤션(언어·형식)이 있으면 `git log` 로 확인해 따른다.

### 3. 커밋
필요한 파일을 스테이징하고 커밋한다. **푸시는 하지 않는다** (그건 `/pr` 몫).
커밋 후 `git log -1 --stat` 결과를 짧게 보고한다.

### 대시보드 추적
- 시작 시: `powershell -File scripts/log-command.ps1 -Command commit -Status running -Note "<커밋 요약>"`
- 종료 시: `powershell -File scripts/log-command.ps1 -Command commit -Status done` (실패 시 `-Status error`)
- 이 기록은 대시보드 "커맨드" 탭에 표시된다. 로깅 실패는 무시하고 본 작업을 계속한다.
