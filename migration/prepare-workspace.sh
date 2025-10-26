#!/bin/bash
# Set venv and folder structure for migration
# prepare-workspace.sh

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

WORK_DIR="$HOME/workspace"

source $SCRIPTSDIR/pretty-printer.sh

# Install system dependencies for migration
# jq is used to print JSON response pretty
# gettext is used to extract messages from source code
function install_system_dependencies() {
    local dependencies=("gettext" "jq")

    for dependency in ${dependencies[@]}; do  
        sudo apt install -y $dependency 2>&1
        if [ $? -ne 0 ]; then
            fail "Failed to install $dependency"
            return 1
        fi
    done
    return 0
}

function create_python_venv() {
    # check python3 is installed
    if ! command -v python3 &> /dev/null; then
        fail "Python3 is not installed"
        return 1
    fi

    # check python is 3.10.*
    # NOTE: we only test 3.10 version
    # PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    # if [[ "$PYTHON_VERSION" != "3.10" ]]; then
    #     fail "Python 3.10 is not installed"
    #     return 1
    # fi

    # create venv 
    if [ ! -d "$WORK_DIR/.venv" ]; then
        python3.10 -m venv $WORK_DIR/.venv >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            fail "Failed to create virtual environment"
            return 1
        fi
    fi

    debug "Virtual environment created"
    return 0
}

function install_python_dependencies() {
    source $WORK_DIR/.venv/bin/activate

    # Install dependencies for custom python scripts
    pip3 install polib==1.2.0 lxml==4.9.3
    if [ $? -ne 0 ]; then
        fail "Failed to install dependencies for custom python scripts"
        return 1
    fi

    # Install dependencies for migrations
    if [ ! -d "$WORK_DIR/requirements" ]; then
        git clone https://opendev.org/openstack/requirements $WORK_DIR/requirements
    fi

    cd $WORK_DIR/requirements

    # Install dependencies with bindep
    pip3 install bindep
    bindep_packages=$($SCRIPTSDIR/.venv/bin/bindep -b 2>/dev/null)
    if [ -n "$bindep_packages" ]; then
        sudo apt install -y $bindep_packages
        if [ $? -ne 0 ]; then
            fail "Failed to install system dependencies with bindep"
            return 1
        fi
    fi

    # Install dependencies with upper-constraints
    pip3 install -r upper-constraints.txt
    if [ $? -ne 0 ]; then
        fail "Failed to install upper-constraints"
        return 1
    fi

    return 0
}

function check_zanata_cli() {
    # Check zanata-cli is installed
    if ! command -v zanata-cli &> /dev/null; then
        fail "zanata-cli is not installed"
        return 1
    fi

    # Check zanata.ini file exists
    if [ ! -f "$HOME/.config/zanata.ini" ]; then
        fail "zanata.ini is not found"
        return 1
    fi

    return 0
}

# Django projects need horizon installed for extraction, install it in
# our venv. The function setup_venv needs to be called first.
function install_horizon {
    # Horizon is a project to be translated.
    # We install it in project directory. 
    if [ ! -d "$HOME/workspace/projects/horizon"]; then
        mkdir -p $HOME/workspace/projects/horizon
        git clone https://opendev.org/openstack/horizon $HOME/workspace/projects/horizon/horizon
    fi
    
    # Save current directory
    local current_dir=$(pwd)
    cd $HOME/workspace/projects/horizon/horizon
    pip3 install -r requirements.txt -r test-requirements.txt &&
    pip3 install .
    local install_result=$?
    
    # Return to original directory
    cd "$current_dir"
    
    if [ $install_result -ne 0 ]; then
        fail "Failed to install horizon to setup environment"
        return 1
    fi
    
    return 0
}

function setup_env() {
    if ! install_system_dependencies; then
        return 1
    fi

    if ! create_python_venv; then
        return 1
    fi
 
    if ! install_python_dependencies; then
        return 1
    fi

    if ! install_horizon; then
        return 1
    fi
 
    if ! check_zanata_cli; then
        return 1
    fi

    return 0
}

function prepare_workspace() {
    # Create workspace directory
    if [ ! -d "$HOME/workspace" ]; then
        if ! mkdir -p "$HOME/workspace"; then
            fail "Failed to create workspace directory"
            return 1
        fi
    fi

    # Create projects directory
    if [ ! -d "$HOME/workspace/projects" ]; then
        if ! mkdir -p "$HOME/workspace/projects"; then
            fail "Failed to create projects directory"
            return 1
        fi
    fi

    debug "Workspace directory created successfully"
    return 0

}

function prepare_project_workspace() {
    local project=$1

    # Create project directory
    if [ ! -d "$HOME/workspace/projects/$project" ]; then
        mkdir -p $HOME/workspace/projects/$project
    fi

    # Clone project
    module_name=$(echo $project | sed 's/-/_/g')
    if [ ! -d "$HOME/workspace/projects/$project/$project" ]; then
        git clone https://opendev.org/openstack/$project $HOME/workspace/projects/$project/$project
        git checkout $BRANCH_NAME
        if [ $? -ne 0 ]; then
            fail "The $BRANCH_NAME branch is not found in the $project project"
            return 1
        fi
        debug "Project $project cloned successfully"
    fi

    # Create pot directory
    if [ ! -d "$HOME/workspace/projects/$project/pot" ]; then
        mkdir -p $HOME/workspace/projects/$project/pot
        debug "Pot directory created successfully"
    fi

    # Create translations directory
    if [ ! -d "$HOME/workspace/projects/$project/translations" ]; then
        mkdir -p $HOME/workspace/projects/$project/translations
        debug "Translations directory created successfully"
    fi

    return 0
}