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
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any
import json

"""
Expected JSON structure:
{
    "projects": {
        "horizon": {
            "master": {
                "metadata": {
                    "total_components": ,
                    "total_locales": 50,
                    "locales": [
                        "en_US",
                        "ko_KR",
                    ]
                },
                "horizon-django": {
                    "total_count": 100,
                    "locales": {
                        "en_US": {
                            "total_count": 100,
                            "translated_count": 100,
                            "success": true,
                            "errors": [],
                            "last_updated": "2025-01-01 12:00:00"
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
            }
        }
    }
}
"""


class TestResult:
    """Test result manager for translation accuracy testing"""
    
    def __init__(self, json_path: Optional[Path] = None):
        """Initialize TestResult
        
        :param json_path: Path to existing JSON file to load
        """
        self.json_path = Path(json_path) if json_path else None
        self._result: Dict[str, Any] = {"projects": {}}
        
        if self.json_path and self.json_path.exists():
            self.load_from_json(self.json_path)
    
    @property
    def projects(self) -> Dict:
        """Get projects dictionary"""
        return self._result["projects"]
    
    @staticmethod
    def _timestamp() -> str:
        """Get current timestamp string"""
        return datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    def _ensure_project(self, project_name: str) -> Dict:
        """Ensure project exists and return it"""
        if project_name not in self.projects:
            self.projects[project_name] = {}
        return self.projects[project_name]
    
    def _ensure_category(self, project_name: str, category_name: str) -> Dict:
        """Ensure category exists and return it"""
        project = self._ensure_project(project_name)
        if category_name not in project:
            project[category_name] = {
                "metadata": {
                    "total_components": 0,
                    "total_locales": 0,
                    "locales": []
                },
                "last_updated": self._timestamp()
            }
        return project[category_name]
    
    def _ensure_component(self, project_name: str, category_name: str, 
                         component_name: str, total_count: int = 0) -> Dict:
        """Ensure component exists and return it"""
        category = self._ensure_category(project_name, category_name)
        if component_name not in category:
            category[component_name] = {
                "total_count": total_count,
                "locales": {}
            }
        return category[component_name] 
    
    
    def add_locale_result(
        self,
        project_name: str,
        category_name: str,
        component_name: str,
        locale: str,
        *,  # Force keyword-only arguments
        total_count: int,
        translated_count: int,
        success: bool,
        errors: Optional[List[str]] = None
    ) -> 'TestResult':  # Return self for method chaining
        """Add test result for a specific locale
        
        :param project_name: Name of the project (e.g., "horizon")
        :param category_name: Name of the category/version (e.g., "master")
        :param component_name: Name of the component (e.g., "horizon-django")
        :param locale: Locale code (e.g., "en_US", "ko_KR")
        :param total_count: Total number of translation entries
        :param translated_count: Number of translated entries
        :param success: Whether the test passed
        :param errors: List of error messages
        :return: Self for method chaining
        """
        errors = errors or []
        
        # Ensure all parents exist
        component = self._ensure_component(project_name, category_name, 
                                          component_name, total_count)
        
        # Check if overwriting
        if locale in component["locales"]:
            print(f"[INFO] Overwriting result for "
                  f"{project_name}/{category_name}/{component_name}/{locale}")
        
        # Update component total_count
        component["total_count"] = total_count
        
        # Add/update locale result
        component["locales"][locale] = {
            "total_count": total_count,
            "translated_count": translated_count,
            "success": success,
            "errors": errors,
            "last_updated": self._timestamp()
        }
        
        # Update category metadata and timestamp
        self._update_category_metadata(project_name, category_name)
        
        return self  # Enable method chaining
    
    def _update_category_metadata(self, project_name: str, category_name: str) -> None:
        """Update category metadata based on current data
        
        :param project_name: Name of the project
        :param category_name: Name of the category
        """
        category = self._ensure_category(project_name, category_name)
        
        # Collect all locales and components
        all_locales = set()
        components = [key for key in category.keys() 
                     if key not in ['metadata', 'last_updated']]
        
        for comp_name in components:
            comp_locales = category[comp_name].get("locales", {}).keys()
            all_locales.update(comp_locales)
        
        # Update metadata
        category["metadata"] = {
            "total_components": len(components),
            "total_locales": len(all_locales),
            "locales": sorted(all_locales)
        }
        
        # Update timestamp
        category["last_updated"] = self._timestamp()
    
    def save_to_json(self, path: Optional[Path] = None) -> 'TestResult':
        """Save results to JSON file
        
        :param path: Path to save the JSON file (uses self.json_path if not provided)
        :return: Self for method chaining
        """
        save_path = Path(path) if path else self.json_path
        if not save_path:
            raise ValueError("No path provided and no default path set")
        
        # Update all category metadata before saving
        for project_name, project in self.projects.items():
            for category_name in project.keys():
                self._update_category_metadata(project_name, category_name)
        
        # Ensure parent directory exists
        save_path.parent.mkdir(parents=True, exist_ok=True)
        
        with save_path.open('w', encoding='utf-8') as f:
            json.dump(self._result, f, indent=2, ensure_ascii=False)
        
        print(f"[INFO] Test results saved to: {save_path}")
        return self
    
    def load_from_json(self, path: Path) -> 'TestResult':
        """Load results from JSON file
        
        :param path: Path to the JSON file
        :return: Self for method chaining
        """
        path = Path(path)
        with path.open('r', encoding='utf-8') as f:
            self._result = json.load(f)
        
        print(f"[INFO] Test results loaded from: {path}")
        return self
    
    def to_dict(self) -> Dict:
        """Get the complete result dictionary
        
        :returns: Complete test results
        """
        return self._result.copy()
    
    def get_component_locales(self, project_name: str, category_name: str, 
                             component_name: str) -> List[str]:
        """Get all locales for a component
        
        :returns: List of locale codes
        """
        try:
            return list(self.projects[project_name][category_name]
                       [component_name]["locales"].keys())
        except KeyError:
            return []
    
    def get_success_rate(self, project_name: str, category_name: str, 
                        component_name: str) -> float:
        """Calculate success rate for a component
        
        :returns: Success rate as percentage (0-100)
        """
        locales = self.get_component_locales(project_name, category_name, component_name)
        if not locales:
            return 0.0
        
        component = self.projects[project_name][category_name][component_name]
        success_count = sum(
            1 for locale in locales 
            if component["locales"][locale].get("success", False)
        )
        
        return (success_count / len(locales)) * 100
    
    def __repr__(self) -> str:
        """String representation"""
        total_projects = len(self.projects)
        total_tests = sum(
            len(category[comp]["locales"])
            for project in self.projects.values()
            for category in project.values()
            for comp in category.keys()
            if comp != "last_updated"
        )
        return f"<TestResult: {total_projects} projects, {total_tests} tests>"