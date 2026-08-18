# Migration Status Tracking & Correctness Plan

## 배경

Zanata → Weblate 번역 리소스 마이그레이션 도구(`migration_resources.sh`,
`migration_projects.sh`, `test_accuracy/`)는 이미 프로젝트 clone, POT 생성,
Zanata 번역본 export, Weblate 컴포넌트 생성, 정합성 테스트까지 한 번에
수행한다. 하지만 실제 코드를 확인한 결과, "지금 마이그레이션이 전체적으로
얼마나 진행됐고 어디서 실패했는지"를 신뢰성 있게 파악할 방법이 없다는
문제를 발견했다. 이 문서는 무엇을, 왜 고쳐야 하는지를 정리한다.

## 문제 진단

### 1. 배치 실행의 성공/실패 판정이 실제로는 항상 "성공"으로 찍힐 수 있다

`migration_projects.sh:82-93`:

```bash
if "$MIGRATION_SCRIPT" "$project" "$version" 2>&1 | while IFS= read -r line; do
    echo "$version | $line" | tee -a "$LOG_FILE"
    ...
done; then
    echo "[$total_count] Success: ..."
else
    echo "[$total_count] Failed: ... (exit code: $?)"
fi
```

Bash 파이프라인(`cmd | while ...`)의 종료 상태는 기본적으로 **파이프의
마지막 명령**(`while` 루프)의 종료 상태다. `while read` 루프는 입력이
EOF에 도달하면 특별한 사정이 없는 한 exit 0으로 끝나므로, `$MIGRATION_SCRIPT`가
실제로 실패(clone 실패, Weblate API 오류, 정합성 불일치 등)해도 `if` 조건은
참이 되어 "Success"로 기록된다. `set -o pipefail`이 스크립트 어디에도
설정돼 있지 않기 때문이다.

**왜 중요한가**: 이 버그가 있는 한 배치 마이그레이션 로그의 성공/실패
카운트 자체를 신뢰할 수 없다. 현황 파악 기능을 아무리 잘 만들어도
입력 데이터(성공/실패 판정)가 틀리면 의미가 없으므로 가장 먼저 고쳐야
하는 전제 조건이다.

### 2. 정합성 테스트 결과가 구조화된 형태로 저장되지 않는다

`test_accuracy/test.sh`는 `--result-json $RESULT_JSON` 인자를
`weblate_utils.py`의 `check-sentence-count`, `check-sentence-detail`
서브커맨드에 넘긴다. 그런데 `WeblateUtils.__init__`
(`common/weblate_utils.py:108`)은 `result_json_path`를 파라미터로만
받고 `self`에 저장하지 않으며, `check_sentence_count`/
`check_sentence_detail` 두 메서드 어디에서도 이 값을 사용해 파일을
쓰지 않는다. 실제 비교 결과는 `print()`로 표준출력/로그 파일에
텍스트로만 남는다.

**왜 중요한가**:
- 텍스트 로그는 grep으로만 검색 가능해, "몇 개 컴포넌트/로케일이
  통과했는지" 같은 집계 질문에 답하려면 매번 로그를 파싱해야 한다.
- 프로젝트/버전/컴포넌트/로케일 단위의 세부 결과(번역 수 일치 여부,
  mismatch/missing/extra 개수)가 재사용 가능한 데이터로 남지 않으므로,
  나중에 재검증하거나 대시보드를 만들 때 원본 PO 파일을 다시 받아
  전체 테스트를 재실행해야 한다.
- `--result-json` 인자가 이미 스크립트 곳곳에 배선돼 있어(코드를 읽는
  사람은 "결과가 JSON으로 남는다"고 오해하기 쉬움) 유지보수 시 혼란을
  일으킨다.

### 3. 배치 실행 전체를 한눈에 보는 집계 수단이 없다

`migration_projects.sh`는 project × version 조합을 순회하며 프로젝트별
디렉터리(`logs/<project>/`)에 로그를 남기지만, 이를 모아 "전체 N개 중
성공 M개, 실패 K개, 실패 사유별 분류"를 보여주는 단계가 없다. 결과를
알려면 사람이 모든 `error.*.log` 파일을 열어봐야 한다.

