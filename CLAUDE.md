# CLAUDE.md

이 저장소에서 작업할 때 따라야 할 규칙. Zanata → Weblate 번역 리소스
마이그레이션 도구(`migration_resources.sh`, `migration_projects.sh`,
`test_accuracy/`, `common/weblate_utils.py` 등)에 관한 작업이며, 현재
진행 중인 목표는 "마이그레이션 현황을 신뢰성 있게, 사람이 검증하기
쉬운 형태로 파악할 수 있게 만드는 것"이다.

## 문서 구조

`~/claude-docs`는 저장소 밖, 로컬에만 존재하는 디렉터리다 (git으로
버전 관리되지 않고, 원격에 올라가지 않는다). 이 저장소를 위한 문서는
`~/claude-docs/weblate-migration/` 아래에 있다.

이 프로젝트에는 goal이 여러 개 있을 수 있다. **goal마다 별도
폴더**로 관리한다 — 여러 goal의 문서를 한 폴더에 섞지 않는다:

```
~/claude-docs/weblate-migration/
  <goal-slug>/
    goal.md              # 이 goal의 진행 상태 트래커
    phase-N-<slug>.md    # Phase 하나의 자세한 실행 기록
  <다른-goal-slug>/
    goal.md
    ...
```

- **`PLAN.md`** (이 저장소): 무엇을, 왜 고쳐야 하는지에 대한 진단과
  Phase별 계획, 그리고 정합성 판단 기준점에 대한 근거. 이 파일이
  바뀌면 "왜"가 바뀐 것이다. **저장소당(goal당이 아니라) 하나만
  둔다** — goal이 여러 개여도 진단·계획의 근거는 이 저장소를 대상으로
  한 것이므로 하나로 합쳐서 관리한다. 새 goal이 생기면 PLAN.md에
  절을 추가하고, 그 절에서 해당 goal 폴더의 `goal.md`로 링크한다.
- **`<goal-slug>/goal.md`**: 그 goal의 Phase별 진행 상태 트래커. 각
  Phase의 상태(완료/진행중/예정), PR 링크, 결과 문서 링크를 표로
  관리한다. 새 Phase를 시작하거나 끝낼 때마다 갱신한다. 현재 활성
  goal 폴더는 `migration-status-tracking`이다.
- **`<goal-slug>/phase-N-<slug>.md`**: Phase 하나의 자세한 실행
  기록. 구조는 문제 → 수정 내용 → 검증 → 리뷰 → 결과 순서를 따른다
  (`migration-status-tracking/phase-1-*.md`,
  `migration-status-tracking/phase-2-*.md` 참고). **PLAN.md나
  goal.md에 실행 세부사항을 직접 적지 않는다** — 반드시 별도 파일로
  분리한다.
- 이 구조와 무관하게, 사용자가 goal 폴더 밖에 직접 만든 메모 파일
  (예: `migration-plan.md`)이 있을 수 있다. 그런 파일은 옮기거나
  구조에 편입시키지 않고 그대로 둔다.

## 작업 절차 (Phase 하나당)

1. **브랜치**: `stats`에서 분기한 `phase-N-<slug>` 브랜치에서 작업한다.
   PR의 base는 항상 `stats`이며 `main`이 아니다.
2. **범위**: 해당 Phase가 다루는 문제만 고친다. 작업 중 발견한 별개의
   문제는 곧바로 고치지 말고 PLAN.md에 새 Phase(문제 진단 + 계획)로
   추가해두고, 지금 하는 작업은 원래 범위대로 끝낸다.
