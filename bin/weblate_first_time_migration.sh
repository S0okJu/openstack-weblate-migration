#!/bin/bash

# Weblate one-time migration script: creates categories, components, and uploads source files and translations.
# weblate_first_time_migration.sh

# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#      http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

PROJECT=$1
BRANCHNAME=$2
# HORIZON_DIR is not used in this script

# Replace /'s in branch names with -'s because Weblate doesn't allow /'s in version names.
BRANCH_VERSION=${BRANCHNAME//\//-}

SCRIPTSDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPTSDIR/common_translation_update.sh"

init_branch "$BRANCHNAME"

if [ -z "$WEBLATE_TOKEN" ]; then
    echo "ERROR: WEBLATE_TOKEN environment variable is not set."
    echo "Please set it with: export WEBLATE_TOKEN=your_token_here"
    exit 1
fi

# --- BEGIN FUNCTION DEFINITIONS ---

# Replace all non [a-zA-Z0-9_-]/ with hyphens for slugs
function clean_slug() {
    echo "${1//[^a-zA-Z0-9_-]/-}"
}

# Helper function to get the double-URL-encoded component path for Weblate API
function get_weblate_encoded_component_path() {
    local branch_version="$1"
    local module_path="$2"
    local pot_filename="$3"
    local branch_slug
    branch_slug=$(echo "$branch_version" | tr '.' '-')
    local module_slug
    module_slug=$(echo "$module_path" | sed 's/[\/.]/-/g')
    local slug="$branch_slug/$module_slug/$pot_filename"
    # Replace "/" with "%252F"
    python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(urllib.parse.quote(sys.argv[1], safe=""), safe=""))' "$slug"
}

