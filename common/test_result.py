# Copyright (c) 2015 Hewlett-Packard Development Company, L.P.
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

from collections import defaultdict
import json
"""
{
    "projects": {
        "horizon": {
            "master": {
                "horizon-django": {
                    "total_count": 100,
                    "locales": {
                        "en_US": {
                            "translated_count": 100,
                            "success": true,
                            "errors": []
                        },
                        "ko_KR": {
                            "translated_count": 90,
                            "success": false,
                            "errors": [
                                "Translation is not complete",
                                "Translation is not accurate"
                            ]
                        }
                    }
                },
                "last_upadated": "2025-01-01 12:00:00"   
            }
        }
    }
}
"""

*/
class TestResult:
    def __init__(self):
        self.result = defaultdict(dict)
    
    def save_to_json(self, path: str) -> None:
        with open(path, 'w') as f:
            json.dump(self.result, f)
    
    def load_from_json(self, path: str) -> None:
        with open(path, 'r') as f:
            self.result = json.load(f)
    
    def add_project(self, project_name: str) -> None: