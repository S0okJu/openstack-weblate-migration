#!/bin/bash

# ========================== Parameters ==========================
DOC_TARGETS=(
    'contributor-guide',
    'horizon',
    'openstack-ansible',
    'operations-guide',
    'swift'
)

# We need a UTF-8 locale, set it properly in case it's not set.
export LANG=en_US.UTF-8

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Source common functions
source $SCRIPTS_DIR/workspace/dependencies/openstack-zuul-jobs/roles/prepare-zanata-client/files/common_translation_update.sh

VENV_PYTHON="$SCRIPTS_DIR/.venv/bin/python3"
VENV_PIP="$SCRIPTS_DIR/.venv/bin/pip3"

# TODO: Replace with actual values
WEBLATE_URL="<weblate_url>"
WEBLATE_TOKEN="<weblate_token>"

if [ -z "$WEBLATE_URL" ] || [ "$WEBLATE_URL" == "<weblate_url>" ]; then
    echo "WEBLATE_URL is not set"
    exit 1
fi
if [ -z "$WEBLATE_TOKEN" ] || [ "$WEBLATE_TOKEN" == "<weblate_token>" ]; then
    echo "WEBLATE_TOKEN is not set"
    exit 1
fi

# ========================== Color definitions ==========================
# Color definitions for log messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
GRAY='\033[1;30m'
BLUE='\033[1;34m'
NC='\033[0m' # No Color

show_stage() {
    local stage_num=$1
    local stage_name=$2
    
    echo ""
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE} Stage ${stage_num}: ${stage_name}${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo ""
}

# Step 표시 함수
show_step() {
    local step_name=$1
    echo -e "  → ${step_name}${NC}"
}

change_step_message() {
    local new_message=$1
    echo -e "  → ${new_message}${NC}"
}

fail_step_message() {
    local failed_message=$1
    echo -e "  ${RED}x ${failed_message}${NC}"
}

skip_step_message() {
    local skipped_message=$1
    echo -e "  ${GRAY}! ${skipped_message}${NC}"
}

complete_step_message() {
    local completed_message=$1
    echo -e "  ${GREEN}✓ ${completed_message}${NC}"
}

# ========================== Parameters ==========================
show_stage 1 "Checking parameters"

show_step "Checking project name..."
project_name=$1
if [ -z "$project_name" ]; then
    fail_step_message "Project name is required"
    exit 1
fi
complete_step_message "Project name is $project_name"

# ========================== Prepare installation ==========================
# Install gettext
# We use jq to parse JSON response

show_stage 2 "Installing dependencies in system"

show_step "Installing gettext and jq..."
ERROR_OUTPUT=$(sudo apt install -y gettext jq 2>&1)
INSTALL_EXIT_CODE=$?

if [ $INSTALL_EXIT_CODE -eq 0 ]; then
    complete_step_message "Installed gettext and jq"
else
    fail_step_message "Failed to install gettext and jq"
    echo $ERROR_OUTPUT
    exit 1
fi

# ========================== Create python virtual environment ==========================
show_stage 3 "Creating python virtual environment"

# Check Python3 installation
show_step "Check Python3 installation..."
if ! command -v python3 &> /dev/null; then
    fail_step_message "Python3 is not installed"
    exit 1
else
    skip_step_message "Python3 is already installed"
fi

# Check Python version 
# NOTE: We only test 3.10 version. 
show_step "Check Python3 version..."
PYTHON_VERSION=$(python --version 2>&1 | cut -d' ' -f2)
PYTHON_MAJOR_MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f1-2)

if [[ $PYTHON_MAJOR_MINOR != "3.10" ]]; then
    fail_step_message "Python3 version is not 3.10 (current: $PYTHON_VERSION)"
    exit 1
else
    complete_step_message "Python3 version is 3.10 ($PYTHON_VERSION)"
fi

