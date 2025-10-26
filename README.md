### 실행 환경
- 현재는 리눅스 환경에만 지원 가능합니다. 

### 사전 준비
- python3.x
- `zanata-cli` 도구가 있는지 확인 부탁드립니다.
- `~/.config/zanata.ini` 에 zanata 환경 설정 파일이 있는지 확인 부탁드립니다. 

### 실행 방법
- Weblate credential를 환경변수에 등록합니다. 
```bash
export WEBLATE_URL="https://"
export WEBLATE_TOKEN="wlc_***"

```

프로젝트 목록과 브랜치 목록을 등록하여 마이그레이션을 수행합니다. 
- list.txt: 프로젝트 목록
- version.txt: 브랜치 목록 
```bash
./run.sh list.txt version.txt
```

마이그레이션과 관련된 모든 파일은 `$HOME/workspace` 경로에 저장되어 있습니다. 

### 로깅 
- logs 폴더 내 <프로젝트 이름>_<브랜치명>.log 파일에 로그를 기록했습니다. 
- 번역 파일 업로드의 경우에는 문제가 발생하더라도 마이그레이션이 중단되지 않습니다. 
- 오류 메세지는 `[ERROR]` 로 시작됩니다.

### 정확성 검증
- 번역 파일 업로드 이후에 전체 문장/번역된 문장 기반으로 정확성이 검증됩니다.

### 이슈
문제 발생 시 github issue에 등록해주시면 바로 수정하겠습니다.
