#!/bin/bash

# Exit if any command fails
set -e

# ========================== Color definitions ==========================
# Color definitions for log messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# ========================== Set up the work environment ==========================
project_name=$1
if [ -z "$project_name" ]; then
    echo "Project name is required"
    exit 1
fi

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

VENV_PYTHON="$SCRIPTS_DIR/.venv/bin/python3"
VENV_PIP="$SCRIPTS_DIR/.venv/bin/pip3"

# Folder structure
# - work
#   - pot-works: generate pot files 
#   - translations: pull from zanata and push to weblate 
# - .venv: virtual environment
log_info "Setting up work directory..."
WORK_DIR=$SCRIPTS_DIR/work
if [ ! -d "$WORK_DIR" ]; then
    mkdir -p $WORK_DIR
    log_success "Created work directory"
else
    log_skip "Work directory already exists"
fi

# Install gettext
sudo apt install -y gettext
sudo apt install -y jq

# ========================== Set up pot-works environment ==========================
# Make pot-works directory to work 
log_info "Setting up pot-works directory..."
POT_WORK_DIR=$WORK_DIR/pot-works
if [ ! -d "$POT_WORK_DIR" ]; then
    mkdir -p $POT_WORK_DIR
    log_success "Created pot-works directory"
else
    log_skip "Pot-works directory already exists"
fi

# Create virtual environment
log_info "Setting up virtual environment..."
if [ ! -d "$SCRIPTS_DIR/.venv" ]; then
    python3.10 -m venv $SCRIPTS_DIR/.venv
    log_success "Created virtual environment"
else
    log_skip "Virtual environment already exists"
fi

# Install dependencies
log_info "Installing dependencies in virtual environment..."
$VENV_PIP install -r $SCRIPTS_DIR/requirements.txt

if [ ! -d "$POT_WORK_DIR/requirements" ]; then
    cd $POT_WORK_DIR
    git clone https://opendev.org/openstack/requirements

    log_info "Installing bindep in virtual environment..."
    
    cd requirements
    $VENV_PIP install bindep
    
    # We need to install system dependencies with bindep
    log_info "Installing system dependencies with bindep..."
    bindep_packages=$($SCRIPTS_DIR/.venv/bin/bindep -b 2>/dev/null)
    if [ -n "$bindep_packages" ]; then
        log_info "Installing packages: $bindep_packages"
        sudo apt install -y $bindep_packages
    else
        log_warning "No system dependencies found by bindep"
    fi

    log_info "Installing upper-constraints in virtual environment..."       
    $VENV_PIP install -r upper-constraints.txt

    cd ..
    rm -rf requirements
else
    log_skip "Requirements directory already exists"
fi 

# Clone project to pot-works directory
log_info "Cloning project $project_name..."
cd $POT_WORK_DIR
if [ ! -d "$POT_WORK_DIR/$project_name" ]; then
    git clone https://opendev.org/openstack/$project_name
    log_success "Cloned project $project_name"
else
    log_skip "Project $project_name already exists"
fi

# =============== Generate POT files ===============
log_info "Start to generate POT files..."
POT_PROJECT_PATH=${POT_WORK_DIR}/${project_name}

# Delete empty pot files
# Official document reference
# https://opendev.org/openstack/openstack-zuul-jobs/src/branch/master/roles/prepare-zanata-client/files/common_translation_update.sh#L352
function check_empty_pot {
    local pot=$1

    # We don't need to add or send around empty source files.
    trans=$(msgfmt --statistics -o /dev/null ${pot} 2>&1)
    if [ "$trans" = "0 translated messages." ] ; then
        rm $pot
        # Remove file from git if it's under version control. We previously
        # had all pot files under version control, so remove file also
        # from git if needed.
        if [ -d .git ]; then
            git rm --ignore-unmatch $pot
        fi
    fi
}

