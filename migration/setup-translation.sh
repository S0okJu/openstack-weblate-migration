#!/bin/bash -xe
# Create zanata.xml for export translation from Zanata
# setup-translation.sh

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

VENV_DIR="$HOME/workspace/.venv"

# Used for setup.py babel commands
QUIET="--quiet"

# Have invalid files been found?
INVALID_PO_FILE=0

# ERROR_ABORT signals whether the script aborts with failure, will be
# set to 0 on successful run.
ERROR_ABORT=1

# HORIZON_DIR="$SCRIPTSDIR/workspace/projects/horizon"

# List of repos that have doc/source translated, we test with a smaller
# set for now.
DOC_TARGETS=('contributor-guide'
             'horizon'
             'openstack-ansible'
             'operations-guide',
             'swift')


# Get a module name of a project
function get_modulename {
    local project=$1
    local target=$2

    python3 $SCRIPTSDIR/get-modulename.py -p $project -t $target -f $HOME/workspace/projects/$project/$project/setup.cfg
}

# Setup nodejs within the python venv. Match the nodejs version with
# the one used in the nodejs6-npm jobs.
function setup_nodeenv {

    # The ensure-babel and ensure-sphinx roles create a venv in
    # ~/.venv containing the needed software. However, it's possible
    # we may want to switch that to using pip install --user and
    # ~/.local instead of a venv, so make this compatible with either.

    NODE_VENV=~/.local/node_venv
    if [ -d ~/.venv ] ; then
        pip install nodeenv
        nodeenv --node 6.9.4 $NODE_VENV
    else
        pip install --user nodeenv
        ~/.local/bin/nodeenv --node 6.9.4 $NODE_VENV
    fi
    source $NODE_VENV/bin/activate

}

# Setup a project for Zanata. This is used by both Python and Django projects.
# syntax: setup_project <project> <zanata_version>
function setup_project {
    local project=$1
    local version=$2

    # Exclude all dot-files, particuarly for things such such as .tox
    # and .venv
    local exclude='.*/**'

    python3 $SCRIPTSDIR/create-zanata-xml.py \
        -p $project -v $version --srcdir . --txdir . \
        -r '**/*.pot' '{path}/{locale_with_underscore}/LC_MESSAGES/{filename}.po' \
        -e "$exclude" -f zanata.xml
}


# Set global variable DocFolder for manuals projects
function init_manuals {
    project=$1

    DocFolder="doc"
    ZanataDocFolder="./doc"
    if [ $project = "api-site" -o $project = "security-doc" ] ; then
        DocFolder="./"
        ZanataDocFolder="."
    fi
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
            tox -e generatepot-rst -- ${DOCNAME}
            ZANATA_RULES="$ZANATA_RULES -r ${ZanataDocFolder}/${DOCNAME}/source/locale/${DOCNAME}.pot ${DocFolder}/${DOCNAME}/source/locale/{locale_with_underscore}/LC_MESSAGES/${DOCNAME}.po"
        else
            # Update the .pot file
            ./tools/generatepot ${DOCNAME}
            if [ -f ${DocFolder}/${DOCNAME}/locale/${DOCNAME}.pot ]; then
                ZANATA_RULES="$ZANATA_RULES -r ${ZanataDocFolder}/${DOCNAME}/locale/${DOCNAME}.pot ${DocFolder}/${DOCNAME}/locale/{locale_with_underscore}.po"
            fi
        fi
    done

    # Project setup and updating POT files for release notes.
    if [[ $project == "openstack-manuals" ]] && [[ $version == "master" ]]; then
        ZANATA_RULES="$ZANATA_RULES -r ./releasenotes/source/locale/releasenotes.pot releasenotes/source/locale/{locale_with_underscore}/LC_MESSAGES/releasenotes.po"
    fi

    python3 $SCRIPTSDIR/create-zanata-xml.py \
        -p $project -v $version --srcdir . --txdir . \
        $ZANATA_RULES -e "$EXCLUDE" \
        -f zanata.xml
}

