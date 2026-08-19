#!/bin/bash
# Pretty print to show readable and standardize the output
# pretty-printer.sh

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

# Tracks whether a stage() is currently open (1) or was closed by a
# matching endstage() (0). Used by _stage_exit_trap below so a stage
# that fails and exits without ever calling endstage still gets its
# closing separator - callers (e.g. migration_resources.sh) exit
# directly from many places, including from deep inside sourced
# functions in other files, so relying on every call site to
# remember to call endstage before exit is not reliable.
_STAGE_OPEN=0

# title is a description of the stage
function stage() {
    local title=$1
    _STAGE_OPEN=1
    echo "# ${title}"
}

function fail() {
    local message=$1
    echo "[Failed] ${message}"
}

function debug() {
    local message=$1
    echo "[Debug] ${message}"
}

function endstage() {
    _STAGE_OPEN=0
    echo "=========================================="
}

# Prints the closing separator for a stage left open by a process exit
# (normal or via `exit N`) that never reached endstage. Registered as
# an EXIT trap below so it runs regardless of where in the script - or
# in a sourced function from another file - the exit happens.
function _stage_exit_trap() {
    if [ "$_STAGE_OPEN" -eq 1 ]; then
        _STAGE_OPEN=0
        echo "=========================================="
    fi
}
trap _stage_exit_trap EXIT