# Create virtual environment
show_step "Setting up virtual environment..."
if [ ! -d "$SCRIPTS_DIR/.venv" ]; then
    python3 -m venv $SCRIPTS_DIR/.venv >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        complete_step_message "Virtual environment created"
    else
        fail_step_message "Failed to create virtual environment"
        exit 1
    fi
else
    skip_step_message "Virtual environment already exists"
fi

# Activate virtual environment
show_step "Activate virtual environment..."
source $SCRIPTS_DIR/.venv/bin/activate
complete_step_message "Activated virtual environment"

# ========================== Setup Directory ==========================
# Setup the directory first.
# Because we need to install dependencies in the dependencies directory.
# 
# Folder structure
# - workspace
#   - dependencies: dependencies directory (e.g. requirements, openstack-zuul-jobs)
#   - projects: project directory that contains pot, po files
# - .venv: virtual environment
# 
show_stage 4 "Setting up workspace directory"

show_step "Setting up workspace directory..."
WORK_DIR=$SCRIPTS_DIR/workspace
if [ ! -d "$WORK_DIR" ]; then
    mkdir -p $WORK_DIR
    complete_step_message "Created workspace directory"
else
    skip_step_message "Workspace directory already exists"
fi


# Make pot-generation directory to work 
show_step "Setting up projects directory..."
PROJECTS_DIR=$WORK_DIR/projects
if [ ! -d "$PROJECTS_DIR" ]; then
    mkdir -p $PROJECTS_DIR
    complete_step_message "Created projects directory"
else
    skip_step_message "Projects directory already exists"
fi

show_step "Setting up dependencies directory..."
DEPENDENCIES_DIR=$WORK_DIR/dependencies
if [ ! -d "$DEPENDENCIES_DIR" ]; then
    mkdir -p $DEPENDENCIES_DIR
    complete_step_message "Created dependencies directory"
else
    skip_step_message "Dependencies directory already exists"
fi

# ========================== Install dependencies ==========================
show_stage 5 "Installing dependencies"
# Install dependencies
show_step "Installing dependencies for custom python scripts"
$VENV_PIP install -r $SCRIPTS_DIR/requirements.txt
if [ $? -eq 0 ]; then
    complete_step_message "Installed dependencies in virtual environment"
else
    fail_step_message "Failed to install dependencies in virtual environment"
    exit 1
fi

show_step "Installing dependencies for migrations"
if [ ! -d "$DEPENDENCIES_DIR/requirements" ]; then
    cd $DEPENDENCIES_DIR
    git clone https://opendev.org/openstack/requirements
    
    cd requirements
    $VENV_PIP install bindep
    
    # We need to install system dependencies with bindep
    bindep_packages=$($SCRIPTS_DIR/.venv/bin/bindep -b 2>/dev/null)
    if [ -n "$bindep_packages" ]; then
        sudo apt install -y $bindep_packages

        if [ $? -ne 0 ]; then
            fail_step_message "Failed to install system dependencies with bindep"
            exit 1

        fi
    fi

    $VENV_PIP install -r upper-constraints.txt
    if [ $? -ne 0 ]; then
        fail_step_message "Failed to install upper-constraints"
        exit 1
    fi

    complete_step_message "Installed requirements for migration"
else
    skip_step_message "Requirements directory already exists"
fi 

show_step "Install openstack-zuul-jobs..."
if [ ! -d "$DEPENDENCIES_DIR/openstack-zuul-jobs" ]; then
    cd $DEPENDENCIES_DIR
    git clone https://opendev.org/openstack/openstack-zuul-jobs
    complete_step_message "Installed openstack-zuul-jobs"
else
    skip_step_message "openstack-zuul-jobs already exists"
fi

# ========================== Setup zanata-cli ==========================
show_stage 6 "Setup zanata-cli"

show_step "Check zanata-cli installation..."
if ! zanata-cli --version; then
    fail_step_message "zanata-cli is not installed"
    exit 1
