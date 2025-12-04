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

source $SCRIPTSDIR/migrate_to_weblate/get_translation_path.sh

function create_weblate_components {
    
    cd $SCRIPTSDIR
    WORKSPACE_DIR=$HOME/workspace/projects/$PROJECT/$WORKSPACE_NAME/test
    mkdir -p $WORKSPACE_DIR

    # Create project
    python3 -u $SCRIPTSDIR/common/weblate_utils.py create-project --project $PROJECT || exit 1
    # Create global glossary for the project
    python3 -u $SCRIPTSDIR/common/weblate_utils.py create-glossary --project $PROJECT || exit 1
    # Create category with the branch name
    python3 -u $SCRIPTSDIR/common/weblate_utils.py create-category --project $PROJECT --category $ZANATA_VERSION || exit 1
    # Create components with the pot file for Weblate component initialization.
    for component in ${COMPONENTS[@]}; do
        pot_path=$(get_pot_path $component)

        python3 -u $SCRIPTSDIR/common/weblate_utils.py create-component \
            --project $PROJECT \
            --category $ZANATA_VERSION \
            --component $component \
            --pot-path $pot_path || exit 1
    done

    for component in ${COMPONENTS[@]}; do
        translation_path_list=$(get_translation_path_list $component)

        for translation_path in $translation_path_list; do
            locale=$(extract_locale_from_path $translation_path)
            echo "[INFO] Creating translation, locale: $locale, component: $component"

            python3 -u $SCRIPTSDIR/common/weblate_utils.py create-translation \
                --project $PROJECT \
                --category $ZANATA_VERSION \
                --component $component \
                --locale $locale 
            sleep 10

            echo "[INFO] Check plural forms..."
            python3 -u $SCRIPTSDIR/migrate-to-weblate/lang_plural_check.py $translation_path

            echo "[INFO] Uploading PO filse: $translation_path"
            python3 -u $SCRIPTSDIR/common/weblate_utils.py upload-po-file \
                --project $PROJECT \
                --category $ZANATA_VERSION \
                --component $component \
                --locale $locale \
                --po-path $translation_path
            
            echo "[INFO] Check the sentence..."
            if ! python3 -u $SCRIPTSDIR/common/weblate_utils.py check-sentence-count \
                --project $PROJECT \
                --category $ZANATA_VERSION \
                --component $component \
                --locale $locale \
                --po-path $translation_path
            then
                echo "[ERROR] Check the sentence failed: $PROJECT, $ZANATA_VERSION, $component, $locale, $translation_path"
                exit 1
            fi

            echo "[INFO] Check the sentence detail..."
            mkdir -p $WORKSPACE_DIR/$component/$locale
            python3 -u $SCRIPTSDIR/common/weblate_utils.py check-sentence-detail \
                --project $PROJECT \
                --category $ZANATA_VERSION \
                --component $component \
                --locale $locale \
                --po-path $translation_path \
                --workspace-path "$WORKSPACE_DIR/$component/$locale.po" || exit 1
            
        done

    done

}
