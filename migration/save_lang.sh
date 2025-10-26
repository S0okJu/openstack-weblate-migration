#!/bin/bash

# Zanata와 Weblate 언어셋을 각각 JSON 파일로 저장하는 스크립트
# 사용법: ./save_languages.sh <zanata_url> <weblate_url> <weblate_token>

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로깅 함수
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# # 인수 확인
# if [ $# -ne 3 ]; then
#     echo "사용법: $0 <zanata_url> <weblate_url> <weblate_token>"
#     echo "예시: $0 https://translate.openstack.org https://weblate.example.com wlu_token123"
#     exit 1
# fi

# ZANATA_URL="$1"
WEBLATE_URL="$1"
WEBLATE_TOKEN="$2"

# log_info "Zanata URL: $ZANATA_URL"
log_info "Weblate URL: $WEBLATE_URL"

# 출력 파일들
ZANATA_OUTPUT="zanata_languages.json"
WEBLATE_OUTPUT="weblate_languages.json"

# Zanata에서 언어 정보 가져오기
get_zanata_languages() {
    log_info "Zanata에서 언어 정보를 가져오는 중..."
    
    # Zanata API에서 언어 목록 가져오기
    # /rest/locales/ui: 서버의 지역화된 locale 전체 목록
    log_info "Zanata 전체 지원 언어를 가져오는 중... (/rest/locales/ui)"
    response=$(curl -s -w "%{http_code}" -o /tmp/zanata_raw.json \
        "$ZANATA_URL/rest/locales/ui")
    
    http_code="${response: -3}"
    
    if [[ "$http_code" == 2* ]]; then
        # JSON을 예쁘게 포맷팅해서 저장
        if command -v jq &> /dev/null; then
            jq '.' /tmp/zanata_raw.json > "$ZANATA_OUTPUT"
            # /rest/locales/ui는 배열 형태이므로 .length 사용
            count=$(jq '. | length' "$ZANATA_OUTPUT" 2>/dev/null || echo "0")
            log_info "총 $count개 언어를 찾았습니다."
        else
            # jq가 없으면 원본 그대로 저장
            mv /tmp/zanata_raw.json "$ZANATA_OUTPUT"
            log_warning "jq가 설치되지 않아 원본 형식으로 저장됩니다."
        fi
        
        log_success "Zanata 언어 정보를 $ZANATA_OUTPUT에 저장했습니다."
    else
        log_error "Zanata 언어 정보를 가져올 수 없습니다. HTTP $http_code"
        exit 1
    fi
}

# Weblate에서 언어 정보 가져오기
get_weblate_languages() {
    log_info "Weblate에서 언어 정보를 가져오는 중..."
    
    # 임시 파일 초기화
    rm -f /tmp/weblate_all.json
    echo '{"results": []}' > /tmp/weblate_all.json
    
    page=1
    total_count=0
    
    while true; do
        log_info "페이지 $page에서 언어 정보를 가져오는 중..."
        
        # Weblate API에서 페이지별로 언어 가져오기
        response=$(curl -s -w "%{http_code}" -o /tmp/weblate_page.json \
            -H "Authorization: Token $WEBLATE_TOKEN" \
            "$WEBLATE_URL/api/languages/?page=$page")
        
        http_code="${response: -3}"
        
        if [[ "$http_code" == 2* ]]; then
            # 현재 페이지의 결과 수 확인
            if command -v jq &> /dev/null; then
                page_count=$(jq '.results | length' /tmp/weblate_page.json 2>/dev/null || echo "0")
                next_url=$(jq -r '.next // empty' /tmp/weblate_page.json 2>/dev/null || echo "")
                
                if [ "$page_count" -gt 0 ]; then
                    # 현재 페이지 결과를 전체 결과에 추가
                    jq -s '.[0].results += .[1].results | .[0]' /tmp/weblate_all.json /tmp/weblate_page.json > /tmp/weblate_temp.json
                    mv /tmp/weblate_temp.json /tmp/weblate_all.json
                    
                    total_count=$((total_count + page_count))
                    log_info "페이지 $page: $page_count개 언어 추가 (총 $total_count개)"
                    
                    # 다음 페이지가 없으면 종료
                    if [ -z "$next_url" ] || [ "$next_url" = "null" ]; then
                        log_info "모든 페이지를 가져왔습니다."
                        break
                    fi
                    
                    page=$((page + 1))
                    sleep 1  # API 호출 간격 조절
                else
                    log_info "페이지 $page에 더 이상 언어가 없습니다."
                    break
                fi
            else
                log_error "jq가 필요합니다. jq를 설치해주세요."
                exit 1
            fi
        else
            log_error "Weblate 언어 정보를 가져올 수 없습니다. HTTP $http_code"
            exit 1
        fi
    done
    
    # 최종 결과 저장
    if command -v jq &> /dev/null; then
        jq '.' /tmp/weblate_all.json > "$WEBLATE_OUTPUT"
        final_count=$(jq '.results | length' "$WEBLATE_OUTPUT" 2>/dev/null || echo "0")
        log_success "총 $final_count개 언어를 가져왔습니다."
    else
        mv /tmp/weblate_all.json "$WEBLATE_OUTPUT"
        log_warning "jq가 설치되지 않아 원본 형식으로 저장됩니다."
    fi
    
    log_success "Weblate 언어 정보를 $WEBLATE_OUTPUT에 저장했습니다."
}

# 메인 실행
main() {
    log_info "언어셋 저장 시작"
    echo
    
    # get_zanata_languages
    get_weblate_languages
    
    # echo
    # log_success "완료! 다음 파일들이 생성되었습니다:"
    # log_info "  - $ZANATA_OUTPUT (Zanata 언어셋)"
    # log_info "  - $WEBLATE_OUTPUT (Weblate 언어셋)"
    
    # # 파일 크기 표시
    # if [ -f "$ZANATA_OUTPUT" ]; then
    #     size=$(du -h "$ZANATA_OUTPUT" | cut -f1)
    #     log_info "  - $ZANATA_OUTPUT 크기: $size"
        
    #     # JSON 형식 확인
    #     if command -v jq &> /dev/null; then
    #         if jq -e . "$ZANATA_OUTPUT" >/dev/null 2>&1; then
    #             log_success "  ✅ $ZANATA_OUTPUT: 유효한 JSON 형식"
    #         else
    #             log_warning "  ⚠️  $ZANATA_OUTPUT: JSON 형식 오류"
    #         fi
    #     fi
    # fi
    
    if [ -f "$WEBLATE_OUTPUT" ]; then
        size=$(du -h "$WEBLATE_OUTPUT" | cut -f1)
        log_info "  - $WEBLATE_OUTPUT 크기: $size"
        
        # JSON 형식 확인
        if command -v jq &> /dev/null; then
            if jq -e . "$WEBLATE_OUTPUT" >/dev/null 2>&1; then
                log_success "  ✅ $WEBLATE_OUTPUT: 유효한 JSON 형식"
            else
                log_warning "  ⚠️  $WEBLATE_OUTPUT: JSON 형식 오류"
            fi
        fi
    fi
}

# 스크립트 실행
main "$@"