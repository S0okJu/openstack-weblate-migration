#!/bin/bash

WEBLATE_URL="<WEBLATE_URL>"
WEBLATE_TOKEN="<WEBLATE_TOKEN>"

SCRIPTS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

VENV_PYTHON="$SCRIPTS_DIR/.venv/bin/python3"
VENV_PIP="$SCRIPTS_DIR/.venv/bin/pip3"

# Replace all non [a-zA-Z0-9_-]/ with hyphens for slugs
function clean_slug() {
    echo "${1//[^a-zA-Z0-9_-]/-}"
}

# Set up virtual environment
function setup_venv {
    cd $SCRIPTS_DIR

    # Set python virtual environment
    if [ ! -d ".venv" ]; then
        # >= 3.10
        python3.10 -m venv .venv
    fi
    
    $VENV_PIP install -r requirements.txt
    
    echo "[INFO]: Installing requirements..."
    if [ ! -d "requirements" ]; then
        git clone https://opendev.org/openstack/requirements
        
        cd requirements
        sudo apt install -y $(../.venv/bin/bindep -b)
        $VENV_PIP install -r upper-constraints.txt

        echo "[SUCCESS]: Requirements installed"
    else
        echo "[SKIP]: Requirements already installed"
    fi

    cd ..

    # Checkc zanata-cli
    echo "[INFO]: Checking zanata-cli..."
    if command -v zanata-cli &> /dev/null; then
        echo "[SUCESS]: Zanata CLI found: $(which zanata-cli)"
    else
        echo "[ERROR]: Zanata CLI not found in PATH"
        return 1 
    fi
        
    # Install openstack-zuul-jobs
    echo "[INFO]: Installing openstack-zuul-jobs..."
    if [ ! -d "openstack-zuul-jobs" ]; then
        git clone https://github.com/openstack/openstack-zuul-jobs.git
        echo "[SUCCESS]: openstack-zuul-jobs installed"
    else
        echo "[SKIP]: openstack-zuul-jobs already installed"
    fi

    
    # Set create-zanata-xml.py information
    CREATE_ZANATA_XML_SCRIPT="openstack-zuul-jobs/roles/prepare-zanata-client/files/create-zanata-xml.py"
    if [ -f "$CREATE_ZANATA_XML_SCRIPT" ]; then
        echo "[SUCCESS]: create-zanata-xml.py found in repository"
        chmod +x "$CREATE_ZANATA_XML_SCRIPT"
    else
        echo "[ERROR]: create-zanata-xml.py not found in repository"
        return 1
    fi
    
    echo "[SUCCESS]: setup_venv completed"
    return 0
}

# Set environment variables for zanata
function set_zanata_config {
    local project_name=$1
    
    # Find zanata.ini file
    local zanata_ini_path="$HOME/.config/zanata.ini"
    if [ -z "$zanata_ini_path" ]; then
        echo "[ERROR]: zanata.ini not found in $HOME/.config/zanata.ini"
        return 1
    fi
    
    echo "[INFO]: Using zanata.ini: $zanata_ini_path"
    
    # Parse zanata.ini file using Python
    # set environment variables
    $VENV_PYTHON $SCRIPTS_DIR/python/zanata_config_parser.py $zanata_ini_path $project_name
    
    # Check required values
    if [ -z "$ZANATA_URL" ] || [ -z "$ZANATA_USERNAME" ] || [ -z "$ZANATA_API_KEY" ] || [ -z "$ZANATA_PROJECT_ID" ]; then
        echo "[ERROR]: Missing required Zanata configuration values" >&2
        return 1
    fi
    
    echo "[SUCCESS]: Zanata configuration loaded successfully"
    return 0
}