**왜 중요한가**: OpenStack 프로젝트 수십~수백 개를 마이그레이션하는
운영 시나리오에서, 실행할 때마다 로그 디렉터리를 손으로 뒤지는 것은
비용이 크고 누락 위험이 있다. 특히 1번 버그로 인해 실패가 "Success"로
잘못 찍히고 있었다면, 지금까지의 마이그레이션 이력 자체를 재검증해야
할 수도 있다.

### 4. 정합성 체크 실패가 실제로는 종료 코드로 전파되지 않는다

Phase 2(`common/weblate_utils.py`) 작업 중 리뷰에서 발견했다.
`check_sentence_count`/`check_sentence_detail`은 불일치를 찾아도
`print(f"[ERROR] ...")`만 하고 `return None`으로 끝난다. `sys.exit(1)`도,
예외 발생도 없다. 그 결과 이 CLI를 호출한 Python 프로세스는 정합성
검사가 실패했더라도 **항상 exit code 0**으로 종료된다.

이 때문에 `test_accuracy/test.sh`의 다음 가드는 실제로는 절대
발동하지 않는다:

```bash
if ! python3 -u $SCRIPTSDIR/common/weblate_utils.py check-sentence-count \
    ...
then
    echo "[ERROR] Check the sentence failed: ..."
    exit 1
fi
```

`check-sentence-count`가 정합성 불일치를 찾아도 프로세스 자체는
exit 0으로 끝나므로 `if !`가 참이 되는 일이 없고, `test_accuracy()`는
실패를 무시한 채 다음 컴포넌트/로케일로 계속 진행하다 결국 정상
종료한다.

**왜 중요한가**: 이는 Phase 1에서 고친 문제와는 다른 지점의 버그다.
Phase 1은 "`migration_resources.sh`의 실제 종료 코드를
`migration_projects.sh`가 제대로 읽는가"를 고쳤지만, 이 문제는 그보다
안쪽, "`migration_resources.sh` 자신이 정합성 실패를 종료 코드에
반영하는가"의 문제다. 즉 Phase 1이 고쳐졌어도, 모든 로케일의 정합성
체크가 실패한 채로 `migration_resources.sh`가 여전히 `exit 0`으로
끝나 배치 로그에 "Success"로 잘못 기록될 수 있다. Phase 1·2가 만든
"신뢰 가능한 성공/실패 판정"이라는 전제 자체를 무너뜨리는 구멍이므로,
Phase 3(집계)·Phase 4(가독성)보다 먼저 막아야 한다.

## 계획

### Phase 1 — 신뢰 가능한 성공/실패 판정 (선행 조건)

- `migration_projects.sh`에서 파이프라인 대신 `PIPESTATUS[0]`을 사용하거나,
  `MIGRATION_SCRIPT`의 출력을 임시 파일에 먼저 저장한 뒤 종료 코드를
  직접 검사하도록 수정.
- **근거**: 이후 만들 모든 집계/대시보드 기능은 이 판정 값을 기반으로
  하므로, 여기가 틀리면 상위 기능 전체가 의미를 잃는다.

### Phase 2 — 정합성 테스트 결과를 실제 JSON으로 영속화

- `WeblateUtils`가 `result_json_path`를 저장하고, `check_sentence_count`
  / `check_sentence_detail`이 각 project/category(version)/component/
  locale 단위 결과를
  `{total, translated_zanata, translated_weblate, mismatch_count,
  missing_count, extra_count, status}` 형태로 해당 JSON 파일에 append
  하도록 수정.
- **근거**: 이미 존재하는 Zanata PO ↔ Weblate PO 비교 로직(기준점은
  아래 "정합성 기준점" 참고)은 올바르지만, 그 결과가 재사용 가능한
  데이터로 남지 않으면 "현황 파악"이라는 목적을 달성할 수 없다. 죽어있는
  인자를 실제로 연결하는 것이므로 리스크가 낮고 이득이 큰 변경이다.

### Phase 3 — 정합성 체크 실패를 실제 종료 코드로 전파

- `check_sentence_count`/`check_sentence_detail`이 불일치를 발견하면
  `print()` 후 `return None`으로 끝나는 대신, 실패 여부를 반환하도록
  수정(예: `bool` 반환, 또는 실패 시 예외).