else
    skip_step_message "zanata-cli already exists"
fi

# Check zanata.ini file exists 
show_step "Check zanata.ini file exists..."
if [ -f "$HOME/.config/zanata.ini" ]; then
    skip_step_message "zanata.ini already exists"
else
    fail_step_message "zanata.ini is not found"
    exit 1
fi

# =============== Generate POT files ===============
show_stage 7 "Generate POT files"

TARGET_PROJECT_DIR=${PROJECTS_DIR}/${project_name}

# Create project-name directory for multiple projects
show_step "Create project name directory..."
if [ ! -d "$TARGET_PROJECT_DIR" ]; then
    mkdir -p $TARGET_PROJECT_DIR
    complete_step_message "Created project name directory"
else
    skip_step_message "Project name directory already exists"
fi

# Clone project to projects directory

show_step "Cloning project $project_name..."
cd $TARGET_PROJECT_DIR
if [ ! -d "$TARGET_PROJECT_DIR" ] || [ -z "$(ls -A $TARGET_PROJECT_DIR 2>/dev/null)" ]; then
    git clone https://opendev.org/openstack/$project_name
    complete_step_message "Cloned project $project_name"
else
    skip_step_message "Project $project_name already exists"
fi

cd $TARGET_PROJECT_DIR

PREPARE_ZANATA_CLIENT_DIR="${DEPENDENCIES_DIR}/openstack-zuul-jobs/roles/prepare-zanata-client/files"

ZANATA_VERSION="master"
BRANCH="master"

# Use common_translation_update.sh
# There are some function about generating pot files 
source $PREPARE_ZANATA_CLIENT_DIR/common_translation_update.sh

# Source propose-translation.sh for additional functions
source $SCRIPTS_DIR/propose-translation.sh

# COMPONENTS is a list of components to be processed
# It'll be used for Weblate component creation
COMPONENTS=()


# POT files
# There is an issue when zanata-cli pull translation is completed,
# the pot file is deleted. 
# So we store in all of pot files into pot directory to avoid this issue.
# show_step "Create pot directory..."
if [ ! -d "$TARGET_PROJECT_DIR/pot" ]; then
    mkdir -p "$TARGET_PROJECT_DIR/pot"
    complete_step_message "Created pot directory"
else
    skip_step_message "Pot directory already exists"
fi

