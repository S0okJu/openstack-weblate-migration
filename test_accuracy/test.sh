source $SCRIPTSDIR/common/get_translation_path.sh

TEST_DIR=$HOME/$WORKSPACE_NAME/projects/$PROJECT/test

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
        # Get translation path list as an array
        local translation_path_array=($(get_translation_path_list $component))
        for translation_path in "${translation_path_array[@]}"; do
            local locale=$(extract_locale_from_path $translation_path)
            echo "[INFO] Testing accuracy for locale: $locale"
            
            echo "[INFO] Check the sentence..."
            if ! python3 -u $SCRIPTSDIR/common/weblate_utils.py check-sentence-count \
                --zanata-po-path $translation_path \
                --weblate-po-path $(get_po_path $component $locale $TEST_DIR/$PROJECT/$ZANATA_VERSION)
            then
                echo "[ERROR] Check the sentence failed: $PROJECT, $ZANATA_VERSION, $component, $locale, $translation_path"
                exit 1
            fi

            echo "[INFO] Check the sentence detail..."
            python3 -u $SCRIPTSDIR/common/weblate_utils.py check-sentence-detail \
                --zanata-po-path $translation_path \
                --weblate-po-path $(get_po_path $component $locale $TEST_DIR/$PROJECT/$ZANATA_VERSION)
            
        done
    done

    cd - > /dev/null
}