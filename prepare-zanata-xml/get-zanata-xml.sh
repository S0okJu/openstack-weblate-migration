#!/bin/bash
# Get zanata.xml from project repository

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

WORK_DIR="$HOME/$WORKSPACE_NAME"

function clone_project() {
    local project=$1
    local version=$2

    if [ ! -d "$WORK_DIR/projects/$project" ]; then
        git clone https://opendev.org/openstack/$project $WORK_DIR/projects/$project
    fi

    # Even if the project is already cloned,
    # we need to checkout the version.
    cd $WORK_DIR/projects/$project
    if [ "$version" != "master" ]; then
        if ! git checkout $version; then
            echo "[ERROR] Failed to checkout $version version"
            return 1
        fi
    fi
    echo "[INFO] $project: Checked out $version version"
    cd - > /dev/null

    return 0
}

# Setup a project for Zanata. This is used by both Python and Django projects.
# syntax: setup_project <project> <zanata_version>
function setup_project {
    local project=$1
    local version=$2

    # Exclude all dot-files, particuarly for things such such as .tox
    # and .venv
    local exclude='.*/**'

    python3 $SCRIPTSDIR/prepare-zanata-xml/create-zanata-xml.py \
        -p $project -v $version --srcdir . --txdir . \
        -r '**/*.pot' '{path}/{locale_with_underscore}/LC_MESSAGES/{filename}.po' \
        -e "$exclude" -f $WORK_DIR/projects/$project/$project/zanata.xml
}

# Setup project manuals projects (api-site, openstack-manuals,
# security-guide) for Zanata
function setup_manuals {
    local project=$1
    local version=${2:-master}

    # Fill in associative array SPECIAL_BOOKS
    declare -A SPECIAL_BOOKS
    source doc-tools-check-languages.conf

    # Grab all of the rules for the documents we care about
    ZANATA_RULES=

    # List of directories to skip.

    # All manuals have a source/common subdirectory that is a symlink
    # to doc/common in openstack-manuals. We have to exclude this
    # source/common directory everywhere, only doc/common gets
    # translated.
    EXCLUDE='.*/**,**/source/common/**'

    # Generate pot one by one
    for FILE in ${DocFolder}/*; do
        # Skip non-directories
        if [ ! -d $FILE ]; then
            continue
        fi
        DOCNAME=${FILE#${DocFolder}/}
        # Ignore directories that will not get translated
        if [[ "$DOCNAME" =~ ^(www|tools|generated|publish-docs)$ ]]; then
            continue
        fi
        IS_RST=0
        if [ ${SPECIAL_BOOKS["${DOCNAME}"]+_} ] ; then
            case "${SPECIAL_BOOKS["${DOCNAME}"]}" in
                RST)
                    IS_RST=1
                    ;;
                skip)
                    EXCLUDE="$EXCLUDE,${DocFolder}/${DOCNAME}/**"
                    continue
                    ;;
            esac
        fi
        if [ ${IS_RST} -eq 1 ] ; then
            ZANATA_RULES="$ZANATA_RULES -r ${ZanataDocFolder}/${DOCNAME}/source/locale/${DOCNAME}.pot ${DocFolder}/${DOCNAME}/source/locale/{locale_with_underscore}/LC_MESSAGES/${DOCNAME}.po"
        else
            if [ -f ${DocFolder}/${DOCNAME}/locale/${DOCNAME}.pot ]; then
                ZANATA_RULES="$ZANATA_RULES -r ${ZanataDocFolder}/${DOCNAME}/locale/${DOCNAME}.pot ${DocFolder}/${DOCNAME}/locale/{locale_with_underscore}.po"
            fi
        fi
    done

    # Project setup and updating POT files for release notes.
    if [[ $project == "openstack-manuals" ]] && [[ $version == "master" ]]; then
        ZANATA_RULES="$ZANATA_RULES -r ./releasenotes/source/locale/releasenotes.pot releasenotes/source/locale/{locale_with_underscore}/LC_MESSAGES/releasenotes.po"
    fi

    python3 $SCRIPTSDIR/prepare-zanata-xml/create-zanata-xml.py \
        -p $project -v $version --srcdir . --txdir . \
        $ZANATA_RULES -e "$EXCLUDE" \
        -f $WORK_DIR/projects/$project/$project/zanata.xml
}

# Setup a training-guides project for Zanata
function setup_training_guides {
    local project=training-guides
    local version=${1:-master}

    python3 $SCRIPTSDIR/prepare-zanata-xml/create-zanata-xml.py \
        -p $project -v $version \
        --srcdir doc/upstream-training/source/locale \
        --txdir doc/upstream-training/source/locale \
        -f $WORK_DIR/projects/$project/$project/zanata.xml
}

# Setup a i18n project for Zanata
function setup_i18n {
    local project=i18n
    local version=${1:-master}

    # Update the .pot file
    tox -e generatepot

    python3 $SCRIPTSDIR/create-zanata-xml.py \
        -p $project -v $version \
        --srcdir doc/source/locale \
        --txdir doc/source/locale \
        -f $WORK_DIR/projects/$project/$project/zanata.xml
}

# Setup a ReactJS project for Zanata
function setup_reactjs_project {
    local project=$1
    local version=$2

    local exclude='node_modules/**'

    setup_nodeenv

    # Extract messages
    npm install
    npm run build
    # Transform them into .pot files
    npm run json2pot

    python3 $SCRIPTSDIR/prepare-zanata-xml/create-zanata-xml.py \
        -p $project -v $version --srcdir . --txdir . \
        -r '**/*.pot' '{path}/{locale}.po' \
        -e "$exclude" \
        -f $WORK_DIR/projects/$project/$project/zanata.xml
}
