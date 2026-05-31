---
description: 맨유 선수 이름의 멀티에이전트 팀을 psmux 분할 패널에서 병렬 실행한다 (예: 리뷰 팀)
argument-hint: <팀이름> [초점/지시]  예) review-team 결제 모듈 집중
allowed-tools: Bash
---

`$ARGUMENTS` 의 첫 토큰이 팀 이름, 나머지가 팀에 줄 초점/지시다. 팀 이름이 없으면
`agents/teams/` 의 사용 가능한 팀 목록을 보여주고 멈춘다.

### 실행
런처를 백그라운드로 띄운다 (이 세션을 막지 않도록 `-NoAttach`):

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-team.ps1 -Team <팀이름> -Task "<나머지 지시>" -NoAttach
```

- `psmux`(또는 `pmux`/`tmux`)와 `claude` CLI 가 PATH 에 있어야 한다. 없으면 런처가
  명확히 알려주니 그 메시지를 그대로 사용자에게 전달한다.
- 성공하면 런처가 출력한 **attach 명령**과 **출력 경로**를 사용자에게 안내한다.
  사용자는 `! psmux attach -t <session>` 으로 패널을 실시간 관찰할 수 있다.

### 안내
- 각 팀원이 자기 관점으로 동시에 변경분을 리뷰하고, 주장(lead)이 완료를 기다렸다가
  `_summary.md` 로 종합한다. 종합이 끝나면 그 파일을 읽어 사용자에게 핵심을 요약해 줘도 된다.
- 무엇이 잘못됐는지 확인이 필요하면 `-DryRun` 으로 실제 실행 없이 생성될 명령만 볼 수 있다.

### 대시보드 추적
- 시작 시: `powershell -File scripts/log-command.ps1 -Command team -Status running -Note "<팀·초점 요약>"`
- 종료 시: `powershell -File scripts/log-command.ps1 -Command team -Status done` (실패 시 `-Status error`)
- 이 기록은 대시보드 "커맨드" 탭에 표시된다. 로깅 실패는 무시하고 본 작업을 계속한다.