# Extract releasenotes messages and create a single file.
function extract_messages_releasenotes {
    local keep_workdir=$1
    
    log_info "Extracting releasenotes messages..."
    
    cd ${POT_PROJECT_PATH}
    $SCRIPTS_DIR/.venv/bin/sphinx-build -b gettext -d releasenotes/build/doctrees \
        releasenotes/source releasenotes/work
    cd ..
    log_success "Extracted releasenotes messages"

    # Extract package name 
    # Save pot file in work directory
    if [ ! -d ${POT_PROJECT_PATH}/releasenotes/work ]; then
        mkdir -p ${POT_PROJECT_PATH}/releasenotes/work
    fi

    # Remove existing build directory
    rm -rf ${POT_PROJECT_PATH}/releasenotes/build
    
    # Concatenate pot files in work directory
    if [ -d ${POT_PROJECT_PATH}/releasenotes/work ] && [ "$(ls -A ${POT_PROJECT_PATH}/releasenotes/work/*.pot 2>/dev/null)" ]; then
        log_info "Found .pot files, concatenating..."

        # Create locale directory
        mkdir -p ${POT_PROJECT_PATH}/locale
        
        # Remove duplicates and concatenate
        msgcat --sort-by-file ${POT_PROJECT_PATH}/releasenotes/work/*.pot \
            > ${POT_PROJECT_PATH}/locale/releasenotes.pot
        
        log_success "Created releasenotes.pot"
    else
        log_error "No releasenotes.pot files found in work directory"
        return 1
    fi  
    
    # If keep_workdir is empty, delete the work directory
    if [ ! -n "$keep_workdir" ]; then
        rm -rf ${POT_PROJECT_PATH}/releasenotes/work
    fi

    return 0
}

extract_messages_releasenotes

# Extract django messages and create a single file.
# Official document reference
# https://opendev.org/openstack/openstack-zuul-jobs/src/branch/master/roles/prepare-zanata-client/files/common_translation_update.sh#L402
function extract_django_messages {
    log_info "Extracting django messages..."

    KEYWORDS="-k gettext_noop -k gettext_lazy -k ngettext_lazy:1,2"
    KEYWORDS+=" -k ugettext_noop -k ugettext_lazy -k ungettext_lazy:1,2"
    KEYWORDS+=" -k npgettext:1c,2,3 -k pgettext_lazy:1c,2 -k npgettext_lazy:1c,2,3"
    KEYWORDS+=" -k ngettext:1,2 -k ungettext:1,2"
    
    # Only run if babel-django.cfg or babel-djangojs.cfg file exists
	# It exists in the project folder
    for DOMAIN in djangojs django ; do
        if [ -f ${POT_PROJECT_PATH}/babel-${DOMAIN}.cfg ]; then
            pot=${POT_PROJECT_PATH}/locale/${DOMAIN}.pot
            touch ${pot}
			
            $SCRIPTS_DIR/.venv/bin/pybabel extract -F ${POT_PROJECT_PATH}/babel-${DOMAIN}.cfg  \
                --add-comments Translators: \
                --msgid-bugs-address="https://bugs.launchpad.net/openstack-i18n/" \
                --project=${project_name} \
                $KEYWORDS \
                -o ${pot} ${project_name} \
                --version master
            
			# Check if the POT file is empty
            check_empty_pot ${pot}
        fi
    done
    
    log_success "Extracted django messages"
}

extract_django_messages

# Extract python messages and create a single file.
# Official document reference
# https://opendev.org/openstack/openstack-zuul-jobs/src/branch/master/roles/prepare-zanata-client/files/common_translation_update.sh#L367
function extract_python_messages {
    log_info "Extracting python messages..."

    local pot=${POT_PROJECT_PATH}/locale/${project_name}.pot

    # In case this is an initial run, the locale directory might not
    # exist, so create it since extract_messages will fail if it does
    # not exist. So, create it if needed.
    mkdir -p ${POT_PROJECT_PATH}/locale

    # Update the .pot files
    # The "_C" and "_P" prefix are for more-gettext-support blueprint,
    # "_C" for message with context, "_P" for plural form message.
    $SCRIPTS_DIR/.venv/bin/pybabel ${QUIET} extract \
        --add-comments Translators: \
        --msgid-bugs-address="https://bugs.launchpad.net/openstack-i18n/" \
        --project=${project_name} \
        -k "_C:1c,2" -k "_P:1,2" \
        -o ${pot} ${project_name}
        
    check_empty_pot ${pot}

    echo "[+]: Extracted python messages"
    return 0
}

extract_python_messages

# ========================== Set up the translation environment ===============
log_info "Setting up translations directory..."
if [ ! -d "$WORK_DIR/translations" ]; then
    mkdir -p $WORK_DIR/translations
    log_success "Created translations directory"
else
    log_skip "Translations directory already exists"
fi

log_info "Check zanata-cli installation..."
if ! zanata-cli --version; then
    log_error "zanata-cli is not installed"
    exit 1
else
    log_skip "zanata-cli already exists"
fi

# ========================== Pull translations from zanata ===============
log_info "Make translation directory..."
TRANSLATION_DIR=$WORK_DIR/translations
if [ ! -d "$TRANSLATION_DIR" ]; then
    mkdir -p $TRANSLATION_DIR
    log_success "Created translation directory"
else
    log_skip "Translation directory already exists"
fi

# Check zanata.ini file exists 
if [ -f "$HOME/.config/zanata.ini" ]; then
    log_skip "zanata.ini already exists"
else
    log_error "zanata.ini is not found"
    exit 1
fi

cd $TRANSLATION_DIR

# Installing openstack-zuul-jobs
log_info "Installing openstack-zuul-jobs..."
if [ ! -d "openstack-zuul-jobs" ]; then
    git clone https://opendev.org/openstack/openstack-zuul-jobs.git
    log_success "Installed openstack-zuul-jobs"
else
    log_skip "openstack-zuul-jobs already installed"
fi

# Set create-zanata-xml.py information
CREATE_ZANATA_XML_SCRIPT="openstack-zuul-jobs/roles/prepare-zanata-client/files/create-zanata-xml.py"
if [ -f "$CREATE_ZANATA_XML_SCRIPT" ]; then
    chmod +x "$CREATE_ZANATA_XML_SCRIPT"
else
    log_error "create-zanata-xml.py not found in repository"
    exit 1
fi

log_info "Create zanata.xml file..."
cd $POT_PROJECT_PATH

if [ ! -f "zanata.xml" ]; then    
    $VENV_PYTHON $TRANSLATION_DIR/$CREATE_ZANATA_XML_SCRIPT \
        -p "$project_name" \
        --srcdir . \
        --txdir . \
        -r '**/*.pot' \
        '{path}/{locale_with_underscore}/LC_MESSAGES/{filename}.po' \
        -e '.*/**' \
        -f zanata.xml \
        -v "master"
    log_success "Created zanata.xml file"
else
    log_skip "zanata.xml file already exists"
fi

# Pull translations from zanata
cd $TRANSLATION_DIR

# Copy zanata.xml to translation directory
if [ -f "$POT_PROJECT_PATH/zanata.xml" ]; then
    cp "$POT_PROJECT_PATH/zanata.xml" .
    log_info "Copied zanata.xml to translation directory"
else
    log_error "zanata.xml not found in project directory"
    exit 1
fi

log_info "Pulling translations from zanata..."
zanata-cli -B -e pull
log_success "Pulled translations from zanata"