function pull_zanata_project {
    project_name=$1

    # Set zanata-cli environment variables
    export ZANATA_URL="$ZANATA_URL"
    export ZANATA_USERNAME="$ZANATA_USERNAME"
    export ZANATA_API_KEY="$ZANATA_API_KEY"
    export ZANATA_PROJECT_ID="$project_name"
    export ZANATA_VERSION_ID="master"

    mkdir -p $SCRIPTS_DIR/$project_name
    cd $SCRIPTS_DIR/$project_name    
    echo "[INFO]: Pulling project $project_name..."
    
    # If zanata.xml file does not exist, create it
    if [ ! -f "zanata.xml" ]; then
        echo "[INFO]: Creating zanata.xml..."
        $SCRIPTS_DIR/.venv/bin/python3 $SCRIPTS_DIR/openstack-zuul-jobs/roles/prepare-zanata-client/files/create-zanata-xml.py -p "$project_name" --srcdir . --txdir . -r '**/*.pot' '{path}/{locale_with_underscore}/LC_MESSAGES/{filename}.po' -e '.*/**' -f zanata.xml -v "master"
    fi
    
    zanata-cli -B -e pull
}

function create_or_get_project {
    project_name=$1
    
    echo "[INFO]: Checking if project $project_name exists in Weblate..."
    
    # Check if project exists
    response=$(curl -s -w "%{http_code}" -H "Authorization: Token $WEBLATE_TOKEN" \
        "$WEBLATE_URL/api/projects/$project_name/")
    
    http_code="${response: -3}"    
    if [ "$http_code" = "200" ]; then
        echo "[SKIP]: Project $project_name already exists in Weblate"
        return 0

    elif [ "$http_code" = "404" ]; then
        echo "[INFO]: Project $project_name does not exist, creating it..."
        
        # Create project
        response=$(curl -s -w "%{http_code}" -X POST \
            -H "Authorization: Token $WEBLATE_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"name\": \"openstack/$project_name\", \"slug\": \"$project_name\", \"web\": \"https://opendev.org/openstack/$project_name\"}" \
            "$WEBLATE_URL/api/projects/")
        
        http_code="${response: -3}"
        if [ "$http_code" = "201" ] || [ "$http_code" = "200" ]; then
            echo "[SUCCESS]: Successfully created project $project_name"
            return 0
        else
            echo "[ERROR]: Failed to create project (HTTP $http_code): $response"
            return 1
        fi

    else
        echo "[ERROR]: Unexpected response when checking project (HTTP $http_code)"
        return 1
    fi    
}


function create_translation {
    local project_name=$1
    local component_name=$2
    local weblate_locale=$3

    echo "[INFO]: Creating translation..."
    response=$(curl -s -w "%{http_code}" -X POST \
        -H "Authorization: Token $WEBLATE_TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"language_code\": \"$weblate_locale\"}" \
        "$WEBLATE_URL/api/components/$project_name/$component_name/translations/")
    
    sleep 5
    
    create_http_code="${response: -3}"
    
    if [ "$create_http_code" = "201" ] || [ "$create_http_code" = "200" ]; then
        echo "[SUCCESS]: Successfully created translation $weblate_locale for component $component_name"
    elif [ "$create_http_code" = "400" ]; then
        echo "[SKIP]: Translation $weblate_locale already exists (HTTP 404) - skipping creation"
    else
        echo "[ERROR]: Failed to create translation (HTTP $create_http_code)"
        cat /tmp/create_response.json >&2
        return 1
    fi
    return 0
}