cd $TARGET_PROJECT_DIR/${project_name}
show_step "Generate POT files..."
case "$project_name" in
    api-site|openstack-manuals|security-doc)
        init_manuals "$project_name"
        # POT file extraction is done in setup_manuals.
        setup_manuals "$project_name" "$ZANATA_VERSION"
        
        case "$project_name" in
            api-site)
                COMPONENTS+=("api-quick-start")
                COMPONENTS+=("firstapp")

                python3 $SCRIPTS_DIR/python/convert_pot.py api-quick-start/locale/api-quick-start.pot
                python3 $SCRIPTS_DIR/python/convert_pot.py firstapp/locale/firstapp.pot

                cp api-quick-start/locale/api-quick-start.pot "$TARGET_PROJECT_DIR/pot/api-quick-start.pot"
                cp firstapp/locale/firstapp.pot "$TARGET_PROJECT_DIR/pot/firstapp.pot"
                ;;
            security-doc)
                COMPONENTS+=("security-guide")
                python3 $SCRIPTS_DIR/python/convert_pot.py security-guide/locale/security-guide.pot
                cp security-guide/locale/security-guide.pot "$TARGET_PROJECT_DIR/pot/security-guide.pot"
                ;;
            *)
                COMPONENTS+=("doc")
                python3 $SCRIPTS_DIR/python/convert_pot.py doc/locale/doc.pot
                cp doc/locale/doc.pot "$TARGET_PROJECT_DIR/pot/doc.pot"
                # python3 $SCRIPTS_DIR/python/convert_pot.py doc/locale/doc-$directory.pot
                ;;
        esac
        if [[ -f releasenotes/source/conf.py ]]; then
            extract_messages_releasenotes 1
            COMPONENTS+=("releasenotes")
            python3 $SCRIPTS_DIR/python/convert_pot.py "releasenotes/source/locale/releasenotes.pot"
            cp releasenotes/source/locale/releasenotes.pot "$TARGET_PROJECT_DIR/pot/releasenotes.pot"

        fi
        ;;
    training-guides)
        setup_training_guides "$ZANATA_VERSION"
        COMPONENTS+=("doc")
        python3 $SCRIPTS_DIR/python/convert_pot.py doc/upstream-training/source/locale/upstream-training.pot
        cp doc/upstream-training/source/locale/upstream-training.pot "$TARGET_PROJECT_DIR/pot/upstream-training.pot"
        ;;
    i18n)
        setup_i18n "$ZANATA_VERSION"
        COMPONENTS+=("doc")
        python3 $SCRIPTS_DIR/python/convert_pot.py doc/locale/doc.pot
        cp doc/locale/doc.pot "$TARGET_PROJECT_DIR/pot/doc.pot"
        # python3 $SCRIPTS_DIR/python/convert_pot.py doc/locale/doc-$directory.pot
        ;;
    tripleo-ui)
        setup_reactjs_project "$project_name" "$ZANATA_VERSION"
        COMPONENTS+=("i18n")
        python3 $SCRIPTS_DIR/python/convert_pot.py i18n/locale/i18n.pot
        cp i18n/locale/i18n.pot "$TARGET_PROJECT_DIR/pot/i18n.pot"
        ;;
    *)
        # Common setup for python and django repositories
        setup_project "$project_name" "$ZANATA_VERSION"
        # ---- Python projects ----
        module_names=$(python3 $PREPARE_ZANATA_CLIENT_DIR/get-modulename.py -p $project_name -t python -f setup.cfg)
        if [ -n "$module_names" ]; then
            if [[ -f releasenotes/source/conf.py ]]; then
                extract_messages_releasenotes 1
                COMPONENTS+=("releasenotes")
                python3 $SCRIPTS_DIR/python/convert_pot.py "releasenotes/source/locale/releasenotes.pot"
                cp releasenotes/source/locale/releasenotes.pot "$TARGET_PROJECT_DIR/pot/releasenotes.pot"
            fi
            for modulename in $module_names; do
                extract_messages_python "$modulename"
                COMPONENTS+=("$modulename")
                python3 $SCRIPTS_DIR/python/convert_pot.py $modulename/locale/$modulename.pot
                cp $modulename/locale/$modulename.pot "$TARGET_PROJECT_DIR/pot/$modulename.pot"
            done
        fi

        # ---- Django projects ----
        module_names=$(get_modulename $project_name django)
        if [ -n "$module_names" ]; then
            install_horizon
            if [[ -f releasenotes/source/conf.py ]]; then
                extract_messages_releasenotes 1
                COMPONENTS+=("releasenotes")
                python3 $SCRIPTS_DIR/python/convert_pot.py "releasenotes/source/locale/releasenotes.pot"
                cp releasenotes/source/locale/releasenotes.pot "$TARGET_PROJECT_DIR/pot/releasenotes.pot"
            
            fi
            for modulename in $module_names; do
                extract_messages_django "$modulename"
                
                # Django projects create django.pot and djangojs.pot
                if [ -f "$modulename/locale/django.pot" ]; then
                    COMPONENTS+=("django")
                    python3 $SCRIPTS_DIR/python/convert_pot.py $modulename/locale/django.pot
                    cp $modulename/locale/django.pot "$TARGET_PROJECT_DIR/pot/django.pot"
                fi
                
                if [ -f "$modulename/locale/djangojs.pot" ]; then
                    COMPONENTS+=("djangojs")
                    python3 $SCRIPTS_DIR/python/convert_pot.py $modulename/locale/djangojs.pot
                    cp $modulename/locale/djangojs.pot "$TARGET_PROJECT_DIR/pot/djangojs.pot"
                fi
            done
        fi
        # ---- Documentation ----
        if [[ -f doc/source/conf.py ]]; then
            # Let's test this with some repos :)
            if [[ ${DOC_TARGETS[*]} =~ "$project_name" ]]; then
                extract_messages_doc
                COMPONENTS+=("doc")
                python3 $SCRIPTS_DIR/python/convert_pot.py doc/source/locale/doc.pot
                cp doc/source/locale/doc.pot "$TARGET_PROJECT_DIR/pot/doc.pot"
                # python3 $SCRIPTS_DIR/python/convert_pot.py doc/source/locale/doc-$directory.pot
            fi
        fi
        ;;