- `main()`이 이 반환값을 보고 실패 시 `sys.exit(1)`하도록 수정해,
  `check-sentence-count`/`check-sentence-detail` CLI 호출이 실제로
  0이 아닌 종료 코드를 낼 수 있게 한다.
- `test_accuracy/test.sh`의 기존 `if ! python3 ... check-sentence-count
  ...; then exit 1; fi` 가드가 실제로 발동하는지 재검증.
- **근거**: 문제 진단 4번. Phase 1이 고친 `migration_projects.sh`의
  판정 문제와는 다른 지점(그보다 안쪽, `migration_resources.sh` 자신이
  실패를 종료 코드에 반영하는지)이라 별도로 고쳐야 한다. 이게 고쳐지지
  않으면 Phase 1·2로 마련한 "신뢰 가능한 성공/실패 판정"이 정합성
  체크 실패 앞에서는 여전히 무의미하므로, 집계·가독성 개선보다 먼저
  처리한다.

### Phase 4 — 배치 결과 집계 리포트

- 여러 project/version 실행에서 생성된 `result.json`들과 (수정된)
  성공/실패 판정을 모아, project × version × component × locale
  단위 상태 표(혹은 CSV)를 출력하는 집계 스크립트 추가.
- 실패 원인을 단계별로 구분해서 보여줄 것: clone 실패 / POT 생성 실패 /
  Weblate 컴포넌트 생성 실패 / 정합성 불일치.
- **근거**: Phase 1·2·3로 신뢰 가능한 원본 데이터가 만들어진 뒤에야
  집계가 의미를 가지므로 그 다음 단계로 둔다. 실패 단계 구분은 "정합성
  문제"와 "인프라/API 문제"를 구분해 조치 우선순위를 정할 수 있게 한다.

### Phase 5 — 실행 과정 가독성 개선

마이그레이션 결과는 결국 사람이 눈으로 검증해야 하므로, 실행 중/종료 후
모두 "지금 무슨 일이 벌어지고 있는지"를 최소한의 노력으로 파악할 수
있어야 한다. Phase 1~4로 데이터(정확한 성공/실패 판정, 구조화된
result.json, 종료 코드 전파, 집계 스크립트)가 준비된 뒤, 그 위에 아래
4가지 표현 개선을 적용한다.

1. **일관된 스테이지 구분**
   이미 존재하는 `migration/pretty-printer.sh`의 `stage()`/`endstage()`를
   `migration_resources.sh`의 각 단계(환경설정 → clone → POT 생성 →
   Zanata export → Weblate 컴포넌트 생성 → 정합성 테스트) 진입/종료
   지점마다 일관되게 호출하도록 수정.
   **근거**: 지금은 각 단계가 `echo "[INFO] ..."` 한 줄로만 표시되고
   구분자가 없어, 로그를 보는 사람이 "지금 몇 번째 단계인지"를 앞뒤
   맥락으로 유추해야 한다. `stage()`/`endstage()`는 이미 저장소에
   구현돼 있는데도 `migration_resources.sh`/`migration_projects.sh`
   경로에서는 쓰이지 않고 있어, 새로 만들 필요 없이 배선만 하면 된다.

2. **배치 실행 중 진행률(퍼센트/예상 남은 시간) 표시**
   `migration_projects.sh`의 기존 `[$total_count] 처리 중` 로그에
   전체 대비 진행률(`%`)과, 지금까지의 평균 처리 시간 기반 예상
   남은 시간을 추가.
   **근거**: 현재는 몇 번째 항목을 처리 중인지만 알 수 있고 전체
   대비 어느 정도 왔는지, 언제 끝날지는 알 수 없다. 프로젝트 수십~
   수백 개, 항목당 15초 sleep까지 포함된 배치 작업이므로 예상 소요
   시간을 아는 것이 운영에 실질적으로 도움된다. 단, 캐리지리턴
   기반 애니메이션 바는 로그 파일 포맷을 깨뜨리므로 채택하지 않고
   (앞선 논의 참고) 한 줄짜리 텍스트 로그로 남긴다.

