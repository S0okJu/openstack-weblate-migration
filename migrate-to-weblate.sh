#!/bin/bash

# ========================== Color definitions ==========================
# Color definitions for log messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
WHITE='\033[1;37m'
GRAY='\033[1;30m'
NC='\033[0m' # No Color

log_info() {
    echo -e "[INFO]: $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]: $1${NC}"
}

log_skip() {
    echo -e "${GRAY}[SKIP]: $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]: $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR]: $1${NC}"
}


# ========================== Push translation to weblate =================

# Parameters
project_name=$1

# TODO: Replace with actual values
WEBLATE_URL="<weblate_url>"
WEBLATE_TOKEN="<weblate_token>"

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
POT_PROJECT_PATH="$SCRIPTS_DIR/work/pot-works/$project_name"
TRANSLATION_DIR="$SCRIPTS_DIR/work/translations"

function error_handling {
    local http_code=$1
    local response_body=$2

    case $http_code in
        4*)
            log_error "Client error occurred: $http_code"
            echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body"
            ;;
        5*)
            log_error "Server error occurred: $http_code"
            echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body"
            ;;
    esac
}

# Create or get project in weblate
# !NOTICE: We did not consider when it has / characters
log_info "Check the project $project_name in weblate..."
log_info "Starting curl request to $WEBLATE_URL/api/projects/$project_name/"
response=$(curl -s --max-time 10 -w "%{http_code}" -H "Authorization: Token $WEBLATE_TOKEN" \
        "$WEBLATE_URL/api/projects/$project_name/")
log_info "curl request completed"

http_code="${response: -3}"
case $http_code in
    200)
        log_skip "Project $project_name already exists in weblate"
        ;;
    404)
        log_info "Create project $project_name in weblate..."
        # 임시 파일로 응답 body와 상태 코드 분리
        response=$(curl -s -w "%{http_code}" -o /tmp/response_body \
            -X POST \
            -H "Authorization: Token $WEBLATE_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"name\": \"$project_name\", \"slug\": \"$project_name\", \"web\": \"https://opendev.org/openstack/$project_name\"}" \
            "$WEBLATE_URL/api/projects/")
        
        http_code="${response: -3}"
        response_body=$(cat /tmp/response_body)
        
        case $http_code in
            2*)
                log_success "Created project $project_name in weblate"
                ;;
            *)
                log_error "HTTP $http_code: $(echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body")"
                exit 1
                ;;
        esac
        ;;  
    *)
        error_handling $http_code "$response_body"
        exit 1
        ;;
esac

# Add component in weblate

function create_or_get_component {
    local component=$1
    local pot_file="${POT_PROJECT_PATH}/locale/${component}.pot"

    log_info "Check the component $component exists in weblate..."
    # 임시 파일로 응답 body와 상태 코드 분리
    response=$(curl -s -w "%{http_code}" -o /tmp/response_body \
        -H "Authorization: Token $WEBLATE_TOKEN" \
        "$WEBLATE_URL/api/projects/$project_name/components/$component/")
    
    http_code="${response: -3}"
    response_body=$(cat /tmp/response_body)
    
    log_info "Component $component check in create_or_get_component - HTTP: $http_code"
    
    case $http_code in
        200)
            log_skip "Component $component already exists in weblate"
            ;;
        404)
            if [ ! -f "$pot_file" ]; then
                log_error "POT file $pot_file does not exist"
                break  # case 문에서 빠져나감
            fi
            log_info "Creating component $component in weblate..."
            response=$(curl -s -w "%{http_code}" -o /tmp/response_body \
                -X POST \
                -H "Authorization: Token $WEBLATE_TOKEN" \
                -F "docfile=@$pot_file" \
                -F "name=$component" \
                -F "slug=$component" \
                -F "file_format=po-mono" \
                -F "source_language=en" \
                $WEBLATE_URL/api/projects/$project_name/components/)

            http_code="${response: -3}"
            response_body=$(cat /tmp/response_body)
            
            log_info "Component creation response - HTTP: $http_code"
    
            case $http_code in
                2*)
                    log_success "Created component $component in weblate"
                    ;;
                *)
                    error_handling $http_code "$response_body"
                    ;;
            esac
            
            ;;
        *)
            error_handling $http_code "$response_body"
            ;;
    esac

}

component_list=("django" "djangojs" "releasenotes" "${project_name}")

# check pot file exists in the project
for component in ${component_list[@]}; do
    if [ -f "${POT_PROJECT_PATH}/locale/${component}.pot" ]; then
        log_info "Check the component $component in weblate..."

        response=$(curl -s -w "%{http_code}" -o /tmp/response_body \
            -H "Authorization: Token $WEBLATE_TOKEN" \
            "$WEBLATE_URL/api/components/$project_name/$component/")
        
        http_code="${response: -3}"
        response_body=$(cat /tmp/response_body)
        
        case $http_code in
            200)
                log_skip "Component $component already exists in weblate"
                ;;
            404)
                create_or_get_component $component
                ;;
            *)
                error_handling $http_code $response_body
                ;;
        esac
    fi
