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

# title is a description of the stage
function stage() {
    local title=$1
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
    echo "=========================================="
}