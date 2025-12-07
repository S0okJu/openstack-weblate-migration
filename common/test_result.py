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

from datetime import datetime
import json
import os

"""
Expected JSON structure:
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
                "last_updated": "2025-01-01 12:00:00"   
            }
        }
    }
}
"""


class TestResult:
    def __init__(self, json_path: str = None):
        """Initialize TestResult
        
        :param json_path: Path to existing JSON file to load
        """
        if json_path and os.path.exists(json_path):
            self.load_from_json(json_path)
        else:
            self.result = {"projects": {}}
    
    def add_locale_result(
        self,
        project_name: str,
        category_name: str,
        component_name: str,
        locale: str,
        total_count: int,
        translated_count: int,
        success: bool,
        errors: list
    ) -> None:
        """Add test result for a specific locale
        
        :param project_name: Name of the project (e.g., "horizon")
        :param category_name: Name of the category/version (e.g., "master")
        :param component_name: Name of the component (e.g., "horizon-django")
        :param locale: Locale code (e.g., "en_US", "ko_KR")
        :param total_count: Total number of translation entries
        :param translated_count: Number of translated entries
        :param success: Whether the test passed
        :param errors: List of error messages
        """
        # Initialize project if not exists
        if project_name not in self.result["projects"]:
            self.result["projects"][project_name] = {}
        
        # Initialize category if not exists
        if category_name not in self.result["projects"][project_name]:
            self.result["projects"][project_name][category_name] = {
                "last_updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            }
        
        # Initialize component if not exists
        if component_name not in self.result["projects"][project_name][category_name]:
            self.result["projects"][project_name][category_name][component_name] = {
                "total_count": total_count,
                "locales": {}
            }
        
        # Update total_count (use the latest value)
        self.result["projects"][project_name][category_name][component_name]["total_count"] = total_count
        
        # Add locale result
        self.result["projects"][project_name][category_name][component_name]["locales"][locale] = {
            "translated_count": translated_count,
            "success": success,
            "errors": errors
        }
        
        # Update last_updated timestamp
        self.result["projects"][project_name][category_name]["last_updated"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    def save_to_json(self, path: str) -> None:
        """Save results to JSON file
        
        :param path: Path to save the JSON file
        """
        with open(path, 'w') as f:
            json.dump(self.result, f, indent=2)
        print(f"[INFO] Test results saved to: {path}")
    
    def load_from_json(self, path: str) -> None:
        """Load results from JSON file
        
        :param path: Path to the JSON file
        """
        with open(path, 'r') as f:
            self.result = json.load(f)
        print(f"[INFO] Test results loaded from: {path}")
    
    def get_result(self) -> dict:
        """Get the complete result dictionary
        
        :returns: Complete test results
        """
        return self.result