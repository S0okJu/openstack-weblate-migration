#!/bin/bash
# Preprocess pot files for each component
# preprocess-pot.sh

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

PROJECT_DIR="$HOME/workspace/projects/$PROJECT/$PROJECT"
POT_DIR="$HOME/workspace/projects/$PROJECT/pot"

source $SCRIPTSDIR/pretty-printer.sh

function preprocess_api_site_pot {
    # python3 $SCRIPTSDIR/convert_pot.py $PROJECT_DIR/api-quick-start/locale/api-quick-start.pot
    # python3 $SCRIPTSDIR/convert_pot.py $PROJECT_DIR/firstapp/locale/firstapp.pot

    cp $PROJECT_DIR/api-quick-start/locale/api-quick-start.pot "$POT_DIR/api-quick-start.pot"
    cp $PROJECT_DIR/firstapp/locale/firstapp.pot "$POT_DIR/firstapp.pot"
}

function preprocess_security_doc_pot {
    # python3 $SCRIPTSDIR/convert_pot.py security-guide/locale/security-guide.pot
    cp $PROJECT_DIR/security-guide/locale/security-guide.pot "$POT_DIR/security-guide.pot"
}

function preprocess_doc_pot {
    local doc_name=$1

    # python3 $SCRIPTSDIR/convert_pot.py $PROJECT_DIR/doc/source/locale/$doc_name.pot
    cp $PROJECT_DIR/doc/source/locale/$doc_name.pot "$POT_DIR/$doc_name.pot"
}

function preprocess_releasenotes_pot {
    # python3 $SCRIPTSDIR/convert_pot.py $PROJECT_DIR/releasenotes/source/locale/releasenotes.pot
    cp $PROJECT_DIR/releasenotes/source/locale/releasenotes.pot "$POT_DIR/releasenotes.pot"
}

function preprocess_training_guides_pot {
    # python3 $SCRIPTSDIR/convert_pot.py $PROJECT_DIR/doc/upstream-training/source/locale/upstream-training.pot
    cp $PROJECT_DIR/doc/upstream-training/source/locale/upstream-training.pot "$POT_DIR/upstream-training.pot"
}

function preprocess_i18n_pot {
    # python3 $SCRIPTSDIR/convert_pot.py $PROJECT_DIR/doc/locale/i18n.pot
    cp $PROJECT_DIR/doc/locale/i18n.pot "$POT_DIR/i18n.pot"
}

function preprocess_reactjs_pot {
    # python3 $SCRIPTSDIR/convert_pot.py $PROJECT_DIR/i18n/locale/i18n.pot
    cp $PROJECT_DIR/i18n/locale/i18n.pot "$POT_DIR/i18n.pot"
}

function preprocess_python_pot {
    local modulename=$1
    local dest_modulename=$2

    # python3 $SCRIPTSDIR/convert_pot.py $PROJECT_DIR/$modulename/locale/$modulename.pot
    cp $PROJECT_DIR/$modulename/locale/$modulename.pot "$POT_DIR/$dest_modulename.pot"
}

function preprocess_django_pot {
    local modulename=$1
    local target_modulename=$2
    local dest_modulename=$3

    # python3 $SCRIPTSDIR/convert_pot.py $PROJECT_DIR/$modulename/locale/$target_modulename.pot
    cp $PROJECT_DIR/$modulename/locale/$target_modulename.pot "$POT_DIR/$dest_modulename.pot"
}