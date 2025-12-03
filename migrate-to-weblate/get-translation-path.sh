#!/bin/bash
# Create and setup the Weblate components.

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

function get_pot_path {
    local component=$1
    local module_name=""

    case $component in
        "releasenotes")
            echo "$HOME/workspace/projects/$PROJECT/pot/releasenotes/source/locale/releasenotes.pot"
            ;;
        "django")
            echo "$HOME/workspace/projects/$PROJECT/pot/$PROJECT/locale/django.pot"
            ;;
        "djangojs")
            echo "$HOME/workspace/projects/$PROJECT/pot/$PROJECT/locale/djangojs.pot"
            ;;
        *-django)
            # openstack-auth-django -> openstack_auth/locale/django.pot
            module_name="${component%-django}"
            module_name="${module_name//-/_}"
            echo "$HOME/workspace/projects/$PROJECT/pot/$module_name/locale/django.pot"
            ;;
        *-djangojs)
            # openstack-auth-djangojs -> openstack_auth/locale/djangojs.pot
            module_name="${component%-djangojs}"
            module_name="${module_name//-/_}"
            echo "$HOME/workspace/projects/$PROJECT/pot/$module_name/locale/djangojs.pot"
            ;;
        "doc"|doc-*)
            echo "$HOME/workspace/projects/$PROJECT/pot/doc/source/locale/$component.pot"
            ;;
        *)
            echo "$HOME/workspace/projects/$PROJECT/pot/$PROJECT/locale/$component.pot"
            ;;
    esac
}

function get_po_path {
    local component=$1
    local locale=$2

    case $component in
        "releasenotes")
            echo "$HOME/workspace/projects/$PROJECT/translations/releasenotes/source/locale/$locale/LC_MESSAGES/releasenotes.po"
            ;;
        "django")
            echo "$HOME/workspace/projects/$PROJECT/translations/$PROJECT/locale/$locale/LC_MESSAGES/django.po"
            ;;
        "djangojs")
            echo "$HOME/workspace/projects/$PROJECT/translations/$PROJECT/locale/$locale/LC_MESSAGES/djangojs.po"
            ;;
        *-django)
            # openstack-auth-django -> openstack_auth/locale/django.pot
            module_name="${component%-django}"
            module_name="${module_name//-/_}"
            echo "$HOME/workspace/projects/$PROJECT/translations/$module_name/locale/$locale/LC_MESSAGES/django.po"
            ;;
        *-djangojs)
            # openstack-auth-djangojs -> openstack_auth/locale/djangojs.pot
            module_name="${component%-djangojs}"
            module_name="${module_name//-/_}"
            echo "$HOME/workspace/projects/$PROJECT/translations/$module_name/locale/$locale/LC_MESSAGES/djangojs.po"
            ;;
        "doc"|doc-*)
            echo "$HOME/workspace/projects/$PROJECT/translations/doc/source/locale/$locale/LC_MESSAGES/$component.po"
            ;;
        *)
            echo "$HOME/workspace/projects/$PROJECT/translations/$PROJECT/locale/$locale/LC_MESSAGES/$component.po"
            ;;
    esac
}


function sanitize_django_component {
    local component=$1
    
    if [[ "$component" == *"-django" ]]; then
        echo "django"
    elif [[ "$component" == *"-djangojs" ]]; then
        echo "djangojs"
    else
        echo "$component"
    fi
}

function get_module_name_from_component {
    local component=$1
    
    if [[ "$component" == *"-django" || "$component" == *"-djangojs" ]]; then
        # Extract module name from component (e.g., "horizon-django" -> "horizon")
        echo "${component%-django*}" | sed 's/-/_/g'
    else
        echo "$component"
    fi
}

function extract_locale_from_path {
    local translation_path=$1
    
    echo "$translation_path" | sed 's|.*/locale/\([^/]*\)/LC_MESSAGES/.*|\1|'
}

function get_po_file_path() {
    local component=$1
    local locale_file=$2
    local django_module_name=$3
    
    # Extract locale name from the full path
    # For paths like /path/to/locale/de/LC_MESSAGES/file.po, extract "de"
    local locale_name=$(echo "$locale_file" | sed 's|.*/locale/\([^/]*\)/LC_MESSAGES/.*|\1|')

    case $component in
        doc*)
            path="${TARGET_PROJECT_DIR}/translations/doc/source/locale/${locale_name}/LC_MESSAGES/${component}.po"
            echo "Doc PO path: $path" >&2
            echo "$path"
            ;;
        "*django"|"*djangojs"|"django"|"djangojs")
            # Django projects: use actual module name
            sanitized_component=$(sanitize_django_component $component)
            if [ -n "$django_module_name" ]; then
                path="${TARGET_PROJECT_DIR}/translations/${django_module_name}/locale/${locale_name}/LC_MESSAGES/${sanitized_component}.po"
                echo "Django PO path with module name: $path" >&2
                echo "$path"
            else
                path="${TARGET_PROJECT_DIR}/translations/${project_package_name}/locale/${locale_name}/LC_MESSAGES/${sanitized_component}.po"
                echo "Django PO path with package name: $path" >&2
                echo "$path"
            fi
            ;;
        "${PROJECT}")
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

function get_translation_path_list() {
    local component=$1
    local target_project_dir="$HOME/workspace/projects/$PROJECT/translations"
    
    if [[ "$component" == "releasenotes" ]]; then
        # Special handling for releasenotes
        locale_list=($(find ${target_project_dir}/releasenotes -name "*.po" -path "*/locale/*/LC_MESSAGES/*.po" 2>/dev/null || echo ""))
    elif [[ "$component" == *"-django" || "$component" == *"-djangojs" ]]; then
        # Django components are saved as django.pot, djangojs.pot
        sanitized_component=$(sanitize_django_component $component)
        # Get the correct module name for this component
        correct_module_name=$(get_module_name_from_component $component)
        locale_list=($(find ${target_project_dir}/${correct_module_name} -name "*.po" -path "*/locale/*/LC_MESSAGES/${sanitized_component}.po" 2>/dev/null || echo ""))
    else
        locale_list=($(find ${target_project_dir} -name "*.po" -path "*/locale/*/LC_MESSAGES/${component}.po" 2>/dev/null || echo ""))
    fi

    echo "${locale_list[@]}"
}