# Setup a training-guides project for Zanata
function setup_training_guides {
    local project=training-guides
    local version=${1:-master}

    # Update the .pot file
    tox -e generatepot-training

    python3 $SCRIPTSDIR/create-zanata-xml.py \
        -p $project -v $version \
        --srcdir doc/upstream-training/source/locale \
        --txdir doc/upstream-training/source/locale \
        -f zanata.xml
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
        -f zanata.xml
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

    python3 $SCRIPTSDIR/create-zanata-xml.py \
        -p $project -v $version --srcdir . --txdir . \
        -r '**/*.pot' '{path}/{locale}.po' \
        -e "$exclude" -f zanata.xml
}

# Delete empty pot files
function check_empty_pot {
    local pot=$1

    # We don't need to add or send around empty source files.
    trans=$(msgfmt --statistics -o /dev/null ${pot} 2>&1)
    if [ "$trans" = "0 translated messages." ] ; then
        rm $pot
    fi
}

# Run extract_messages for python projects.
function extract_messages_python {
    local modulename=$1

    local pot=${modulename}/locale/${modulename}.pot

    # In case this is an initial run, the locale directory might not
    # exist, so create it since extract_messages will fail if it does
    # not exist. So, create it if needed.
    mkdir -p ${modulename}/locale

    # Update the .pot files
    # The "_C" and "_P" prefix are for more-gettext-support blueprint,
    # "_C" for message with context, "_P" for plural form message.
    pybabel ${QUIET} extract \
        --add-comments Translators: \
        --msgid-bugs-address="https://bugs.launchpad.net/openstack-i18n/" \
        --project=${PROJECT} --version=${VERSION} \
        -k "_C:1c,2" -k "_P:1,2" \
        -o ${pot} ${modulename}
    check_empty_pot ${pot}
}
# Extract messages for a django project, we need to update django.pot
# and djangojs.pot.
function extract_messages_django {
    local modulename=$1
    local pot

    KEYWORDS="-k gettext_noop -k gettext_lazy -k ngettext_lazy:1,2"
    KEYWORDS+=" -k ugettext_noop -k ugettext_lazy -k ungettext_lazy:1,2"
    KEYWORDS+=" -k npgettext:1c,2,3 -k pgettext_lazy:1c,2 -k npgettext_lazy:1c,2,3"

    for DOMAIN in djangojs django ; do
        if [ -f babel-${DOMAIN}.cfg ]; then
            mkdir -p ${modulename}/locale
            pot=${modulename}/locale/${DOMAIN}.pot
            touch ${pot}
            pybabel ${QUIET} extract -F babel-${DOMAIN}.cfg \
                --add-comments Translators: \
                --msgid-bugs-address="https://bugs.launchpad.net/openstack-i18n/" \
                --project=${PROJECT} --version=${VERSION} \
                $KEYWORDS \
                -o ${pot} ${modulename}
            check_empty_pot ${pot}
        fi
    done
}