done

# # Add translation in weblate 

log_info "Add translation in weblate..."

# get list of locales
# Convert project name from kebab-case to snake_case
function create_translation {
    local component=$1
    local weblate_locale=$2

    log_info "Check the translation $weblate_locale in weblate..."
    # 임시 파일로 응답 body와 상태 코드 분리
    response=$(curl -s -w "%{http_code}" -o /tmp/response_body \
        -H "Authorization: Token $WEBLATE_TOKEN" \
        "$WEBLATE_URL/api/translations/$project_name/$component/$weblate_locale/")

    http_code="${response: -3}"
    response_body=$(cat /tmp/response_body)
    
    case $http_code in
        200)
            log_skip "Translation $weblate_locale already exists in weblate"
            ;;
        404)
            log_info "Create translation $weblate_locale in weblate..."
            # 임시 파일로 응답 body와 상태 코드 분리
            response=$(curl -s -w "%{http_code}" -o /tmp/response_body \
                -X POST \
                -H "Authorization: Token $WEBLATE_TOKEN" \
                -H "Content-Type: application/json" \
                -d "{\"language_code\": \"$weblate_locale\"}" \
                "$WEBLATE_URL/api/components/$project_name/$component/translations/")
            
            http_code="${response: -3}"
            response_body=$(cat /tmp/response_body)
            
            case $http_code in
                2*)
                    log_success "Created translation $weblate_locale in weblate"
                    ;;
                *)
                    error_handling $http_code "$response_body"
                    ;;
            esac
            ;;
        *)
            error_handling $http_code "$response_body"
            ;;
    esac

    log_success "Created translation $weblate_locale in weblate"
}

function push_po_file {
    local weblate_locale=$1
    local po_file=$2
    local component=$3

    log_info "Changing plural forms in $weblate_locale po file..."
    $SCRIPTS_DIR/.venv/bin/python3 $SCRIPTS_DIR/python/plural.py $weblate_locale $po_file
    log_success "Changed plural forms in $weblate_locale po file"

    log_info "Push $weblate_locale po file in $component..."
    response=$(curl -s -w "%{http_code}" -o /tmp/response_body -X POST \
        -H "Authorization: Token $WEBLATE_TOKEN" \
        -F "file=@$po_file" \
        "$WEBLATE_URL/api/translations/$project_name/$component/$weblate_locale/file/")

    # 임시 파일로 응답 body와 상태 코드 분리
    http_code="${response: -3}"
    response_body=$(cat /tmp/response_body)
    
    echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body"
    
    
    case $http_code in
        2*)
            log_success "Pushed $weblate_locale po file in $component"
            ;;
        *)
            error_handling $http_code "$response_body"
            exit 1
            ;;
    esac
}



project_package_name=${project_name//-/_}

locale_list=($(ls -d ${TRANSLATION_DIR}/${project_package_name}/locale/*/ 2>/dev/null || echo ""))
log_info "Found ${#locale_list[@]} locales"

for component in ${component_list[@]}; do
    log_info "Processing component: $component"
    for locale in ${locale_list[@]}; do

        log_info "Push $locale po file in $component..."
        locale_name=$(basename "$locale" | tr '_' '-')

        log_info "Change language code in $weblate_locale po file..."
        weblate_locale=$($SCRIPTS_DIR/.venv/bin/python3 $SCRIPTS_DIR/python/language_mapping.py $locale_name)
        $SCRIPTS_DIR/.venv/bin/python3 $SCRIPTS_DIR/python/language.py $weblate_locale $po_file
        log_success "Changed language code in $weblate_locale -> $po_file"

        locale_folder_name=$(basename "$locale")
        case $component in        
            "django"|"djangojs")
                po_file="${TRANSLATION_DIR}/${project_package_name}/locale/${locale_folder_name}/LC_MESSAGES/${component}.po"
                ;;
            "${project_name}")
                # Convert hyphen to underscore (for file name)
                file_name=$(echo $component | tr '-' '_')
                po_file="${TRANSLATION_DIR}/${project_package_name}/locale/${locale_folder_name}/LC_MESSAGES/${file_name}.po"
                ;;
            "releasenotes")
                po_file="${TRANSLATION_DIR}/releasenotes/source/locale/${locale_folder_name}/LC_MESSAGES/releasenotes.po"
                ;;
        esac

        log_info "PO file path: $po_file"
        log_info "PO file exists: $([ -f "$po_file" ] && echo "YES" || echo "NO")"
        echo ""
        
        if [ -f "$po_file" ]; then
            create_translation $component $weblate_locale
            push_po_file $weblate_locale $po_file $component

            sleep 5
        fi
        
    done
done
