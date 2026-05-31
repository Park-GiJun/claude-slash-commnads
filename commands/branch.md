---
description: 작업 내용을 분석해 의미가 드러나는 프리픽스 브랜치를 기본 브랜치에서 만든다
argument-hint: [작업 설명] (생략 시 현재 변경분/맥락에서 추론)
allowed-tools: Bash, Read
---

`$ARGUMENTS` 가 작업 설명이면 그걸 쓰고, 비어 있으면 `git status`/`git diff` 와 대화 맥락에서 작업 성격을 추론한다.

### 1. 유형 결정
작업 성격에 맞는 프리픽스 하나를 고른다:
`feat`(기능) · `fix`(버그) · `refactor` · `perf` · `test` · `docs` · `chore` · `build`.

### 2. 슬러그 작성
- kebab-case, 핵심 키워드 3~5개. 예: `feat/user-export-csv`, `fix/null-token-refresh`.
- 한글 작업명은 영어로 짧게 옮긴다. 이슈 번호가 있으면 `<type>/<num>-<slug>` 형태도 가능.

### 3. 생성
기본 브랜치(`main`/`master`)가 최신인지 확인하고, 거기서 새 브랜치를 만들어 체크아웃한다.
이미 커밋되지 않은 변경이 있으면 그대로 따라오므로 그 사실만 알린다.
생성한 브랜치명을 보고한다.