esac

# In bash script, it did not handle duplication.
# So we need to delete duplicated components.
show_step "Delete duplicate components..."
if [ ${#COMPONENTS[@]} -gt 0 ]; then
    # Remove duplicates from COMPONENTS array
    unique_components=()
    for component in "${COMPONENTS[@]}"; do
        if [[ ! " ${unique_components[@]} " =~ " ${component} " ]]; then
            unique_components+=("$component")
        fi
    done
    COMPONENTS=("${unique_components[@]}")
    
    complete_step_message "Unique components: ${COMPONENTS[@]}"
else
    fail_step_message "No components to process"
    exit 1
fi


# # ========================== Pull translations from zanata ===============
show_stage 8 "Pull translations from zanata"

if [ ! -d "$TARGET_PROJECT_DIR/translations" ]; then
    mkdir -p $TARGET_PROJECT_DIR/translations
    complete_step_message "Created translations directory"
else
    skip_step_message "Translations directory already exists"
fi

cp $TARGET_PROJECT_DIR/${project_name}/zanata.xml $TARGET_PROJECT_DIR/translations/zanata.xml

cd $TARGET_PROJECT_DIR/translations

# We did not use pull_from_zanata in common_translation_update.sh
# to pull all translations from zanata.
case "$project_name" in
    api-site|openstack-manuals|security-doc)
        init_manuals "$project_name"
        setup_manuals "$project_name" "$ZANATA_VERSION"

        propose_manuals
        propose_releasenotes "$ZANATA_VERSION"
        ;;
    training-guides)
        setup_training_guides "$ZANATA_VERSION"
        propose_training_guides
        ;;
    i18n)
        setup_i18n "$ZANATA_VERSION"
        propose_i18n
        ;;
    tripleo-ui)
        setup_reactjs_project "$project_name" "$ZANATA_VERSION"
        propose_reactjs
        ;;
    *)
        # Common setup for python and django repositories
        handle_python_django_project $project_name
        ;;
esac

# ========================== Create project and components in Weblate ===============
function error_handling {
    local http_code=$1
    local response_body=$2

    case $http_code in
        4*)
            fail_step_message "Client error occurred: $http_code"
            echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body"
            ;;
        5*)
            fail_step_message "Server error occurred: $http_code"
            echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body"
            ;;
    esac
}

# Sanitize slug for Weblate
# Replace special characters(dot, space, etc.) with hyphens.
function sanitize_slug {
    local name=$1
    echo "$name" | sed 's/[^a-zA-Z0-9_-]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g'
}

show_stage 9 "Create project and components in Weblate"

show_step "Create $project_name project in Weblate..."
response=$(curl -s --max-time 10 -w "%{http_code}" -H "Authorization: Token $WEBLATE_TOKEN" \
        "$WEBLATE_URL/api/projects/$(sanitize_slug $project_name)/")

