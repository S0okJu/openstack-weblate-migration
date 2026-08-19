source $SCRIPTSDIR/common/get_translation_path.sh

TEST_DIR=$HOME/$WORKSPACE_NAME/projects/$PROJECT/test
RESULT_JSON=$HOME/$WORKSPACE_NAME/projects/$PROJECT/result.jsonl

function test_accuracy {

    if [ ! -d "$TEST_DIR" ]; then
        echo "[INFO] TEST_DIR does not exist. Create new one."
        mkdir -p $TEST_DIR
    fi

    cd $TEST_DIR
    # Download translation file from Weblate
    python3 -u $SCRIPTSDIR/common/weblate_utils.py download-translation-file \
        --project $PROJECT \
        --po-path $TEST_DIR/$PROJECT.zip
    unzip -o $PROJECT.zip
    rm -f $PROJECT.zip
    
    for component in "${COMPONENTS[@]}"; do
        echo ""
        echo "============================================================"
        echo " Target: $PROJECT / $ZANATA_VERSION / $component"
        echo "============================================================"
        
        # Get translation path list as an array
        local translation_path_array=($(get_translation_path_list $component))
        
        for translation_path in "${translation_path_array[@]}"; do
            local locale=$(extract_locale_from_path $translation_path)
            echo ""
            echo "[INFO] Testing locale: $locale"
            
            # the directory name did not support .,
            # so we need to replace . with -
            local version_dir=${ZANATA_VERSION//./-}
            local weblate_po_path=$(get_po_path $component $locale $TEST_DIR/$PROJECT/$version_dir true)

            echo "[INFO] Step 1/3: Check the component/locale existence..."
            if ! python3 -u $SCRIPTSDIR/common/weblate_utils.py check-translation-existence \
                --project $PROJECT \
                --category $ZANATA_VERSION \
                --component $component \
                --locale $locale \
                --zanata-po-path $translation_path \
                --weblate-po-path $weblate_po_path \
                --result-json $RESULT_JSON
            then
                echo "[ERROR] Component/locale does not exist: $PROJECT, $ZANATA_VERSION, $component, $locale, $translation_path"
                exit 1
            fi

            echo "[INFO] Step 2/3: Check the sentence count..."
            if ! python3 -u $SCRIPTSDIR/common/weblate_utils.py check-sentence-count \
                --project $PROJECT \
                --category $ZANATA_VERSION \
                --component $component \
                --locale $locale \
                --zanata-po-path $translation_path \
                --weblate-po-path $weblate_po_path \
                --result-json $RESULT_JSON
            then
                echo "[ERROR] Check the sentence failed: $PROJECT, $ZANATA_VERSION, $component, $locale, $translation_path"
                exit 1
            fi

            echo "[INFO] Step 3/3: Check the sentence detail..."
            if ! python3 -u $SCRIPTSDIR/common/weblate_utils.py check-sentence-detail \
                --project $PROJECT \
                --category $ZANATA_VERSION \
                --component $component \
                --locale $locale \
                --zanata-po-path $translation_path \
                --weblate-po-path $weblate_po_path \
                --result-json $RESULT_JSON
            then
                echo "[ERROR] Check the sentence detail failed: $PROJECT, $ZANATA_VERSION, $component, $locale, $translation_path"
                exit 1
            fi

        done
        echo "[INFO] ✓ Component '$component' completed - tested ${#translation_path_array[@]} locales"
    done

    echo ""

    cd - > /dev/null
}