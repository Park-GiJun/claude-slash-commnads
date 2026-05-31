---
description: 문서 기반 팀 파이프라인 — working tree 문서화 → planning 팀 먼저 → 후속 팀 → 산출물 종합
argument-hint: <작업 지시> [-- 팀 슬러그들 또는 all]  예) 결제모듈 추가 -- review-team backend-dev-kotlin
allowed-tools: Bash
---

`$ARGUMENTS` 를 파싱한다: `--` 앞은 작업 지시(Task), 뒤는 후속 팀 슬러그 목록(공백 구분). 팀 목록이
없으면 `review-team` 만, `all` 이면 planning 제외 전체 팀이 후속으로 돈다.

### 실행
파이프라인을 백그라운드로 띄운다(이 세션을 막지 않게):

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-pipeline.ps1 -Task "<작업>" -Teams <t1>,<t2> -Cwd "<현재 저장소>"
```

파이프라인 단계:
1. **working tree → 문서** (`00-worktree.md`): git status·diff·파일목록 스냅샷.
2. **planning 팀 먼저**: 그 문서로 계획 수립 → `10-plan.md`.
3. **후속 팀**(문서 기반): 각 팀이 계획 문서를 입력으로 분석 → `20-<팀>.md`.
4. **산출물 종합** → `90-summary.md`.

각 팀은 psmux 분할 패널에서 멤버가 동시에 돌고(팀원별 배정 모델 `--model`), 주장이 종합한다.

### 안내
- 전제: `psmux`(또는 `pmux`/`tmux`)·`claude` CLI 가 PATH 에, 대상은 git 저장소.
- 실행은 **순차**(planning 완료 후 후속 팀)다 — 의존성과 토큰/시간 관리를 위해.
- 끝나면 런처가 출력한 `90-summary.md` 경로를 읽어 사용자에게 핵심을 요약해 줘도 된다.
- 흐름만 점검하려면 스크립트에 `-DryRun` 을 붙인다(실제 claude 실행 없음).

### 대시보드 추적
- 시작 시: `powershell -File scripts/log-command.ps1 -Command squad -Status running -Note "<작업 요약>"`
- 종료 시: `powershell -File scripts/log-command.ps1 -Command squad -Status done` (실패 시 `-Status error`)
- 이 기록은 대시보드 "커맨드" 탭에 표시된다. 로깅 실패는 무시하고 본 작업을 계속한다.