3. **TTY 감지 색상 출력**
   `[ -t 1 ]`로 표준출력이 터미널인지 확인해, 터미널일 때만
   성공(초록)/실패(빨강)/경고(노랑) 색을 입히고, 로그 파일에 `tee`로
   남길 때는 이스케이프 코드 없는 순수 텍스트를 쓰도록 분리.
   색상 코드는 `migration/save_lang.sh`에 이미 정의된
   `RED`/`GREEN`/`YELLOW`/`NC`를 재사용.
   **근거**: 색을 무조건 넣으면 로그 파일에 `\033[...]` 이스케이프
   문자가 그대로 남아 `error.*.log`를 grep하거나 다른 도구로 파싱할
   때 노이즈가 된다. TTY 여부로 분기하면 터미널에서 보는 사람은
   성공/실패를 색으로 즉시 구분하면서도, 로그 파일은 README에 정의된
   `version | message` 포맷을 그대로 유지할 수 있다.

4. **배치 종료 후 사람이 읽는 요약 (콘솔 표 + report.md)**
   Phase 4에서 만든 집계 스크립트의 출력을, 배치 종료 시점에
   (a) 콘솔에 project × version × component × locale 상태 표로
   출력하고, (b) 동일한 내용을 `report.md`로도 저장.
   **근거**: 지금은 결과를 확인하려면 `logs/<project>/` 아래 모든
   `error.*.log` 파일을 사람이 직접 열어봐야 한다. 콘솔 요약은
   실행 직후 바로 확인할 수 있게 해주고, `report.md`는 그 결과를
   남겨서 나중에(혹은 다른 사람과) 다시 확인·공유할 수 있게 해준다.
   두 출력 모두 Phase 2의 result.json을 원본으로 삼으므로 서로
   불일치할 일이 없다.

### (선택) Phase 6 — 재개(resume) 지원

- 이미 성공으로 확정된 project × version은 재실행 시 스킵할 수 있도록
  체크포인트 파일 도입.
- **근거**: 배치 스크립트에 project당 15초 sleep이 걸려 있어, 대량
  재실행 비용이 크다. Phase 1의 정확한 성공 판정이 선행되어야 안전하게
  스킵할 수 있다.

## 정합성(정확성) 판단 기준점

마이그레이션이 "정확하다"고 판단하는 기준점은 **Zanata에서 export한
PO 파일을 원본 진실(source of truth)로 삼고, Weblate에서 다시
다운로드한 PO 파일이 이와 일치하는지 비교**하는 것이다. 이는 이미
`test_accuracy/test.sh` + `weblate_utils.py`의
`check_sentence_count`/`check_sentence_detail`에 구현되어 있으며
방향 자체는 맞다:

- obsolete 항목을 제외한 전체 문장 수 / 번역 완료 문장 수 일치
- msgid 기준으로 1:1 매핑하여 msgstr 완전 일치
- Weblate에 없는 항목(missing), Zanata에 없는데 Weblate에만 있는
  항목(extra) 검출

**보완이 필요한 부분**과 그 근거:

1. **비교 키를 `msgid` 단독이 아니라 `(msgid, msgctxt)` 조합으로.**
   같은 msgid가 다른 context에서 반복되는 경우(예: plural 관련 문자열)
   현재 로직은 이를 구분하지 못해 잘못된 매칭이 발생할 수 있다.
2. **컴포넌트/로케일 자체의 존재 여부를 별도로 검증.** 현재 루프는
   Zanata 쪽에 존재하는 로케일 목록을 기준으로 순회하므로, Weblate에
   컴포넌트나 특정 로케일이 통째로 생성되지 않은 경우 "이 로케일이
   아예 없음"이라는 사실이 명시적으로 기록되지 않고 다운로드/경로
   조회 단계에서 스크립트가 죽는 방식으로만 드러난다.
3. **plural form 인덱스별 비교 포함.** 저장소에 이미
   `zanata_plural_rules.py`/`weblate_plural_rules.py`가 존재하는
   것으로 보아 두 플랫폼의 plural 규칙 차이가 실제 이슈였던 것으로
   보인다. 단순 msgstr 문자열 비교만으로는 plural index가 어긋나도
   놓칠 수 있다.

이 기준점(Zanata PO = 원본, Weblate PO = 검증 대상)은 바꿀 필요가
없고, 위 세 가지 보완을 통해 오탐/누락을 줄이는 방향으로 강화하면
된다.
