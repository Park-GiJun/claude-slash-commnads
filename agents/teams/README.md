# 멀티에이전트 팀 (psmux) + 문서 기반 파이프라인

팀 = 디렉터리. 팀원 = **맨유 25/26 인물**(1군 + U21 + Carrick 체제 코칭스태프) 이름의 자문 에이전트.
각 팀원이 자기 관점으로 **동시에**(psmux 분할 패널) 입력을 검토하고 주장(lead)이 종합한다.
**한 사람 = 한 팀**(전역 유일, 총 56명).

## 두 가지 실행 방식

### 1. 단일 팀 — `/team <팀> [초점]` → `scripts/run-team.ps1`
한 팀을 띄워 현재 git 변경분(또는 `-InputDoc` 문서)을 검토한다.

### 2. 문서 기반 파이프라인 — `/squad <작업> -- <팀들|all>` → `scripts/run-pipeline.ps1`
```
working tree ──▶ 00-worktree.md          (1) 워킹트리 문서화
                     │
              planning 팀                 (2) 계획 먼저 (Carrick + 4)
                     ▼  10-plan.md
        후속 팀들 (문서 기반, 순차)        (3) 계획 문서를 입력으로 각 팀 분석
                     ▼  20-<팀>.md
                90-summary.md             (4) 산출물 종합
```
**모든 후속 동작은 planning 팀의 계획 문서를 입력으로** 한다. 순차 실행(의존성·토큰/시간 관리).

## 모델/사용량 (토큰·시간 최적화)

팀원마다 역할 무게에 맞는 모델이 배정된다 (team.json·페르소나 frontmatter·런처 `--model`). 3티어:
- **opus (심층)** — 주장/리드(팀원 종합·머지 판단). 팀당 1명.
- **sonnet (표준)** — 심층 분석(보안/아키텍처/정확성/AC/API/배포/보안 등).
- **haiku (경량)** — 좁고 정형적인 역할(스타일/콘텐츠/CI 설정/관측성/테스트 작성 등).

현재 분포: opus 11(리드) · sonnet 24 · haiku 21.

## 실행 방식 — 자문(advisory) 모드
런처는 병렬 **읽기 전용**(`Read,Grep,Glob`)이라 동시 코드 수정 충돌이 없다. 팀은 코드를 직접
고치지 않고 **분석·계획·리뷰**를 산출한다. (코드 작성형 = worktree 격리, 후속 과제.)

## 전제 조건
- `psmux`(또는 `pmux`/`tmux`)·`claude` CLI 가 PATH 에. 대상은 git 저장소.
- `.ps1` 은 **UTF-8 with BOM**(PS 5.1 한글). 런처는 `.md`/`.json` 을 `-Encoding UTF8` 로 읽는다.
- 흐름만 점검: 스크립트에 `-DryRun`.

## 팀 로스터 (11팀 · 56명, 전역 유일)

| 팀 | 리드 | 멤버 (역할 슬롯 순서) |
|---|---|---|
| **review-team** | Bruno (주장) | Casemiro 보안 · Yoro 구조 · Shaw 정확성 · Dalot 성능 · Lammens 검증 |
| **planning** | **Carrick** (HC) | Mainoo AC · Cunha 시나리오 · Collyer 리스크 · Fredricson 지표 |
| **backend-dev-kotlin** | Holland | Koné 구현 · León API · Mather 테스트 · Biancheri 리뷰 |
| **backend-dev-java** | Woodgate | Mazraoui 구현 · Amass API · Bradbury 테스트 · Ajayi 리뷰 |
| **backend-dev-typescript** | Evans | Mbeumo 구현 · Amad API · Barbosa 테스트 · Obi 리뷰 |
| **frontend-dev-compose** | Binnion | Wheatley 컴포넌트 · Šeško 상태 · Gabriel 스타일 · Kukonki 테스트 |
| **frontend-dev-svelte** | Maguire | Fitzgerald 컴포넌트 · Zirkzee 상태 · Devaney 스타일 · Armer 테스트 |
| **frontend-dev-react** | De Ligt | Munro 컴포넌트 · Dorgu 상태 · Ogunneye 스타일 · Aljofree 테스트 |
| **frontend-dev-vue** | Mount | Bayındır 컴포넌트 · Ugarte 상태 · Byrne-Hughes 스타일 · Watson 테스트 |
| **infra** | Mawson (GK코치) | Heaton CI/CD · Harrison 배포 · Heath 관측성 · Murdock 보안 *(전원 GK = 최후방/안정성)* |
| **design** | Martínez | Heaven UX · Lacey 비주얼 · J.Fletcher 접근성 · T.Fletcher 콘텐츠 |

> 역할 슬롯: **backend** 아키텍트·구현·API·테스트·리뷰 / **frontend** 리드·컴포넌트·상태·스타일·테스트 /
> **infra** 리드·CI/CD·배포·관측성·보안 / **design** 리드·UX·비주얼·접근성·콘텐츠 /
> **planning** 리드·AC·시나리오·리스크·지표. 모델은 역할 슬롯 기준(위 *모델/사용량* 참조) —
> 각 팀은 1군 멤버를 최소 1명 포함하도록 균형 배치했다.

## 팀 추가/수정
`scripts/gen-teams.ps1` 의 `$Squad`/`$Teams`/`$RoleModel` 설정만 고치고 재실행한다
(BOM 변환 후 실행). 전역 유일성·미등록 인물은 생성 시 검증된다. review-team 은 손작성(기준 팀).
런처/파이프라인은 `team.json` 만 읽으므로 코드 수정 불필요.