http_code="${response: -3}"
case $http_code in
    200)
        complete_step_message "Project $project_name created in weblate"
        ;;
    400)
        response_type=$(echo "$response_body" | jq -r '.type')
        if [ "$response_type" == "validation_error" ]; then
            skip_step_message "Project $project_name already exists in weblate"
            return 0
        fi
        fail_step_message "HTTP $http_code: $(echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body")"
        exit 1
        ;;
    404)
        show_step "Create project $project_name in weblate..."
        response=$(curl -s -w "%{http_code}" -o /tmp/response_body \
            -X POST \
            -H "Authorization: Token $WEBLATE_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"name\": \"$project_name\", \"slug\": \"$(sanitize_slug $project_name)\", \"web\": \"https://opendev.org/openstack/$project_name\"}" \
            "$WEBLATE_URL/api/projects/")
        
        http_code="${response: -3}"
        response_body=$(cat /tmp/response_body)
        
        echo "Weblate API Response (HTTP $http_code):"
        echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body"
        
        case $http_code in
            2*)
                complete_step_message "Created project $project_name in weblate"
                ;;
            400)

                if echo "$response_body" | grep -q "already exists"; then
                    skip_step_message "Project $project_name already exists in weblate"
                else
                    fail_step_message "HTTP 400: Invalid data: $(echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body")"
                    exit 1
                fi
                ;;
            *)
                fail_step_message "HTTP $http_code: $(echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body")"
                exit 1
                ;;
        esac
        ;;  
    *)
        error_handling $http_code "$response_body"
        exit 1
        ;;
esac


# Show components to create
# COMPONENTS are created when pot file is generated.
show_step "Check components to create..."
complete_step_message "Components to create: ${COMPONENTS[@]}"

show_step "Create components in Weblate..."

function create_or_get_component {
    local component=$1
    local project_name=$2
    local is_glossary=$3
    local pot_file="$TARGET_PROJECT_DIR/pot/$component.pot"

    show_step "Check the component $component exists in weblate..."
    response=$(curl -s -w "%{http_code}" -o /tmp/response_body \
        -H "Authorization: Token $WEBLATE_TOKEN" \
        "$WEBLATE_URL/api/projects/$(sanitize_slug $project_name)/components/$(sanitize_slug $component)/")
    
    http_code="${response: -3}"
    response_body=$(cat /tmp/response_body)
    
    
    case $http_code in
        200)
            skip_step_message "Component $component already exists in weblate"
            ;;
        400)
            response_type=$(echo "$response_body" | jq -r '.type')
            if [ "$response_type" == "validation_error" ]; then
                skip_step_message "Component $component already exists in weblate"
                continue
            fi
            fail_step_message "HTTP $http_code: $(echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body")"
            exit 1
            ;;
        404)
            if [ "$is_glossary" == "true" ]; then
                show_step "Creating glossary component $component in weblate..."
                response=$(curl -s -w "%{http_code}" -o /tmp/response_body \
                    -X POST \
                    -H "Authorization: Token $WEBLATE_TOKEN" \
                    -F "name=Glossary" \
                    -F "slug=glossary" \
                    -F "file_format=tbx" \
                    -F "filemask=*.tbx" \
                    -F "repo=local:" \
                    -F "vcs=local" \
                $WEBLATE_URL/api/projects/$(sanitize_slug $project_name)/components/)
            else
                if [ ! -f "$pot_file" ]; then
                    fail_step_message "POT file $pot_file does not exist"
                    return 1
                fi
                show_step "Creating component $component in weblate..."

                response=$(curl -s -w "%{http_code}" -o /tmp/response_body \
                    -X POST \
                    -H "Authorization: Token $WEBLATE_TOKEN" \
                    -F "docfile=@$pot_file" \
                    -F "name=$component" \
                    -F "slug=$(sanitize_slug $component)" \
                    -F "file_format=po-mono" \
                    -F "source_language=en" \
                $WEBLATE_URL/api/projects/$(sanitize_slug $project_name)/components/)
            fi 
            http_code="${response: -3}"
            response_body=$(cat /tmp/response_body)
            
            echo "Weblate API Response (HTTP $http_code):"
            echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body"
    
            case $http_code in
                2*)
                    complete_step_message "Created component $component in weblate"
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


