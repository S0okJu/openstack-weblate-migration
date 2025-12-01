#!/bin/bash

# 스크립트 사용법 체크
if [ $# -eq 0 ]; then
    echo "사용법: $0 <list_file> [version_file]"
    echo "예시: $0 list.txt"
    echo "예시: $0 list.txt version.txt"
    exit 1
fi

LIST_FILE="$1"
VERSION_FILE="${2:-version.txt}"

# 파일 존재 여부 확인
if [ ! -f "$LIST_FILE" ]; then
    echo "오류: 파일 '$LIST_FILE'이 존재하지 않습니다."
    exit 1
fi

if [ ! -f "$VERSION_FILE" ]; then
    echo "오류: 파일 '$VERSION_FILE'이 존재하지 않습니다."
    exit 1
fi

# migration.sh 경로 설정 (틸드 확장)
MIGRATION_SCRIPT="$(dirname "$0")/migration/migration.sh"

# migration.sh 존재 여부 확인
if [ ! -f "$MIGRATION_SCRIPT" ]; then
    echo "오류: migration.sh 파일이 '$MIGRATION_SCRIPT'에 존재하지 않습니다."
    exit 1
fi

# migration.sh 실행 권한 확인
if [ ! -x "$MIGRATION_SCRIPT" ]; then
    echo "경고: migration.sh에 실행 권한이 없습니다. 실행 권한을 부여합니다."
    chmod +x "$MIGRATION_SCRIPT"
fi

# logs 디렉토리 생성
mkdir -p logs

echo "=== Migration 시작 ==="
echo "프로젝트 파일: $LIST_FILE"
echo "버전 파일: $VERSION_FILE"
echo "====================="

total_count=0

while IFS= read -r project || [ -n "$project" ]; do   
    is_setup="true"
    echo "=== 프로젝트: $project ==="
    if [[ -z "${project// }" ]]; then
        continue
    fi
    
    mkdir -p logs/$project
    project=$(echo "$project" | xargs)
    
    echo ""
    echo "=== 프로젝트: $project ==="
    
    # 버전별로 반복
    while IFS= read -r version || [ -n "$version" ]; do
        # 빈 줄이나 공백만 있는 줄 건너뛰기
        if [[ -z "${version// }" ]]; then
            continue
        fi
        
        # 앞뒤 공백 제거
        version=$(echo "$version" | xargs)
        
        # 버전 앞에 #가 있으면 IS_LOCKED=true, 없으면 IS_LOCKED=false
        if [[ "$version" == \#* ]]; then
            IS_LOCKED="true"
            version="${version#\#}"  # 맨 앞의 # 제거
        else
            IS_LOCKED="false"
        fi
        
        ((total_count++))
        echo "[$total_count] 처리 중: '$project' (버전: $version) [LOCKED: $IS_LOCKED]"
        
        # 로그 파일 경로 설정 (버전별로 구분)
        LOG_FILE="logs/$project/migration.log"
        ERROR_LOG="logs/$project/error.log"
        
        # migration.sh 실행하면서 로그 파일에 저장
        
        if "$MIGRATION_SCRIPT" "$project" "$version" "$is_setup" "$IS_LOCKED" 2>&1 | while IFS= read -r line; do
            # migration.log에 버전 포함하여 저장
            echo "$version | $line" | tee -a "$LOG_FILE"
            # ERROR 라인이면 error.log에도 저장
            if [[ "$line" == \[ERROR\]* ]]; then
                echo "$version | $line" >> "$ERROR_LOG"
            fi
        done; then
            echo "[$total_count] 성공: '$project' (버전: $version)"
        else
            echo "[$total_count] 실패: '$project' (버전: $version) (종료 코드: $?)"
        fi

        is_setup="false"

        sleep 15
        
        echo "---"
    done < "$VERSION_FILE"
    
done < "$LIST_FILE"

echo "====================="
echo "=== Migration 완료 ==="