# Function to create (or get) a category
function get_or_create_weblate_category() {
    local project=$1
    local category_name=$2
    local parent_url=$3
    local category_slug
    category_slug=$(clean_slug "$category_name")

    # Build the query string
    local query="project=https://openstack.weblate.cloud/api/projects/$project/&slug=$category_slug"
    if [ -n "$parent_url" ]; then
        query="$query&category=$parent_url"
    fi

    # Check if category already exists
    categories_response=$(curl -s -H "Authorization: Token $WEBLATE_TOKEN" \
        "https://openstack.weblate.cloud/api/categories/?$query")

    existing_category_url=$(echo "$categories_response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for cat in data.get('results', []):
        if cat.get('slug') == '$category_slug' and cat.get('category') == '$parent_url':
            print(cat['url'])
            sys.exit(0)
except:
    pass
")

    if [ -n "$existing_category_url" ]; then
        echo "$existing_category_url"
        return 0
    fi

    # Create new category
    json_data="{\"name\": \"$category_name\", \"slug\": \"$category_slug\", \"project\": \"https://openstack.weblate.cloud/api/projects/$project/\""
    if [ -n "$parent_url" ]; then
        json_data="$json_data, \"category\": \"$parent_url\""
    fi
    json_data="$json_data}"

    response=$(curl -s -X POST -H "Authorization: Token $WEBLATE_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$json_data" \
        "https://openstack.weblate.cloud/api/categories/" \
        -o /tmp/category_response.json)

    category_url=$(grep -o '"url":"[^\"]*"' /tmp/category_response.json | grep -o 'https://[^\"]*' | head -1)

    if [ -n "$category_url" ]; then
        echo "$category_url"
        return 0
    else
        cat /tmp/category_response.json >&2
        return 1
    fi
}

# Function to check if a component exists in Weblate using curl
function component_exists_in_weblate() {
    local project=$1
    local pot_filename=$2
    local category_url=$3
    local module_path=$4  # module path (e.g., doc/source/locale/)
    local BRANCH_VERSION=$5  # branch/category
    local component_slug=$6  # cleaned slug
    # Get all components for the project
    components_response=$(curl -s -H "Authorization: Token $WEBLATE_TOKEN" \
        "https://openstack.weblate.cloud/api/projects/$project/components/")
    existing_component_url=$(echo "$components_response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for comp in data.get('results', []):
        if comp.get('slug') == '$component_slug':
            print(comp['url'])
            sys.exit(0)
except:
    pass
")
    if [ -n "$existing_component_url" ]; then
        return 0
    else
        return 1
    fi
}

# Function to create a component in Weblate
function create_weblate_component() {
    local project=$1
    local pot_filename=$2
    local pot_file=$3
    local category_url=$4
    local module_path=$5  # module path (e.g., doc/source/locale/)
    local BRANCH_VERSION=$6  # branch/category
    local component_slug=$7  # cleaned slug
    if [ ! -f "$pot_file" ]; then
        echo "ERROR: POT file $pot_file does not exist!"
        return 1
    fi
    local display_name="$pot_filename"
    
    # Create component and upload .pot file in the same request
    http_code=$(curl -s -o /tmp/component_response.json -w "%{http_code}" -X POST "https://openstack.weblate.cloud/api/projects/$project/components/" \
        -H "Authorization: Token $WEBLATE_TOKEN" \
        -H "Content-Type: multipart/form-data; charset=utf-8; boundary=__X_PAW_BOUNDARY__" \
        -F "name=$display_name" \
        -F "slug=$component_slug" \
        -F "filemask=*.pot" \
        -F "file_format=po-mono" \
        -F "repo=local:" \
        -F "vcs=local" \
        -F "new_lang=add" \
        -F "new_base=$pot_filename.pot" \
        -F "docfile=@$pot_file" \
        ${category_url:+-F "category=$category_url"})
    # Check if component was created successfully or already exists
    if [ "$http_code" = "201" ] || [ "$http_code" = "200" ] || grep -q '"id":' /tmp/component_response.json; then
        # log errors
            return 0
    else
        echo "ERROR: Failed to create component $pot_filename (slug: $component_slug). Response:" >&2
        cat /tmp/component_response.json >&2
        return 1
    fi
}

# Function to upload a POT file to an existing component (update source)
function upload_pot_to_component() {
    local project=$1
    local pot_filename=$2
    local pot_file=$3
    local category_url=$4
    local module_path=$5  # module path (e.g., doc/source/locale/)
    local BRANCH_VERSION=$6  # branch/category
    local component_slug=$7  # cleaned slug
    if [ ! -f "$pot_file" ]; then
        echo "ERROR: POT file $pot_file does not exist!"
        return 1
    fi
    components_response=$(curl -s -H "Authorization: Token $WEBLATE_TOKEN" \
        "https://openstack.weblate.cloud/api/projects/$project/components/")
    component_url=$(echo "$components_response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for comp in data.get('results', []):
        if comp.get('slug') == '$component_slug':
            print(comp['url'] + 'repository/')
            sys.exit(0)
except:
    pass
")
    if [ -z "$component_url" ]; then
        echo "ERROR: Component $pot_filename with slug $component_slug not found in project $project" >&2
        return 1
    fi
    response=$(curl -s -w "%{http_code}" -X POST "$component_url" \
        -H "Authorization: Token $WEBLATE_TOKEN" \
        -F "operation=push" \
        -F "file=@$pot_file" \
        -o /tmp/upload_response.json)
    http_code="${response: -3}"
    if [ "$http_code" != "200" ] && [ "$http_code" != "201" ]; then
        echo "ERROR: Failed to upload POT file. Response:" >&2
        cat /tmp/upload_response.json >&2
        return 1
    else
        echo "Successfully uploaded POT file to component $pot_filename (slug $component_slug)" >&2
        return 0
    fi
}

# Function to upload PO files for languages to a component
function upload_po_files_to_component() {
    local project=$1
    local pot_filename=$2
    local module_path=$3  # module path (e.g., doc/source/locale/)
    local BRANCH_VERSION=$4  # branch/category
    local component_slug=$5  # cleaned slug
    
    # Find all .po files in the module directory
    po_files=$(find "$module_path" -name "*.po" 2>/dev/null || echo "")
    if [ -z "$po_files" ]; then
        echo "No PO files found in $module_path for component $pot_filename"
        return 0
    fi
    
    for po_file in $po_files; do
        lang_code=$(echo "$po_file" | sed -n 's/.*\/\([^\/]*\)\/LC_MESSAGES\/.*\.po$/\1/p')
        if [ -z "$lang_code" ]; then
            lang_code=$(echo "$po_file" | sed -n 's/.*\/\([^\/]*\)\.po$/\1/p')
        fi
        if [ -z "$lang_code" ]; then
            echo "WARNING: Could not extract language code from $po_file, skipping"
            continue
        fi
        if [ "$lang_code" = "zh_CN" ]; then
            lang_code="zh_Hans"
        elif [ "$lang_code" = "zh_TW" ]; then
            lang_code="zh_Hant"
        fi
        orig_lang_code="$lang_code"
        fallback_lang_code=""
        lang_enable_success=0
        echo "Uploading PO file $po_file (language: $lang_code) to component $pot_filename..."
        echo "Ensuring language $lang_code is enabled for $project/$component_slug via API..."
        encoded_component_path=$(get_weblate_encoded_component_path "$BRANCH_VERSION" "$module_path" "$component_slug")
        echo "POSTing to: https://openstack.weblate.cloud/api/components/$project/$encoded_component_path/translations/"
        add_lang_response=$(curl -s -o /tmp/add_lang_response.json -w "%{http_code}" -X POST \
            -H "Authorization: Token $WEBLATE_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"language_code\": \"$lang_code\"}" \
            "https://openstack.weblate.cloud/api/components/$project/$encoded_component_path/translations/")
        if [ "$add_lang_response" = "201" ] || [ "$add_lang_response" = "200" ]; then
            echo "[OK] Language $lang_code enabled for $project/$encoded_component_path."
            lang_enable_success=1
        elif [ "$add_lang_response" = "400" ]; then
            if grep -q "already exists" /tmp/add_lang_response.json; then
                echo "[OK] Language $lang_code already exists for $project/$encoded_component_path."
                lang_enable_success=1
            elif grep -q "No language code" /tmp/add_lang_response.json; then
                if [[ "$orig_lang_code" != "zh_Hans" && "$orig_lang_code" != "zh_Hant" && "$orig_lang_code" == *_* ]]; then
                    fallback_lang_code="${orig_lang_code%%_*}"
                    echo "[INFO] Retrying with fallback language code: $fallback_lang_code"
                    add_lang_response_fallback=$(curl -s -o /tmp/add_lang_response_fallback.json -w "%{http_code}" -X POST \
                        -H "Authorization: Token $WEBLATE_TOKEN" \
                        -H "Content-Type: application/json" \
                        -d "{\"language_code\": \"$fallback_lang_code\"}" \
                        "https://openstack.weblate.cloud/api/components/$project/$encoded_component_path/translations/")
                    if [ "$add_lang_response_fallback" = "201" ] || [ "$add_lang_response_fallback" = "200" ]; then
                        echo "[OK] Language $fallback_lang_code enabled for $project/$encoded_component_path (fallback for $orig_lang_code)."
                        lang_enable_success=1
                        LANG_ENABLE_FALLBACK+=("$orig_lang_code → $fallback_lang_code")
                    elif grep -q "already exists" /tmp/add_lang_response_fallback.json; then
                        echo "[OK] Language $fallback_lang_code already exists for $project/$encoded_component_path (fallback for $orig_lang_code)."
                        lang_enable_success=1
                        LANG_ENABLE_FALLBACK+=("$orig_lang_code → $fallback_lang_code")
                    else
                        echo "[FAIL] Fallback language $fallback_lang_code also failed. Response:"
                        cat /tmp/add_lang_response_fallback.json
                        LANG_ENABLE_FAILED+=("$orig_lang_code (fallback $fallback_lang_code failed)")
                    fi
                else
                    echo "[FAIL] Language $orig_lang_code could not be enabled. Response:"
                    cat /tmp/add_lang_response.json
                    LANG_ENABLE_FAILED+=("$orig_lang_code")
                fi
            else
                echo "[FAIL] Language $orig_lang_code could not be enabled. Response:"
                cat /tmp/add_lang_response.json
                LANG_ENABLE_FAILED+=("$orig_lang_code")
            fi
        else
            echo "[INFO] Language $lang_code may already be enabled or could not be enabled (HTTP $add_lang_response). Response:"
            cat /tmp/add_lang_response.json
        fi
        upload_lang_code="$lang_code"
        if [ "$lang_enable_success" -eq 1 ] && [ -n "$fallback_lang_code" ]; then
            upload_lang_code="$fallback_lang_code"
        fi
        upload_url="https://openstack.weblate.cloud/api/translations/$project/$encoded_component_path/$upload_lang_code/file/"
        echo "Uploading PO file via API: $upload_url"
        echo "Local PO file: $po_file"
        max_upload_retries=3
        upload_attempt=1
        upload_success=0
        while [ $upload_attempt -le $max_upload_retries ]; do
            upload_response=$(curl -s -w "%{http_code}" -X POST \
                -F file=@"$po_file" \
                -F method=replace \
                -H "Authorization: Token $WEBLATE_TOKEN" \
                "$upload_url" \
                -o /tmp/upload_response.json)
            http_code="${upload_response: -3}"
            response_body=$(cat /tmp/upload_response.json)
            if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
                # Check if accepted == total
                accepted=$(echo "$response_body" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('accepted', -1)) if 'accepted' in d else print(-1)")
                total=$(echo "$response_body" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('total', -1)) if 'total' in d else print(-1)")
                if [ "$accepted" = "$total" ] && [ "$accepted" != "-1" ]; then
                    echo "[OK] Successfully uploaded PO file for language $upload_lang_code to component $component_slug via API (attempt $upload_attempt)"
                    upload_success=1
                    PO_UPLOAD_SUCCEEDED+=("$component_slug:$upload_lang_code:$po_file:$accepted/$total")
                    break
                else
                    echo "[FAIL] PO file upload for $component_slug:$upload_lang_code succeeded but accepted ($accepted) != total ($total) (attempt $upload_attempt)"
                    PO_UPLOAD_FAILED+=("$component_slug:$upload_lang_code:$po_file:accepted $accepted/total $total: $response_body")
                fi
            else
                if [ $upload_attempt -lt $max_upload_retries ]; then
                    echo "[RETRY] Failed to upload PO file for language $upload_lang_code to component $component_slug via API (HTTP $http_code, attempt $upload_attempt). Retrying..."
                    sleep 2
                fi
            fi
            upload_attempt=$((upload_attempt+1))
        done
        if [ $upload_success -eq 0 ]; then
            echo "[FAIL] Failed to upload PO file for language $upload_lang_code to component $component_slug via API after $max_upload_retries attempts (last HTTP $http_code)"
            echo "Response: $response_body"
            echo "To reproduce, run:"
            echo "curl -X POST -F file=@\"$po_file\" -F method=replace -H 'Authorization: Token $WEBLATE_TOKEN' '$upload_url'"
            PO_UPLOAD_FAILED+=("$component_slug:$upload_lang_code:$po_file:HTTP $http_code: $response_body")
            PO_UPLOAD_RECREATE_CMDS+=("curl -X POST -F file=@\"$po_file\" -F method=replace -H 'Authorization: Token $WEBLATE_TOKEN' '$upload_url'  # $component_slug $upload_lang_code")
        fi
    done
    return 0
}

# --- END FUNCTION DEFINITIONS ---

# Extraction logic
ALL_MODULES=""
setup_venv
setup_git

# Project setup and updating POT files.
case "$PROJECT" in
    api-site|openstack-manuals|security-doc)
        init_manuals "$PROJECT"
        setup_manuals "$PROJECT" "$BRANCHNAME"
        case "$PROJECT" in
            api-site)
                ALL_MODULES="api-quick-start firstapp"
                ;;
            security-doc)
                ALL_MODULES="security-guide"
                ;;
            *)
                ALL_MODULES="doc"
                ;;
        esac
        ;;
    training-guides)
        setup_training_guides "$BRANCHNAME"
        ALL_MODULES="doc"
        ;;
    i18n)
        setup_i18n "$BRANCHNAME"
        ALL_MODULES="doc"
        ;;
    tripleo-ui)
        setup_reactjs_project "$PROJECT" "$BRANCHNAME"
        ALL_MODULES="i18n"
        ;;
    *)
        module_names=$(get_modulename "$PROJECT" python)
        if [ -n "$module_names" ]; then
            for modulename in $module_names; do
                extract_messages_python "$modulename"
                ALL_MODULES="$modulename $ALL_MODULES"
            done
        fi
        module_names=$(get_modulename "$PROJECT" django)
        if [ -n "$module_names" ]; then
            install_horizon
            for modulename in $module_names; do
                extract_messages_django "$modulename"
                ALL_MODULES="$modulename $ALL_MODULES"
            done
        fi
        if [[ -f doc/source/conf.py ]]; then
            if [[ ${DOC_TARGETS[*]} =~ $PROJECT ]]; then
                extract_messages_doc
                ALL_MODULES="doc $ALL_MODULES"
            fi
        fi
        ;;