# Weblate에 번역 파일 업로드
function upload_translation_to_weblate {
    local project_name=$1
    local component_name=$2
    local locale=$3
    local po_file=$4
    
    echo "[INFO]: Uploading translation file $po_file for locale $locale to component $component_name"
    
    # Convert Zanata locale to Weblate locale
    # Weblate use simple locale code like ko_KR -> ko 
    local weblate_locale=$locale
    case $locale in
        "zh-CN") weblate_locale="zh_Hans" ;;
        "zh-TW") weblate_locale="zh_Hant" ;;
        "pt-BR") weblate_locale="pt_BR" ;;
        "pt-PT") weblate_locale="pt_PT" ;;
        "ko-KR") weblate_locale="ko" ;;
        *) weblate_locale=$(echo $locale) ;;
    esac
    echo "[INFO]: Converted locale: $locale -> $weblate_locale"
    
    # Step 2-3: Upload translation file
    echo "[INFO]: Uploading translation file..."
    response=$(curl -s -w "%{http_code}" -X POST \
        -H "Authorization: Token $WEBLATE_TOKEN" \
        -F "file=@$po_file" \
        "$WEBLATE_URL/api/translations/$project_name/$component_name/$weblate_locale/file/")
    
    # Wait for 5 seconds
    sleep 5
    
    http_code="${response: -3}"
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        echo "  ✓ Successfully uploaded translation for $weblate_locale to component $component_name"
        return 0
    elif [ "$http_code" = "400" ]; then
        echo "  ✓ Translation upload failed (HTTP 400) - translation might already exist"
        cat /tmp/upload_response.json >&2
        return 0
    else
        echo "  ✗ Failed to upload translation (HTTP $http_code)"
        cat /tmp/upload_response.json >&2
        return 1
    fi
}

# Download all translation files from Zanata and upload to Weblate
function migrate_zanata_translations {
    local project_name=$1
    local version=$2
    
    echo "[INFO]: Starting Zanata to Weblate migration for project: $project_name, version: $version"
    
    # 1단계: Zanata에서 프로젝트 locale 리스트 가져오기
    echo "[INFO]: Getting locale list from Zanata..."
    
    # Parse Zanata configuration
    if ! set_zanata_config "$project_name"; then
        return 1
    fi
    
    # zanata.xml에서 locale 리스트 가져오기
    cd "${SCRIPTS_DIR}/${PROJECT_NAME}"
        
    # Extract locale list from downloaded translation files
    all_locales=$(find . -name "*.po" -type f | sed 's|.*/\([^/]*\)/LC_MESSAGES/.*|\1|' | sort -u | tr '\n' ' ')    
    locales=$(echo $all_locales | xargs)  # Remove spaces
    
    if [ $? -eq 0 ] && [ -n "$locales" ]; then
        echo "[SUCCESS]: Found locales from zanata.xml: $locales"
        cd ..
    else
        echo "[ERROR]: Failed to get locales from zanata.xml"
        cd ..
        return 1
    fi
        
    # Step 2: Upload translations to Weblate components
    echo "[INFO]: Uploading translations to Weblate components..."
    
    # Process each locale
    for locale in $locales; do
        echo "[INFO]: Processing locale: $locale"
        
        # Package name (convert hyphen to underscore)
        package_name=$(echo $PROJECT_NAME | tr '-' '_')

        # Upload translation files for each component
        for component_name in django neutron-fwaas-dashboard releasenotes; do
            # Determine PO file path for each component            
            case $component_name in        
                "django")
                    po_file="${PROJECT_NAME}/${package_name}/locale/${locale}/LC_MESSAGES/${component_name}.po"
                    ;;
                "neutron-fwaas-dashboard")
                    # Convert hyphen to underscore (for file name)
                    file_name=$(echo $component_name | tr '-' '_')
                    po_file="${PROJECT_NAME}/${package_name}/locale/${locale}/LC_MESSAGES/${file_name}.po"
                    ;;
                "releasenotes")
                    po_file="${PROJECT_NAME}/releasenotes/source/locale/${locale}/LC_MESSAGES/releasenotes.po"
                    ;;
            esac
            
            if [ -f "$po_file" ]; then
                echo "[INFO]: Processing component: $component_name"
                echo "[INFO]: PO file: $po_file"
                upload_translation_to_weblate "$project_name" "$component_name" "$locale" "$po_file"
            else
                echo "[ERROR]: No PO file found for locale $locale, component $component_name"
            fi
        done
    done
    
    echo "🎉 Zanata to Weblate migration completed!"
}

