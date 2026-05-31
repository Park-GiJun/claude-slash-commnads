---
description: README.md / CLAUDE.md 등 프로젝트 문서를 실제 코드 상태와 대조해 어긋난 부분만 갱신한다
argument-hint: [대상 문서 경로] (생략 시 README.md, CLAUDE.md 자동 탐색)
allowed-tools: Read, Grep, Glob, Edit, Bash
---

`$ARGUMENTS` 에 경로가 있으면 그 문서를, 없으면 저장소 루트의 `README.md` 와 `CLAUDE.md`(있으면)를 대상으로 한다.

문서를 새로 쓰는 게 아니라 **현실과 어긋난 부분만 고친다.** 멀쩡한 서술은 건드리지 않는다.

### 1. 문서의 주장 수집
대상 문서를 읽고, 코드로 검증 가능한 사실 주장들을 뽑는다:
설치/실행 명령, 스크립트 이름, 디렉터리 구조, 의존성/버전, 환경변수, 진입점, 기능 목록 등.

### 2. 코드와 대조
각 주장을 실제 파일로 확인한다 — 추측 금지.
- 명령/스크립트: `package.json`, `Makefile`, `build.gradle`, `pyproject.toml` 등
- 구조: 실제 디렉터리/파일 존재 여부 (Glob)
- 의존성/버전: 매니페스트 파일
- 환경변수·설정: 코드에서 실제로 읽는 키

### 3. 드리프트만 수정
어긋난 항목만 Edit 으로 고친다. 새 섹션을 무단으로 추가하지 않는다 —
명백히 빠진 핵심(예: 빌드 명령 누락)이 있으면 추가를 제안하되 사용자 확인을 받는다.

### 4. 보고
무엇이 어긋나 있었고 무엇을 고쳤는지 목록으로. 확신이 안 서 손대지 않은 항목도 함께 남긴다.

### 대시보드 추적
- 시작 시: `powershell -File scripts/log-command.ps1 -Command sync-docs -Status running -Note "<대상 요약>"`
- 종료 시: `powershell -File scripts/log-command.ps1 -Command sync-docs -Status done` (실패 시 `-Status error`)
- 이 기록은 대시보드 "커맨드" 탭에 표시된다. 로깅 실패는 무시하고 본 작업을 계속한다.
