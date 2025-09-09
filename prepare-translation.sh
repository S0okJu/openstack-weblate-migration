#!/bin/bash

# Exit if any command fails
set -e

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

VENV_PYTHON="$SCRIPTS_DIR/.venv/bin/python3"
VENV_PIP="$SCRIPTS_DIR/.venv/bin/pip3"

# TODO: Replace with actual values
WEBLATE_URL="<weblate_url>"
WEBLATE_TOKEN="<weblate_token>"

if [ -z "$WEBLATE_URL" || "$WEBLATE_URL" == "<weblate_url>" ]; then
    echo "WEBLATE_URL is not set"
    exit 1
fi
if [ -z "$WEBLATE_TOKEN" || "$WEBLATE_TOKEN" == "<weblate_token>" ]; then
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
PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
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

# Create project-name directory for multiple projects
show_step "Create project name directory..."
if [ ! -d "$PROJECTS_DIR/$project_name" ]; then
    mkdir -p $PROJECTS_DIR/$project_name
    complete_step_message "Created project name directory"
else
    skip_step_message "Project name directory already exists"
fi

# Clone project to projects directory
TARGET_PROJECT_DIR=${PROJECTS_DIR}/${project_name}/${project_name}
show_step "Cloning project $project_name..."
cd $PROJECTS_DIR/${project_name}
if [ ! -d "$TARGET_PROJECT_DIR" ]; then
    git clone https://opendev.org/openstack/$project_name
    complete_step_message "Cloned project $project_name"
else
    skip_step_message "Project $project_name already exists"
fi

PREPARE_ZANATA_CLIENT_DIR="${DEPENDENCIES_DIR}/openstack-zuul-jobs/roles/prepare-zanata-client/files"

ZANATA_VERSION="master"

cd $TARGET_PROJECT_DIR

# Use common_translation_update.sh
# There are some function about generating pot files 
source $PREPARE_ZANATA_CLIENT_DIR/common_translation_update.sh

# COMPONENTS is a list of components to be processed
# It'll be used for Weblate component creation
COMPONENTS=()

case "$project_name" in
    api-site|openstack-manuals|security-doc)
        init_manuals "$project_name"
        # POT file extraction is done in setup_manuals.
        setup_manuals "$project_name" "$ZANATA_VERSION"
        
        case "$project_name" in
            api-site)
                COMPONENTS+=("api-quick-start")
                COMPONENTS+=("firstapp")

                python3 $SCRIPTS_DIR/python/polib.py api-quick-start/locale/api-quick-start.pot
                python3 $SCRIPTS_DIR/python/polib.py firstapp/locale/firstapp.pot
                ;;
            security-doc)
                COMPONENTS+=("security-guide")
                python3 $SCRIPTS_DIR/python/polib.py security-guide/locale/security-guide.pot
                ;;
            *)
                COMPONENTS+=("doc")
                python3 $SCRIPTS_DIR/python/polib.py doc/locale/doc.pot
                # python3 $SCRIPTS_DIR/python/polib.py doc/locale/doc-$directory.pot
                ;;
        esac
        if [[ -f releasenotes/source/conf.py ]]; then
            extract_messages_releasenotes
            COMPONENTS+=("releasenotes")
            python3 $SCRIPTS_DIR/python/polib.py releasenotes/source/locale/releasenotes.pot
        fi
        ;;
    training-guides)
        setup_training_guides "$ZANATA_VERSION"
        COMPONENTS+=("doc")
        python3 $SCRIPTS_DIR/python/polib.py doc/locale/doc.pot
        # python3 $SCRIPTS_DIR/python/polib.py doc/locale/doc-$directory.pot
        ;;
    i18n)
        setup_i18n "$ZANATA_VERSION"
        COMPONENTS+=("doc")
        python3 $SCRIPTS_DIR/python/polib.py doc/locale/doc.pot
        # python3 $SCRIPTS_DIR/python/polib.py doc/locale/doc-$directory.pot
        ;;
    tripleo-ui)
        setup_reactjs_project "$project_name" "$ZANATA_VERSION"
        COMPONENTS+=("i18n")
        python3 $SCRIPTS_DIR/python/polib.py i18n/locale/i18n.pot
        ;;
    *)
        # Common setup for python and django repositories
        setup_project "$project_name" "$ZANATA_VERSION"
        # ---- Python projects ----
        module_names=$(get_modulename $project_name python)
        if [ -n "$module_names" ]; then
            if [[ -f releasenotes/source/conf.py ]]; then
                extract_messages_releasenotes
                COMPONENTS+=("releasenotes")
                python3 $SCRIPTS_DIR/python/polib.py releasenotes/source/locale/releasenotes.pot
            fi
            for modulename in $module_names; do
                extract_messages_python "$modulename"
                COMPONENTS+=("$modulename")
                python3 $SCRIPTS_DIR/python/polib.py $modulename/locale/$modulename.pot
            done
        fi

        # ---- Django projects ----
        module_names=$(get_modulename $project_name django)
        if [ -n "$module_names" ]; then
            install_horizon
            if [[ -f releasenotes/source/conf.py ]]; then
                extract_messages_releasenotes
                COMPONENTS+=("releasenotes")
                python3 $SCRIPTS_DIR/python/polib.py releasenotes/source/locale/releasenotes.pot
            fi
            for modulename in $module_names; do
                extract_messages_django "$modulename"
                COMPONENTS+=("$modulename")
                python3 $SCRIPTS_DIR/python/polib.py $modulename/locale/$modulename.pot
            done
        fi
        # ---- Documentation ----
        if [[ -f doc/source/conf.py ]]; then
            # Let's test this with some repos :)
            if [[ ${DOC_TARGETS[*]} =~ "$project_name" ]]; then
                extract_messages_doc
                COMPONENTS+=("doc")
                python3 $SCRIPTS_DIR/python/polib.py doc/source/locale/doc.pot
                # python3 $SCRIPTS_DIR/python/polib.py doc/source/locale/doc-$directory.pot
            fi
        fi
        ;;
esac

# In bash script, it did not handle duplication.
# So we need to delete duplicated components.
show_step "Delete duplicate components..."
if [ ${#COMPONENTS[@]} -gt 0 ]; then
    COMPONENTS=($(printf "%s\n" "${COMPONENTS[@]}" | sort -u))
    complete_step_message "Unique components: ${COMPONENTS[@]}"
else
    fail_step_message "No components to process"
    exit 1
fi

# ========================== Pull translations from zanata ===============
show_stage 8 "Pull translations from zanata"

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
            log_error "Client error occurred: $http_code"
            echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body"
            ;;
        5*)
            log_error "Server error occurred: $http_code"
            echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body"
            ;;
    esac
}


# TODO: Fix this functions
show_stage 9 "Create project and components in Weblate"

show_step "Create $project_name project in Weblate..."
response=$(curl -s --max-time 10 -w "%{http_code}" -H "Authorization: Token $WEBLATE_TOKEN" \
        "$WEBLATE_URL/api/projects/$project_name/")

http_code="${response: -3}"
case $http_code in
    200)
        skip_step_message "Project $project_name already exists in weblate"
        ;;
    404)
        show_step "Create project $project_name in weblate..."
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
                complete_step_message "Created project $project_name in weblate"
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

show_step "Create components in Weblate..."

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


# check pot file exists in the project
for component in ${COMPONENTS[@]}; do

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