# Extract releasenotes messages and create a single file.
function extract_messages_releasenotes {
    local keep_workdir=$1
    
    echo "[INFO]: Extracting releasenotes messages..."
    
    cd ${SCRIPTS_DIR}/${PROJECT_NAME}
    $SCRIPTS_DIR/.venv/bin/sphinx-build -b gettext -d releasenotes/build/doctrees \
        releasenotes/source releasenotes/work
    cd ..

    # Extract package name 
    # Save pot file in work directory
    echo "[INFO]: Checking work directory..."
    if [ ! -d ${PROJECT_NAME}/releasenotes/work ]; then
        mkdir -p ${PROJECT_NAME}/releasenotes/work
    fi

    # Remove existing build directory
    rm -rf ${PROJECT_NAME}/releasenotes/build
    
    # Concatenate pot files in work directory
    if [ -d ${PROJECT_NAME}/releasenotes/work ] && [ "$(ls -A ${PROJECT_NAME}/releasenotes/work/*.pot 2>/dev/null)" ]; then
        echo "Found .pot files, concatenating..."

        # Create locale directory
        mkdir -p ${PROJECT_NAME}/locale
        
        # Remove duplicates and concatenate
        msgcat --sort-by-file ${PROJECT_NAME}/releasenotes/work/*.pot \
            > ${PROJECT_NAME}/locale/releasenotes.pot
        
        echo "[SUCCESS]: Created releasenotes.pot"
    else
        echo "[ERROR]: No .pot files found in work directory"
        return 1
    fi  
    
    # If keep_workdir is empty, delete the work directory
    if [ ! -n "$keep_workdir" ]; then
        rm -rf ${PROJECT_NAME}/releasenotes/work
    fi

    return 0
}

# Official document reference
# https://opendev.org/openstack/openstack-zuul-jobs/src/branch/master/roles/prepare-zanata-client/files/common_translation_update.sh#L402
function extract_django_messages {
    echo "[INFO]: Extracting django messages..."

    KEYWORDS="-k gettext_noop -k gettext_lazy -k ngettext_lazy:1,2"
    KEYWORDS+=" -k ugettext_noop -k ugettext_lazy -k ungettext_lazy:1,2"
    KEYWORDS+=" -k npgettext:1c,2,3 -k pgettext_lazy:1c,2 -k npgettext_lazy:1c,2,3"
    
    # Only run if babel-django.cfg or babel-djangojs.cfg file exists
	# It exists in the project folder
    for DOMAIN in djangojs django ; do
        if [ -f ${PROJECT_NAME}/babel-${DOMAIN}.cfg ]; then
            pot=${PROJECT_NAME}/locale/${DOMAIN}.pot
            touch ${pot}
			
            $SCRIPTS_DIR/.venv/bin/pybabel extract -F ${PROJECT_NAME}/babel-${DOMAIN}.cfg  \
                --add-comments Translators: \
                --msgid-bugs-address="https://bugs.launchpad.net/openstack-i18n/" \
                --project=${PROJECT_NAME} \
                $KEYWORDS \
                -o ${pot} ${PROJECT_NAME} \
                --version master
            
            
			# Check if the POT file is empty
            check_empty_pot ${pot}
        fi
    done
    
    echo "[SUCCESS]: Extracted django messages"
}

# Official document reference
# https://opendev.org/openstack/openstack-zuul-jobs/src/branch/master/roles/prepare-zanata-client/files/common_translation_update.sh#L367
function extract_python_messages {
    echo "[INFO]: Extracting python messages..."

    local pot=${PROJECT_NAME}/locale/${PROJECT_NAME}.pot

    # In case this is an initial run, the locale directory might not
    # exist, so create it since extract_messages will fail if it does
    # not exist. So, create it if needed.
    mkdir -p ${PROJECT_NAME}/locale

    # Update the .pot files
    # The "_C" and "_P" prefix are for more-gettext-support blueprint,
    # "_C" for message with context, "_P" for plural form message.
    $SCRIPTS_DIR/.venv/bin/pybabel ${QUIET} extract \
        --add-comments Translators: \
        --msgid-bugs-address="https://bugs.launchpad.net/openstack-i18n/" \
        --project=${PROJECT_NAME} \
        -k "_C:1c,2" -k "_P:1,2" \
        -o ${pot} ${PROJECT_NAME}
        
    check_empty_pot ${pot}

    echo "[SUCCESS]: Extracted python messages"
    return 0
}

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

function create_or_get_component {
    project_name=$1
    component_name=$2
    pot_file=$3
    
    echo "Checking if component $component_name exists in project $project_name..."
    
    # Check if component already exists
    response=$(curl -s -w "%{http_code}" -H "Authorization: Token $WEBLATE_TOKEN" \
        "$WEBLATE_URL/api/projects/$project_name/components/$component_name/")
    
    # Wait for 5 seconds
    sleep 5
    
    http_code="${response: -3}"
    
    # 200이면 이미 존재함
    if [ "$http_code" = "200" ]; then
        echo "Component $component_name already exists in project $project_name"
        return 0
    fi
    
    # If component does not exist, create it
    if [ "$http_code" = "404" ]; then
        echo "Component $component_name does not exist, creating it..."
        
        # Create component
        response=$(curl -s -w "%{http_code}" -X POST \
            -H "Authorization: Token $WEBLATE_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"name\": \"$component_name\", \"slug\": \"$component_name\", \"file_format\": \"po\"}" \
            "$WEBLATE_URL/api/projects/$project_name/components/")
        
        # Wait for 5 seconds
        sleep 5
        
        http_code="${response: -3}"
        
        if [ "$http_code" = "201" ] || [ "$http_code" = "200" ]; then
            echo "Successfully created component $component_name"
            
            # Upload POT file
            response=$(curl -s -w "%{http_code}" -X POST \
                -H "Authorization: Token $WEBLATE_TOKEN" \
                -F "file=@$pot_file" \
                "$WEBLATE_URL/api/projects/$project_name/components/$component_name/file/")
            
            # Wait for 5 seconds
            sleep 5
            
            upload_http_code="${response: -3}"
            
            if [ "$upload_http_code" = "200" ] || [ "$upload_http_code" = "201" ]; then
                echo "Successfully uploaded POT file for component $component_name"
                return 0
            else
                echo "Failed to upload POT file (HTTP $upload_http_code)"
                return 1
            fi
        elif [ "$http_code" = "400" ]; then
            echo "Component $component_name already exists (HTTP 400) - skipping creation"
            return 0
        else
            echo "Failed to create component (HTTP $http_code)"
            return 1
        fi
    fi
    
    echo "Unexpected response when checking component (HTTP $http_code)"
    return 1
}

function create_components {
    project_name=$1
    
    echo "Creating components for project $project_name..."
    
    # Create components for each POT file
    for pot_file in ${PROJECT_NAME}/locale/*.pot; do
        if [ -f "$pot_file" ]; then
            component_name=$(basename "$pot_file" .pot)
            echo "Processing component: $component_name"
            
            if ! create_or_get_component "$project_name" "$component_name" "$pot_file"; then
                echo "Warning: Failed to create component $component_name, continuing with next component"
                continue
            fi
        fi
    done
    return 0
}

function main() {
    project_name=$1
    
    echo "[INFO]: main() called with args: '$1' '$2'"
    
    # Set PROJECT_NAME variable
    PROJECT_NAME=$project_name
    
    setup_venv
    
    set_zanata_config $project_name
    pull_zanata_project $project_name

    create_or_get_project $project_name
    
    extract_messages_releasenotes
    extract_django_messages
    extract_python_messages

    create_components $project_name
    
    if [ "$2" = "--migrate-zanata" ]; then
        echo "[INFO]: Starting Zanata migration..."
        migrate_zanata_translations "$project_name" "master"
    else
        echo "[INFO]: Skipping Zanata migration (use --migrate-zanata to enable)"
    fi
    
    return 0
}

# Run script
if [ $# -lt 1 ]; then
    echo "Usage: $0 <project_name> [--migrate-zanata]"
    echo "Example: $0 neutron-fwaas-dashboard --migrate-zanata"
    exit 1
fi

main "$@"