esac

if [[ "$BRANCHNAME" == "master" && -f releasenotes/source/conf.py ]]; then
    extract_messages_releasenotes
    ALL_MODULES="releasenotes $ALL_MODULES"
fi

echo "ALL_MODULES for $BRANCHNAME: $ALL_MODULES"

# Migration logic: create categories/components if they do not exist
# Clean up name as Weblate does not allow '.' in the name
SAFE_BRANCH_VERSION=$(echo "$BRANCH_VERSION" | tr '.' '-')
if ! branch_category_url=$(get_or_create_weblate_category "$PROJECT" "$SAFE_BRANCH_VERSION" ""); then
    echo "ERROR: Could not create/get branch category $SAFE_BRANCH_VERSION"
    exit 1
fi

components_attempted=0
components_succeeded=0

for m in $ALL_MODULES; do
    echo "Processing module: $m"
    # For each .pot file in the module, use its directory as the second category
    pot_files=$(find "$m" -type f -name "*.pot" 2>/dev/null || echo "")
    echo "Found POT files for $m: $pot_files"
    if [ -z "$pot_files" ]; then
        echo "No POT files found in module $m"
        continue
    fi
    for pot in $pot_files; do
        pot_filename=$(basename "$pot" .pot)
        pot_dir=$(dirname "$pot")
        module_path_category="$pot_dir"
        module_path_slug=$(clean_slug "$module_path_category")
        # Create/get the module path category under the branch category
        if ! module_path_category_url=$(get_or_create_weblate_category "$PROJECT" "$module_path_category" "$branch_category_url"); then
            echo "ERROR: Could not create/get module path category $module_path_category under $SAFE_BRANCH_VERSION"
            continue
        fi
        component_slug="${SAFE_BRANCH_VERSION}-${module_path_slug}-$(clean_slug "$pot_filename")"
        echo "[DEBUG] Considering $pot for component creation (module path: $module_path_category, pot_filename: $pot_filename, slug: $component_slug)"
        components_attempted=$((components_attempted+1))
        if ! component_exists_in_weblate "$PROJECT" "$pot_filename" "$module_path_category_url" "$module_path_category" "$SAFE_BRANCH_VERSION" "$component_slug"; then
            echo "Creating component $pot_filename in Weblate under $module_path_category..."
            if create_weblate_component "$PROJECT" "$pot_filename" "$pot" "$module_path_category_url" "$module_path_category" "$SAFE_BRANCH_VERSION" "$component_slug"; then
                components_succeeded=$((components_succeeded+1))
                # Upload PO files for languages
                echo "Uploading PO files for languages to component $pot_filename..."
                upload_po_files_to_component "$PROJECT" "$pot_filename" "$module_path_category" "$SAFE_BRANCH_VERSION" "$component_slug"
            else
                echo "ERROR: Failed to create component $pot_filename in $module_path_category."
            fi
        else
            echo "Component $pot_filename already exists, skipping creation."
            components_succeeded=$((components_succeeded+1))
            # Upload PO files for languages even for existing components
            echo "Uploading PO files for languages to existing component $pot_filename..."
            upload_po_files_to_component "$PROJECT" "$pot_filename" "$module_path_category" "$SAFE_BRANCH_VERSION" "$component_slug"
        fi
    done

