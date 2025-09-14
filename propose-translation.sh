#!/bin/bash -xe

# Did not check percentage of translations
function pull_from_zanata {

    zanata-cli -B -e pull
}

# Propose updates for manuals
function propose_manuals {

    # Pull updated translations from Zanata.
    pull_from_zanata "$project_name"

}

# Propose updates for training-guides
function propose_training_guides {

    # Pull updated translations from Zanata.
    pull_from_zanata "$PROJECT"

}

# Propose updates for i18n
function propose_i18n {

    # Pull updated translations from Zanata.
    pull_from_zanata "$PROJECT"
}

# Propose updates for python and django projects
function propose_python_django {
    local modulename=$1
    local version=$2

    # Check for empty directory and exit early
    local content

    content=$(ls -A $modulename/locale/)

    if [[ "$content" == "" ]] ; then
        return
    fi

}


# Handle either python or django proposals
function handle_python_django_project {
    local project=$1

    setup_project "$project" "$ZANATA_VERSION"
    pull_from_zanata "$project"
    rename_django_chinese_locales "$project" "$BRANCH"
    handle_python_django $project python
    handle_python_django $project django
    handle_project_doc $project
}

# Handle project doc proposals
function handle_project_doc {
    local project=$1
    # Doing only things in the test repos for project doc translation
    if ! [[ ${DOC_TARGETS[*]} =~ "$project" ]]; then
        return
    fi
    # setup_project and pull_from_zanata are already done
    # we start directly with generating .pot files
    extract_messages_doc

}

# Rename existing Chinese locales in the project repository
# (zh_CN -> zh_Hans, zh_TW -> zh_Hant)
# NOTE: This is expected to call after pulling translations from zanata.
function rename_django_chinese_locales {
    local project=$1
    local branch=$2
    local module_name module_names
    local old_locale new_locale

    # Renaming Chinese locales is unnecessary for Victoria or earlier.
    # TODO(amotoki): Once all stable branches support the new Chinese locales
    # in horizon and its plugins, this branch check can be dropped.
    case "$branch" in
        stable/ussuri|stable/victoria) return ;;
        *) ;;
    esac

    declare -A locale_rename_map=(
        ["zh_CN"]="zh_Hans"
        ["zh_TW"]="zh_Hant"
    )

    module_names=$(get_modulename $project django)
    for module_name in $module_names; do
        for old_locale in "${!locale_rename_map[@]}"; do
            new_locale=${locale_rename_map[$old_locale]}
            rm -rf $module_name/locale/$new_locale
            if [ -d $module_name/locale/$old_locale ]; then
                mv $module_name/locale/$old_locale $module_name/locale/$new_locale
            fi
            if git ls-files | grep -q $module_name/locale/$old_locale; then
                git rm -r $module_name/locale/$old_locale
            fi
        done
    done
}


# Handle either python or django proposals
function handle_python_django {
    local project=$1
    # kind can be "python" or "django"
    local kind=$2
    local module_names

    module_names=$(get_modulename $project $kind)
    if [ -n "$module_names" ]; then
        if [[ "$kind" == "django" ]] ; then
            install_horizon
        fi
        propose_releasenotes "$ZANATA_VERSION"
        for modulename in $module_names; do
            # Note that we need to generate the pot files so that we
            # can calculate how many strings are translated.
            case "$kind" in
                django)
                    # Update the .pot file
                    extract_messages_django "$modulename"
                    ;;
                python)
                    # Extract messages from project except log messages
                    extract_messages_python "$modulename"
                    ;;
            esac
            propose_python_django "$modulename" "$ZANATA_VERSION"
        done
    fi
}


function propose_releasenotes {
    local version=$1

    # This function does not check whether releasenote publishing and
    # testing are set up in zuul/layout.yaml. If releasenotes exist,
    # they get pushed to the translation server.

    # Note that releasenotes only get translated on master.
    if [[ "$version" == "master" && -f releasenotes/source/conf.py ]]; then

        # Note that we need to generate these so that we can calculate
        # how many strings are translated.
        extract_messages_releasenotes "keep_workdir"

        local lang_po
        local locale_dir=releasenotes/source/locale
        for lang_po in $(find $locale_dir -name 'releasenotes.po'); do
            check_releasenotes_per_language $lang_po
        done

        # Remove the working directory. We no longer needs it.
        rm -rf releasenotes/work

        # Cleanup POT files.
        # PO files are already clean up in check_releasenotes_translations.
        cleanup_pot_files "releasenotes"

        # Compress downloaded po files, this needs to be done after
        # cleanup_po_files since that function needs to have information the
        # number of untranslated strings.
        compress_po_files "releasenotes"

    fi

    # Remove any releasenotes translations from stable branches, they
    # are not needed there.
    if [[ "$version" != "master" && -d releasenotes/source/locale ]]; then
        # Note that content might exist, e.g. from downloaded translations,
        # but are not under git control.
        git rm --ignore-unmatch -rf releasenotes/source/locale
    fi
}


function propose_reactjs {
    pull_from_zanata "$PROJECT"

    # Clean up files (removes incomplete translations and untranslated strings)
    # cleanup_module "i18n"

    # Convert po files to ReactJS i18n JSON format
    for lang in `find i18n/*.po -printf "%f\n" | sed 's/\.po$//'`; do
        npm run po2json -- ./i18n/$lang.po -o ./i18n/$lang.json
        # The files are created as a one-line JSON file - expand them
        python -m json.tool ./i18n/$lang.json ./i18n/locales/$lang.json
        rm ./i18n/$lang.json
    done

}
