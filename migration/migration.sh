#!/bin/bash
# Migration script to create Weblate components and translations
# migration.sh

# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

PROJECT=$1
BRANCH_NAME=$2
IS_SETUP=$3

# Replace /'s in branch names with -'s because Zanata doesn't
# allow /'s in version names.
BRANCHNAME=${BRANCH_NAME:-"master"}
ZANATA_VERSION=${BRANCHNAME//\//-}

# List the components to be handled
COMPONENTS=()

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPTSDIR/po-utils.sh
source $SCRIPTSDIR/prepare-weblate.sh
source $SCRIPTSDIR/prepare-workspace.sh
source $SCRIPTSDIR/preprocess-pot.sh
source $SCRIPTSDIR/pretty-printer.sh
source $SCRIPTSDIR/propose-translation.sh
source $SCRIPTSDIR/setup-translation.sh

# We need a UTF-8 locale, set it properly in case it's not set.
export LANG=en_US.UTF-8
export WEBLATE_URL="$WEBLATE_URL"
export WEBLATE_TOKEN="$WEBLATE_TOKEN"

stage "Check variables"
if [ -z "$WEBLATE_URL" ] || [ "$WEBLATE_URL" == "<weblate_url>" ]; then
    fail "WEBLATE_URL is not set"
    exit 1
fi
if [ -z "$WEBLATE_TOKEN" ] || [ "$WEBLATE_TOKEN" == "<weblate_token>" ]; then
    fail "WEBLATE_TOKEN is not set"
    exit 1
fi
debug "WEBLATE_URL and WEBLATE_TOKEN are set"
endstage


stage "Prepare workspace"
if ! prepare_workspace; then
    exit 1
fi
prepare_project_workspace "$PROJECT"
endstage

stage "Setup environment"
if [ "$IS_SETUP" == "true" ]; then
    if ! setup_env; then
        exit 1
    fi
fi
endstage

stage "Generate POT files"
source $HOME/workspace/.venv/bin/activate

cd $HOME/workspace/projects/$PROJECT/$PROJECT
case "$PROJECT" in
    api-site|openstack-manuals|security-doc)
        init_manuals "$PROJECT"
        # POT file extraction is done in setup_manuals.
        setup_manuals "$PROJECT" "$ZANATA_VERSION"
        
        case "$PROJECT" in
            api-site)
                preprocess_api_site_pot
                COMPONENTS+=("api-quick-start")
                COMPONENTS+=("firstapp")
                ;;
            security-doc)
                preprocess_security_doc_pot
                COMPONENTS+=("security-guide")
                ;;
            *)
                preprocess_doc_pot "doc"
                COMPONENTS+=("doc")

                # Process all doc-*.pot files
                for doc_pot_file in doc/locale/doc-*.pot; do
                    if [[ -f "$doc_pot_file" ]]; then
                        doc_component_name=$(basename "$doc_pot_file" .pot)
                        preprocess_doc_pot "$doc_component_name"
                        COMPONENTS+=("$doc_component_name")
                    fi
                done
                ;;
        esac
        if [[ "$ZANATA_VERSION" == "master" && -f releasenotes/source/conf.py ]]; then
            extract_messages_releasenotes
            preprocess_releasenotes_pot
            COMPONENTS+=("releasenotes")
        fi
        ;;
    training-guides)
        setup_training_guides "$ZANATA_VERSION"
        preprocess_training_guides_pot
        COMPONENTS+=("doc")
        ;;
    i18n)
        setup_i18n "$ZANATA_VERSION"
        preprocess_i18n_pot
        COMPONENTS+=("doc")
        ;;
    tripleo-ui)
        setup_reactjs_project "$PROJECT" "$ZANATA_VERSION"
        preprocess_reactjs_pot
        # The pot file is generated in the ./i18n directory
        COMPONENTS+=("i18n")
        ;;
    *)
        # ---- Python projects ----
        # Common setup for python and django repositories
        setup_project "$PROJECT" "$ZANATA_VERSION"
        module_names=$(python3 $SCRIPTSDIR/get-modulename.py -p $PROJECT -t python -f setup.cfg)
        debug "Python module names: $module_names"
        if [ -n "$module_names" ]; then
            if [[ "$ZANATA_VERSION" == "master" && -f releasenotes/source/conf.py ]]; then
                extract_messages_releasenotes
                preprocess_releasenotes_pot
                COMPONENTS+=("releasenotes")
            fi
            for modulename in $module_names; do
                extract_messages_python "$modulename"
                preprocess_python_pot "$modulename" "$modulename"
                COMPONENTS+=("$modulename")
            done
        fi

        # ---- Django projects ----
        module_names=$(python3 $SCRIPTSDIR/get-modulename.py -p $PROJECT -t django -f setup.cfg)
        debug "Django module names: $module_names"
        # Convert array for proper counting
        # In Weblate, we can't use multiple components name in a project.
        # If it has multiple Django modules, we set name <module_name>-django/djangojs
        # to identify the module in weblate. 
        # e.g. horizon-django, openstack-dashboard-django
        django_module_names=($module_names)

        if [ ${#django_module_names[@]} -ge 2 ]; then
            is_multiple=true
        else
            is_multiple=false
        fi

        if [ -n "$module_names" ]; then
            if [[ -f releasenotes/source/conf.py ]]; then
                extract_messages_releasenotes
                preprocess_releasenotes_pot
                COMPONENTS+=("releasenotes")
            fi

            # Check if the project has multiple Django modules
            # If it has, we set name <module_name>-django/djangojs
            for modulename in ${django_module_names[@]}; do
                # Extract messages and generate pot files for all Django modules
                extract_messages_django "$modulename"

                if [ -f "$modulename/locale/django.pot" ]; then
                    dest_modulename="django"
                    if [ "$is_multiple" == "true" ]; then
                        # The module name basically use _ as separator.
                        # In weblate, we need to use -.
                        module_name_hyphenated=$(echo "$modulename" | sed 's/_/-/g')
                        dest_modulename="${module_name_hyphenated}-django"
                    fi

                    preprocess_django_pot "$modulename" "django" "$dest_modulename"
                    COMPONENTS+=("$dest_modulename")
                fi

                if [ -f "$modulename/locale/djangojs.pot" ]; then
                    dest_modulename="djangojs"
                    if [ "$is_multiple" == "true" ]; then
                        module_name_hyphenated=$(echo "$modulename" | sed 's/_/-/g')
                        dest_modulename="${module_name_hyphenated}-djangojs"
                    fi
                    preprocess_django_pot "$modulename" "djangojs" "$dest_modulename"
                    COMPONENTS+=("$dest_modulename")
                fi
            done
        fi

        # ---- Documentation ----
        if [[ -f doc/source/conf.py ]]; then
            # Let's test this with some repos :)
            if [[ ${DOC_TARGETS[*]} =~ "$PROJECT" ]]; then
                extract_messages_doc
                preprocess_doc_pot "doc"
                COMPONENTS+=("doc")

                for doc_pot_file in doc/source/locale/doc-*.pot; do
                    if [[ -f "$doc_pot_file" ]]; then
                        doc_component_name=$(basename "$doc_pot_file" .pot)
                        preprocess_doc_pot "$doc_component_name"
                        COMPONENTS+=("$doc_component_name")
                    fi
                done
            fi
        fi
        ;;
esac

# In bash script, it did not handle duplication.
# So we need to delete duplicated components.
if [ ${#COMPONENTS[@]} -eq 0 ]; then
    fail "No components to process"
    exit 1
fi

unique_components=()
for component in "${COMPONENTS[@]}"; do
    if [[ ! " ${unique_components[@]} " =~ " ${component} " ]]; then
        unique_components+=("$component")
    fi
done

COMPONENTS=("${unique_components[@]}")
debug "Unique components: ${COMPONENTS[@]}"
endstage

stage "Pull translations from Zanata"

cd $HOME/workspace/projects/$PROJECT/translations

# When we generate POT files, 
# We create zanata.xml file in the translations directory.
# So we need to copy it to the translations directory
# for working in it.
cp $HOME/workspace/projects/$PROJECT/$PROJECT/zanata.xml .
cp $HOME/workspace/projects/$PROJECT/$PROJECT/setup.cfg .

case "$PROJECT" in
    api-site|openstack-manuals|security-doc|i18n|training-guides)
        pull_from_zanata 
        ;;
    tripleo-ui)
        propose_reactjs
        ;;
    *)   
        handle_python_django_project $PROJECT
        ;;  
esac

endstage

stage "Create Weblate components"
cd $SCRIPTSDIR

# Create project
python3 -u $SCRIPTSDIR/weblate_utils.py create-project --project $PROJECT || exit 1
# Create global glossary for the project
python3 -u $SCRIPTSDIR/weblate_utils.py create-glossary --project $PROJECT || exit 1
# Create category with the branch name
python3 -u $SCRIPTSDIR/weblate_utils.py create-category --project $PROJECT --category $BRANCHNAME || exit 1
# Create components with the pot file for Weblate component initialization.
for component in ${COMPONENTS[@]}; do
    python3 -u $SCRIPTSDIR/weblate_utils.py create-component \
        --project $PROJECT \
        --category $BRANCHNAME \
        --component $component \
        --pot-path $HOME/workspace/projects/$PROJECT/pot/$component.pot || exit 1
done

for component in ${COMPONENTS[@]}; do
    translation_path_list=$(get_translation_path_list $component)

    for translation_path in $translation_path_list; do
        locale=$(extract_locale_from_path $translation_path)
        echo "[DEBUG] Creating translation, locale: $locale, component: $component"
        
        python3 -u $SCRIPTSDIR/weblate_utils.py create-translation \
            --project $PROJECT \
            --category $BRANCHNAME \
            --component $component \
            --locale $locale 
        sleep 10

        echo "[DEBUG] Check plural forms..."
        python3 $SCRIPTSDIR/plural.py $locale $translation_path

        echo "[DEBUG] Uploading PO file: $translation_path"
        python3 -u $SCRIPTSDIR/weblate_utils.py upload-po-file \
            --project $PROJECT \
            --category $BRANCHNAME \
            --component $component \
            --locale $locale \
            --po-path $translation_path
        
        # Verify the sentences.
        echo "[DEBUG] Checking accuracy..."
        python3 -u $SCRIPTSDIR/weblate_utils.py check-accuracy \
            --project $PROJECT \
            --category $BRANCHNAME \
            --component $component \
            --locale $locale \
            --po-path $translation_path

    done
done

endstage

# clean up 
rm -rf $HOME/workspace/projects/$PROJECT