done

echo "$components_succeeded/$components_attempted component creation attempts succeeded."
echo "Weblate migration complete." 

# At the end of the script, print the summary

echo

echo "==== Language Enable Summary ===="
if [ ${#LANG_ENABLE_FAILED[@]} -gt 0 ]; then
    echo "Languages that failed to enable:"
    for lang in "${LANG_ENABLE_FAILED[@]}"; do
        echo "  - $lang"
    done
else
    echo "All languages enabled successfully."
fi
if [ ${#LANG_ENABLE_FALLBACK[@]} -gt 0 ]; then
    echo "Languages that succeeded after fallback:"
    # Print only unique fallback pairs
    printf '%s\n' "${LANG_ENABLE_FALLBACK[@]}" | sort -u | while read -r lang; do
        echo "  - $lang"
    done
fi

echo "==== PO Upload Summary ===="
if [ ${#PO_UPLOAD_FAILED[@]} -gt 0 ]; then
    echo "PO uploads that failed or were incomplete (accepted != total):"
    for fail in "${PO_UPLOAD_FAILED[@]}"; do
        echo "  - $fail"
    done
else
    echo "All PO files uploaded successfully and completely."
fi
total_po_attempts=$(( ${#PO_UPLOAD_SUCCEEDED[@]} + ${#PO_UPLOAD_FAILED[@]} ))
echo "PO uploads succeeded: ${#PO_UPLOAD_SUCCEEDED[@]} / $total_po_attempts"
if [ ${#PO_UPLOAD_RECREATE_CMDS[@]} -gt 0 ]; then
    echo "==== Recreate Failed PO Uploads ===="
    echo "To manually retry the failed uploads, run the following commands:"
    for cmd in "${PO_UPLOAD_RECREATE_CMDS[@]}"; do
        echo "  $cmd"
    done
fi
echo "==================================" 

# === Retry Failed PO Uploads ===
if [ ${#PO_UPLOAD_RECREATE_CMDS[@]} -gt 0 ]; then
    echo "Retrying failed PO uploads..."
    new_failed=()
    new_succeeded=()
    for idx in "${!PO_UPLOAD_RECREATE_CMDS[@]}"; do
        cmd="${PO_UPLOAD_RECREATE_CMDS[$idx]}"
        fail_entry="${PO_UPLOAD_FAILED[$idx]}"
        # Extract component and language info from the comment
        component_lang=${cmd##*# }
        echo "Retrying: $component_lang"
        response=$(eval "$cmd" 2>&1)
        # Check for success (look for '"result":true' in response)
        if echo "$response" | grep -q '"result":true'; then
            echo "[SUCCESS] Retry succeeded for $component_lang"
            new_succeeded+=("$fail_entry")
        else
            echo "[FAILED] Retry failed for $component_lang"
            echo "Response: $response"
            new_failed+=("$fail_entry")
        fi
    done
    # Update arrays
    PO_UPLOAD_SUCCEEDED+=("${new_succeeded[@]}")
    PO_UPLOAD_FAILED=("${new_failed[@]}")
else
    echo "No failed uploads to retry."
fi

echo "==================================" 

# === Overall Summary ===
echo "==== Overall Migration Summary ===="
echo "Components succeeded: $components_succeeded / $components_attempted"
echo "PO uploads succeeded: ${#PO_UPLOAD_SUCCEEDED[@]} / $total_po_attempts"
echo "==================================" 

for m in $ALL_MODULES; do
    cleanup_po_files "$m"
    cleanup_pot_files "$m"
done 