# check pot file exists in the project

# Create glossary component at first
# If glossary is not first, 
# weblate automatically create a component as glossary in the first request.
COMPONENTS_TO_CREATE=("glossary" "${COMPONENTS[@]}")

for component in ${COMPONENTS_TO_CREATE[@]}; do

    if [ -f "$TARGET_PROJECT_DIR/pot/$component.pot" ] || [ "$component" == "glossary" ]; then
        show_step "Check the component $component in weblate..."

        response=$(curl -s -w "%{http_code}" -o /tmp/response_body \
            -H "Authorization: Token $WEBLATE_TOKEN" \
            "$WEBLATE_URL/api/components/$(sanitize_slug $project_name)/$(sanitize_slug $component)/")
        
        http_code="${response: -3}"
        response_body=$(cat /tmp/response_body)
        
        case $http_code in
            200)
                skip_step_message "Component $component already exists in weblate"
                ;;
            404)
                if [ "$component" == "glossary" ]; then
                    create_or_get_component "$component" "$project_name" "true"
                else
                    create_or_get_component "$component" "$project_name" "false"
                fi
                ;;
            *)
                error_handling $http_code "$response_body"
                ;;
        esac
    else
        echo "Warning: POT file for component $component not found: $TARGET_PROJECT_DIR/pot/$component.pot"
    fi
done

show_step "Push translation files to Weblate..."
# Get list of locales
# Convert project name from kebab-case to snake_case
function create_translation {
    local component=$1
    local weblate_locale=$2

    # Convert only the part before underscore to lowercase (e.g., Th -> th, ZH -> zh)
    if [[ "$weblate_locale" == *"_"* ]]; then
        prefix="${weblate_locale%%_*}"
        suffix="${weblate_locale#*_}"
        weblate_locale="${prefix,,}_${suffix}"
    else
        weblate_locale="${weblate_locale,,}"
    fi

    show_step "Check the translation $weblate_locale in weblate..."
    # 임시 파일로 응답 body와 상태 코드 분리
    response=$(curl -s -w "%{http_code}" -o /tmp/response_body \
        -H "Authorization: Token $WEBLATE_TOKEN" \
        "$WEBLATE_URL/api/translations/$project_name/$component/$weblate_locale/")

    http_code="${response: -3}"
    response_body=$(cat /tmp/response_body)
    
    case $http_code in
        200)
            skip_step_message "Translation $weblate_locale already exists in weblate"
            ;;
        404)
            show_step "Create translation $weblate_locale in weblate..."
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
                    complete_step_message "Created translation $weblate_locale in weblate"
                    ;;
                *)
                if echo "$response_body" | jq . >/dev/null 2>&1; then
                    echo "$response_body" | jq .
                else
                    echo "$response_body"
                fi
                ;;
            esac
            ;;
        *)
            if echo "$response_body" | jq . >/dev/null 2>&1; then
                echo "$response_body" | jq .
            else
                echo "$response_body"
            fi
            ;;
    esac
}