3. **검증**: 구현 후 최소한 아래를 직접 실행해서 확인한다. 이
   저장소에는 자동 테스트가 없으므로 사람이 하듯 수동으로 재현해야
   한다.
   - Bash 변경: `bash -n <file>` 구문 검사, 실패/성공 케이스를 별도로
     재현해 실제 동작 확인 (예: 가짜 실패를 일으켜 exit code가 제대로
     잡히는지 등).
   - Python 변경(`common/weblate_utils.py`): `~/workspace/.venv`에
     `polib`/`requests`/`flake8`가 설치되어 있으니 그걸로
     `py_compile`, `flake8`을 돌리고, 픽스처 PO 파일을 만들어 CLI를
     직접 호출해 pass/fail 시나리오를 확인한다.
4. **리뷰**: `/code-review medium`으로 리뷰받는다. 발견된 이슈는:
   - 실제 결함이면 고치고 다시 검증한다 (여러 라운드가 필요할 수
     있음 — Phase 2에서는 3라운드+검증 에이전트 1회가 필요했다).
   - 지금 범위 밖이거나 현재 규모에서 실질적 영향이 없다고 판단되면,
     **조용히 넘어가지 말고** 결과 문서에 "의도적으로 보류한 항목"
     섹션으로 근거와 함께 남긴다.
   - 리뷰 중 이번 Phase와 무관한 별개의 심각한 문제를 발견하면,
     그 자리에서 고치지 말고 PLAN.md에 새 Phase로 추가하고 결과
     문서에도 "리뷰 중 발견한 별도의 이슈" 섹션으로 남긴다 (Phase 2
     작업 중 발견한 exit-code 미전파 문제가 이 패턴의 예시).
5. **커밋**: 이 Phase와 관련 없는 파일은 절대 커밋하지 않는다.
   `git status`로 스테이징 전에 항상 확인할 것 — 특히 `list.txt`는
   이 작업들과 무관한 로컬 수정이 계속 남아있으니 건드리지 않는다.
6. **문서화**: 해당 goal 폴더에
   `~/claude-docs/weblate-migration/<goal-slug>/phase-N-<slug>.md`를
   작성한 후, 같은 폴더의 `goal.md` 상태 표를 갱신한다.
7. **PR**: `git push -u origin phase-N-<slug>` 후
   `gh pr create --base stats --head phase-N-<slug>`로 PR을 올린다.
   PR 본문에 요약, 테스트 내역(체크리스트), 결과 문서 경로, (있다면)
   범위 밖 이슈를 적는다.

## 자동 머지 권한

**아래 조건을 모두 만족하면, 사용자에게 다시 묻지 않고 PR을 바로
머지해도 된다** (`gh pr merge --merge --delete-branch`):

- 4단계 리뷰에서 미해결 CONFIRMED 결함이 없다 (고쳤거나, 근거를 남기고
  의도적으로 보류한 상태).
- 3단계 검증을 실제로 수행했고 통과했다.
- 6단계 결과 문서와 `goal.md` 갱신이 끝났다.
- PR의 base가 `stats`이다.

**이 권한의 범위를 벗어나면 반드시 사용자에게 먼저 확인한다**:
`main` 브랜치로의 머지, force-push, 리뷰에서 못 고친 CONFIRMED 결함이
남은 상태의 머지, `stats` 브랜치 자체에 대한 `reset`/`rebase`/히스토리
재작성. 머지가 끝나면 로컬 `stats`를 pull하고, 머지된 원격 브랜치의
로컬 잔여 참조를 `git fetch --prune`으로 정리한다.

## 환경 메모

- GitHub CLI(`gh`)는 계정 `S0okJu`로 인증되어 있다.
- origin: `https://github.com/S0okJu/openstack-weblate-migration.git`
  (원격에는 `main`, `stats`만 존재; 각 Phase 브랜치는 PR 머지 후
  삭제한다).
- `tox.ini`에 `pep8`(flake8), `doc8` 환경이 정의돼 있지만 이
  샌드박스에는 프로젝트 venv가 없다. 대신
  `~/workspace/.venv`(과거 다른 프로젝트 실행 중 생성됨)에 `polib`,
  `requests`, `flake8`이 이미 설치되어 있어 이걸로 대체 검증한다.
