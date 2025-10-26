#!/bin/bash
# Utilities for preparing Weblate
# prepare-weblate.sh
#
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

# Sanitize slug for Weblate
# Replace special characters(dot, space, etc.) with hyphens.
function sanitize_slug {
    local name=$1
    echo "$name" | sed 's/[^a-zA-Z0-9_-]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g'
}

# Extract moudle name from component
# We use it when we read .po files.
function extract_module_name {
    local component=$1
    
    if [[ "$component" == *"-django" ]]; then
        echo "django"
    elif [[ "$component" == *"-djangojs" ]]; then
        echo "djangojs"
    else
        echo "$component"
    fi
}