function push_po_file {
    local weblate_locale=$1
    local po_file=$2
    local component=$3

    # Check plural forms in the po file
    python3 $SCRIPTS_DIR/python/plural.py $weblate_locale $po_file

    # Convert only the part before underscore to lowercase (e.g., Th -> th, ZH -> zh)
    if [[ "$weblate_locale" == *"_"* ]]; then
        prefix="${weblate_locale%%_*}"
        suffix="${weblate_locale#*_}"
        weblate_locale="${prefix,,}_${suffix}"
    else
        weblate_locale="${weblate_locale,,}"
    fi

    response=$(curl -s -w "%{http_code}" -o /tmp/response_body -X POST \
        -H "Authorization: Token $WEBLATE_TOKEN" \
        -F "file=@$po_file" \
        "$WEBLATE_URL/api/translations/$project_name/$component/$weblate_locale/file/")

    http_code="${response: -3}"
    response_body=$(cat /tmp/response_body)
    echo "$response_body" | jq '.' 2>/dev/null
    
    case $http_code in
        2*)
            # Check if result is false in the response
            result_status=$(echo "$response_body" | jq -r '.result // "unknown"' 2>/dev/null)
            if [ "$result_status" = "false" ]; then
                echo "$response_body" | jq . 2>/dev/null || echo "$response_body"
            fi
            complete_step_message "Pushed $weblate_locale po file in $component"
            ;;
        *)
            echo "⚠️  Continuing with next file..."
            ;;
    esac
}

project_package_name=${project_name//[-.]/_}

function get_locale_list {
    local component=$1

    case $component in
        "django"|"djangojs")
            # Django projects: module_name/locale/locale_name/LC_MESSAGES/component.po
            echo "${TARGET_PROJECT_DIR}/translations/${project_package_name}/locale/*/LC_MESSAGES/${component}.po"
            ;;
        "${project_name}")
            echo "${TARGET_PROJECT_DIR}/translations/${project_package_name}/locale/*/LC_MESSAGES/${project_package_name}.po"
            ;;
        "releasenotes")
            echo "${TARGET_PROJECT_DIR}/translations/releasenotes/source/locale/*/LC_MESSAGES/*.po"
            ;;
        *)
            echo "${TARGET_PROJECT_DIR}/translations/${project_package_name}/locale/*/LC_MESSAGES/${project_package_name}.po"
            ;;
    esac
}

function get_po_file_path {
    local component=$1
    local locale_file=$2
    
    # Extract locale name from the full path
    # For paths like /path/to/locale/de/LC_MESSAGES/file.po, extract "de"
    local locale_name=$(echo "$locale_file" | sed 's|.*/locale/\([^/]*\)/LC_MESSAGES/.*|\1|')
    
    case $component in
        "django"|"djangojs")
            # Django projects: locale/locale_name/LC_MESSAGES/component.po
            echo "${TARGET_PROJECT_DIR}/translations/${project_package_name}/locale/${locale_name}/LC_MESSAGES/${component}.po"
            ;;
        "${project_name}")
            echo "${TARGET_PROJECT_DIR}/translations/${project_package_name}/locale/${locale_name}/LC_MESSAGES/${project_package_name}.po"
            ;;
        "releasenotes")
            # For releasenotes, locale_file should be the full path
            echo "${TARGET_PROJECT_DIR}/translations/releasenotes/source/locale/${locale_name}/LC_MESSAGES/${component}.po"
            ;;
        *)
            echo "${TARGET_PROJECT_DIR}/translations/${project_package_name}/locale/${locale_name}/LC_MESSAGES/${project_package_name}.po"
            ;;
    esac
}

for component in ${COMPONENTS[@]}; do
    show_step "Processing component: $component"
    
    # Get locale list for this component
    locale_list=($(ls $(get_locale_list $component) 2>/dev/null || echo ""))
    complete_step_message "Found ${#locale_list[@]} locales for component $component"
    
    for locale in ${locale_list[@]}; do
        show_step "Push $locale po file in $component..."
        
        # Extract locale name from path for language mapping
        locale_name=$(echo "$locale" | sed 's|.*/locale/\([^/]*\)/LC_MESSAGES/.*|\1|')
        
        # Get the actual PO file path
        po_file=$(get_po_file_path $component $locale)
        
        echo ""
        
        if [ -f "$po_file" ]; then
            create_translation $component $locale_name

            sleep 5

            push_po_file $locale_name $po_file $component
            
            sleep 3
        else
            echo "DEBUG: PO file not found: $po_file"
        fi
        
    done
done