# Extract doc messages
function extract_messages_doc {
    # Temporary build folder for gettext
    mkdir -p doc/build/gettext

    # Extract messages
    $VENV_DIR/bin/sphinx-build -b gettext doc/source \
        doc/build/gettext/
    # Manipulates pot translation sources if needed
    if [[ -f tools/doc-pot-filter.sh ]]; then
        tools/doc-pot-filter.sh
    fi

    # New translation target projects may not have locale folder
    mkdir -p doc/source/locale

    # Sphinx builds a pot file for each directory and for each file
    # in the top-level directory.
    # We keep the directory files and concatenate all top-level files.
    local has_other=0
    for f in doc/build/gettext/*.pot; do
        local fn=$(basename $f .pot)
        # If a pot file corresponds to a directory, we use the pot file as-is.
        if [ -d doc/source/$fn ]; then
            msgcat --use-first --sort-by-file $f \
                > doc/source/locale/doc-$fn.pot
            rm $f
        else
            has_other=1
        fi
    done

    # We concatenate remaining into a single pot file so that
    # single pot file for all top-level files.
    if [ "$has_other" = "1" ]; then
        msgcat --use-first --sort-by-file doc/build/gettext/*.pot \
            > doc/source/locale/doc.pot
    fi

    rm -rf doc/build/gettext/
}

# Extract releasenotes messages
function extract_messages_releasenotes {
    local keep_workdir=$1

    
    # Extract messages
    $VENV_DIR/bin/sphinx-build -b gettext -d releasenotes/build/doctrees \
        releasenotes/source releasenotes/work
    rm -rf releasenotes/build
    # Concatenate messages into one POT file
    mkdir -p "$TARGET_PROJECT_DIR/pot"
    if [ -d "releasenotes/work" ] && [ "$(find releasenotes/work -name "*.pot" -type f | wc -l)" -gt 0 ]; then
        msgcat --sort-by-file releasenotes/work/*.pot \
            > releasenotes/source/locale/releasenotes.pot
    fi
    if [ "$keep_workdir" != "1" ]; then
        rm -rf releasenotes/work
    fi
}

# Check releasenote translation progress per language.
# It checks the progress per release. Add the release note translation
# 
# NOTE: We did not consider the translation progress per language.
# NOTE: this function assume POT files in releasenotes/work
# extracted by extract_messages_releasenotes().
# The workdir should be clean up by the caller.
function check_releasenotes_per_language {
    local lang_po=$1

    # The expected PO location is
    # releasenotes/source/locale/<lang>/LC_MESSAGES/releasenotes.po.
    # Extract language name from 4th component.
    local lang
    lang=$(echo $lang_po | cut -d / -f 4)

    local release_pot
    local release_name
    local workdir=releasenotes/work

    local has_high_thresh=0
    local has_low_thresh=0

    mkdir -p $workdir/$lang
    for release_pot in $(find $workdir -name '*.pot'); do
        release_name=$(basename $release_pot .pot)
        # The index file usually contains small number of words,
        # so we skip to check it.
        if [ $release_name = "index" ]; then
            continue
        fi
        msgmerge --quiet -o $workdir/$lang/$release_name.po $lang_po $release_pot
        check_po_file $workdir/$lang/$release_name.po
    done
}

# Remove all pot files, we publish them to
# http://tarballs.openstack.org/translation-source/{name}/VERSION ,
# let's not store them in git at all.
# Previously, we had those files in git, remove them now if there
# are still there.
function cleanup_pot_files {
    local modulename=$1

    for i in $(find $modulename -name *.pot) ; do
        # Remove file; Only local.
        rm $i
    done
}

# Reduce size of po files. This reduces the amount of content imported
# and makes for fewer imports.
# This does not touch the pot files. This way we can reconstruct the po files
# using "msgmerge POTFILE POFILE -o COMPLETEPOFILE".
function compress_po_files {
    local directory=$1

    for i in $(find $directory -name *.po) ; do
        # Remove auto translated comments, those are not needed.
        # Do this first since it introduces empty lines, the msgattrib
        # remove them.
        sed -e 's|^# auto translated by TM merge.*$||' -i $i
        msgattrib --translated --no-location --sort-output "$i" \
            --output="${i}.tmp"
        mv "${i}.tmp" "$i"
    done
}

function pull_from_zanata {

    local project=$1

    # Since Zanata does not currently have an option to not download new
    # files, we download everything, and then remove new files that are not
    # translated enough.
    zanata-cli -B -e pull
}

# Copy all pot files in modulename directory to temporary path for
# publishing. This uses the exact same path.
function copy_pot {
    local all_modules=$1
    local target=.translation-source/$ZANATA_VERSION/

    for m in $all_modules ; do
        for f in `find $m -name "*.pot" ` ; do
            local fd
            fd=$(dirname $f)
            mkdir -p $target/$fd
            cp $f $target/$f
        done
    done
}
