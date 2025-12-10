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

import argparse
from collections import defaultdict
import io
import json
import os
from pathlib import Path
import re
import sys
import time
from urllib.parse import urljoin
import zipfile
import polib
import requests


def sanitize_locale(locale: str) -> str:
    """Sanitize locale for standardization

    :param locale: string locale to sanitize
    :returns: string sanitized locale
    """
    # Some translations are set to invalid locale format in weblate.
    # so we need to convert them. ex) zh_Hans, zh_Hant, etc.
    if locale == "zh_Hans":
        locale = "zh_CN"
    elif locale == "zh_Hant":
        locale = "zh_TW"
    # In weblate, the language code is lowercase.
    # ex) Th -> th etc.
    if '_' in locale:
        locale_split = locale.split('_')
        locale = locale_split[0].lower() + '_' + locale_split[1]
    else:
        locale = locale.lower()
    return locale


def sanitize_slug(name: str) -> str:
    """Sanitize slug for standardization

    Replace special characters(dot, space, etc.) with hyphens.
    ex) stable/2025.02 -> stable-2025-02, zun_ui -> zun-ui etc.

    :param name: string name to sanitize
    :returns: string sanitized name
    """
    return re.sub(r'-+', '-', re.sub(r'[^a-zA-Z0-9_-]', '-', name)).strip('-')


def get_filemask(component_name: str) -> str:
    """Get filemask for the component

    It follows the pattern that zanata uses.

    :param component_name: string name of the component
    :returns: string filemask for the component
    """
    if component_name == 'releasenotes':
        return 'source/locale/*/LC_MESSAGES/releasenotes.po'
    # In Weblate, it doesn't allow the same component name.
    # When the project has multiple horizon modules,
    # the component name is <module_name>-django/djangojs.
    # But, the filemask is same for consistency with other components.
    elif component_name == 'django' or component_name.endswith('-django'):
        return 'locale/*/LC_MESSAGES/django.po'
    elif component_name == 'djangojs' or component_name.endswith('-djangojs'):
        return 'locale/*/LC_MESSAGES/djangojs.po'
    # All of the doc components use the same filemask.
    # ex) doc, doc-install, etc.
    elif component_name.startswith('doc'):
        return f'source/locale/*/LC_MESSAGES/{component_name}.po'
    else:
        return f'locale/*/LC_MESSAGES/{component_name}.po'


def get_version_name(version: str) -> str:
    return version.replace('/', '-')


class WeblateConfig:
    """Object that stores Weblate configuration.

    Before using this class, you need to set the
    WEBLATE_TOKEN and WEBLATE_URL
    in system environment variables.
    """
    def __init__(self):
        self.token = os.getenv('WEBLATE_TOKEN')
        self.base_url = os.getenv('WEBLATE_URL')


class WeblateUtils:
    """Utilities for managing Weblate features"""
    def __init__(self, config: WeblateConfig, result_json_path: str = None):
        self.config: WeblateConfig = config
        # All of the API calls are prefixed with api/
        self.base_url = urljoin(self.config.base_url, 'api/')

    @property
    def _headers(self) -> dict:
        """Get headers for the request

        Create a new dict of headers on each call
        to avoid potential issues.
        This prevents issues where headers modified in one method
        could affect subsequent requests.

        :returns: A dict of headers
        """
        return {
            'Authorization': f'Token {self.config.token}',
        }

    def _get(self, url, params=None, raise_error=False) -> requests.Response:
        """Get query to request

        Weblate uses a RESTful API, so query parameters
        should be passed in the URL.

        :param url: The URL to send the request to
        :param params: The parameters to send in the request
        :param raise_error: (Optional)
            If status code is over 400,
            raise an exception.
        :raises: requests.exceptions.RequestException
            If request is failed. If raise_error is True,
            this exception will be raised.
            When it's raised, the function will exit
            with status code 1.
        :returns: requests.Response
        """
        try:
            response = requests.get(url, headers=self._headers, params=params)
            if raise_error:
                response.raise_for_status()
            return response
        except requests.exceptions.RequestException as e:
            print(f"[ERROR] Failed to get: {url}")
            if hasattr(e, 'response') and e.response is not None:
                print(f"[ERROR] Response details: {e.response.text}")
            sys.exit(1)

    def _post(
        self,
        url: str,
        data: str = None,
        file: dict = None,
        raise_error: bool = False
    ) -> requests.Response:
        """Post query to request

        When the file is included in the request,
        the file should be passed in the file parameter.

        :param url: The URL string to send the request to
        :param data: (Optional) The data string to send in the request
        :param file: (Optional) The file dictionary to send in the request
        :param raise_error: (Optional)
            If status code is over 400,
            raise an exception.
        :raises: requests.exceptions.RequestException
            If request is failed. If raise_error is True,
            this exception will be raised.
            When it's raised, the function will exit
            with status code 1.
        :returns: requests.Response
        """
        try:
            # The requests.post automatically set the Content-Type
            # depending on the post type.
            if file:
                response = requests.post(
                    url, data=data, files=file, headers=self._headers)
            else:
                response = requests.post(url, json=data, headers=self._headers)

            if raise_error:
                response.raise_for_status()

            return response
        except requests.exceptions.RequestException as e:
            print(f"[ERROR] Failed to post: {url}")
            print(f"[ERROR] Exception: {e}")
            if hasattr(e, 'response') and e.response is not None:
                print(f"[ERROR] Response: {e.response.text}")
            sys.exit(1)

    def _build_category_list(self, project_name: str) -> dict:
        """Get category list for the project

        :param project_name: The name of the project
        :returns: A dictionary of categories
            Each key is a category name and
            the value is a dictionary representing a category ID.
        """
        path = f'projects/{sanitize_slug(project_name)}/categories/'
        url = urljoin(self.base_url, path)
        response = self._get(url, raise_error=True)

        # The dictionary is set as defaultdict(dict)
        # to clearly indicate the value is a category id.
        category_dict = defaultdict(dict)
        for category in response.json()['results']:
            category_dict[category['name']] = {
                'id': category['id'],
            }
        return category_dict

    def _get_category_id(self, project_name: str, category_name: str) -> int:
        """Get category id for the project

        In weblate, referencing a category requires
        using its unique category ID.

        :param project_name: The name of the project
        :param category_name: The name of the category
        :returns: The id of the category
        """
        category_dict = self._build_category_list(project_name)
        if not category_dict.get(get_version_name(category_name)):
            print("[ERROR] Category does not exist: ", category_name)
            sys.exit(1)

        return category_dict[get_version_name(category_name)]['id']

    def create_project(self, project_name: str) -> None:
        """Create a new project

        If the project does not exist, create a new one.

        :param project_name: The name of the project
        """

        path = f'projects/{sanitize_slug(project_name)}/'
        url = urljoin(self.base_url, path)
        response = self._get(url)
        if response.status_code == 200:
            print("[INFO] Project already exists: ", project_name)
        elif response.status_code == 404:
            print("[INFO] Project does not exist: ", project_name)

            path = 'projects/'
            url = urljoin(self.base_url, path)
            data = {
                'name': project_name,
                'slug': sanitize_slug(project_name),
                'web': f'https://opendev.org/openstack/{project_name}',
            }
            _ = self._post(url=url, data=data, raise_error=True)

            print("[INFO] Project created: ", project_name)
        else:
            print("[ERROR] Failed to create project: ",
                  json.dumps(response.json()))

    def create_category(self, project_name: str, category_name: str) -> None:
        """Create a new category to specify the version.

        If the category does not exist, create a new one.

        :param project_name: The name of the project
        :param category_name: The name of the category
        """

        category_dict = self._build_category_list(project_name)
        is_exists = bool(category_dict.get(get_version_name(category_name)))
        if not is_exists:
            print("[INFO] Category does not exist: ", category_name)

            path = 'categories/'
            url = urljoin(self.base_url, path)
            data = {
                'name': get_version_name(category_name),
                'slug': sanitize_slug(category_name),
                'project': urljoin(
                    self.base_url, f'projects/{sanitize_slug(project_name)}/'),
            }
            _ = self._post(url=url, data=data, raise_error=True)

            print("[INFO] Category created: ", category_name)
        else:
            print("[INFO] Category already exists: ", category_name)

    def create_glossary(self, project_name: str) -> None:
        """Create a new glossary component

        If the glossary component does not exist, create a new one.
        In glossary component, the filemask and file_format is tbx.

        :param project_name: The name of the project
        """
        path = (f'components/{sanitize_slug(project_name)}/'
                f'glossary/')
        url = urljoin(self.base_url, path)
        response = self._get(url)
        if response.status_code == 200:
            print("[INFO] Glossary Component already exists.")
        elif response.status_code == 404:
            print("[INFO] Glossary Component does not exist")

            path = f'projects/{sanitize_slug(project_name)}/components/'
            url = urljoin(self.base_url, path)
            data = {
                'name': 'glossary',
                'slug': 'glossary',
                'file_format': 'tbx',
                'filemask': '*.tbx',
                'repo': 'local:',
                'vcs': 'local',
                'source_language': 'en_US',
                "is_glossary": True,
            }
            _ = self._post(url=url, data=data, raise_error=True)

            print("[INFO] Glossary created.")
        else:
            print("[ERROR] Failed to create glossary: ",
                  json.dumps(response.json()))
            sys.exit(1)

    def create_component(
            self,
            project_name: str,
            category_name: str,
            component_name: str,
            pot_path: str
    ) -> None:
        """Create a new component

        If the component does not exist, create a new one.

        :param project_name: The name of the project
        :param category_name: The name of the category
        :param component_name: The name of the component
        :param pot_path: The path to the pot file
        """

        path = (f'components/{sanitize_slug(project_name)}/'
                f'{sanitize_slug(category_name)}%252F'
                f'{sanitize_slug(component_name)}/')
        url = urljoin(self.base_url, path)
        response = self._get(url)

        if response.status_code == 200:
            print("[INFO] Component already exists: ", component_name)
        elif response.status_code == 404:
            print("[INFO] Component does not exist: ", component_name)

            path = f'projects/{sanitize_slug(project_name)}/components/'
            url = urljoin(self.base_url, path)
            category_id = self._get_category_id(project_name, category_name)
            category_url = urljoin(
                self.base_url,
                f"categories/{category_id}/")

            # Create a zip file containing the pot file for Weblate
            # component initialization.
            # The new_base parameter will be set to the pot file name.
            zip_buf = io.BytesIO()
            with zipfile.ZipFile(
                    zip_buf, 'w', zipfile.ZIP_DEFLATED) as zip_file:
                zip_file.write(pot_path, os.path.basename(pot_path))
            # Set the pointer to the beginning of the zip for uploading.
            zip_buf.seek(0)
            file = {
                'zipfile': (
                    f'{component_name}.zip',
                    zip_buf,
                    'application/zip',
                ),
            }
            data = {
                'name': component_name,
                'slug': sanitize_slug(component_name),
                'file_format': 'po',
                'filemask': get_filemask(component_name),
                'repo': 'local:',
                'vcs': 'local',
                'source_language': 'en_US',
                'new_base': f'{component_name}.pot',
                'category': category_url,
            }
            _ = self._post(url=url, data=data, file=file, raise_error=True)

            print("[INFO] Component created: ", component_name)
        else:
            print("[ERROR] Failed to create component: ",
                  json.dumps(response.json()))
            sys.exit(1)

    def create_translation(
            self,
            project_name: str,
            category_name: str,
            component_name: str,
            locale: str
    ) -> None:
        """Create a new translation

        If the translation does not exist, create a new one.

        :param project_name: The name of the project
        :param category_name: The name of the category
        :param component_name: The name of the component
        :param locale: The locale of the translation
        """

        locale = sanitize_locale(locale)
        path = (f'translations/{sanitize_slug(project_name)}/'
                f'{sanitize_slug(category_name)}%252F'
                f'{sanitize_slug(component_name)}/'
                f'{locale}/')
        url = urljoin(self.base_url, path)
        response = self._get(url)

        if response.status_code == 200:
            print("[INFO] Translation already exists: ", locale)
        elif response.status_code == 404:
            path = (f'components/{sanitize_slug(project_name)}/'
                    f'{sanitize_slug(category_name)}%252F'
                    f'{sanitize_slug(component_name)}/'
                    f'translations/')
            url = urljoin(self.base_url, path)
            data = {
                'language_code': locale,
            }
            _ = self._post(url=url, data=data, raise_error=True)

            print("[INFO] Translation created: ", locale)
        else:
            print("[ERROR] Failed to create translation: ",
                  json.dumps(response.json()))
            sys.exit(1)

    def upload_po_file(
        self,
        project_name: str,
        category_name: str,
        component_name: str,
        locale: str,
        po_path: str
    ) -> None:
        """Upload a translation po file

        This function will retry up to 3 times
        for actually uploading.

        :param project_name: The name of the project
        :param category_name: The name of the category
        :param component_name: The name of the component
        :param locale: The locale of the translation
        :param po_path: The path to the po file
        """

        retry_count = 3
        locale = sanitize_locale(locale)
        path = (f'translations/{sanitize_slug(project_name)}/'
                f'{sanitize_slug(category_name)}%252F'
                f'{sanitize_slug(component_name)}/'
                f'{locale}/file/')
        url = urljoin(self.base_url, path)
        for cnt in range(retry_count):
            sleep_time = 15
            print(f"[INFO] Uploading PO file: {po_path}, "
                  f"Retry count: {cnt + 1}")
            with open(po_path, 'rb') as f:
                file = {
                    'file': f,
                }
                data = {
                    'method': 'replace',
                }
                response = self._post(
                    url=url, file=file, data=data, raise_error=True)

                # If the upload is successful, out of the loop.
                if (response.status_code == 200 and
                        response.json()['result'] is True):
                    print("[INFO] Upload successful: ",
                          component_name, locale)
                    return

                time.sleep(sleep_time)

        print("[INFO] Upload failed: ",
              json.dumps(response.json()))

    def download_translation_file(
        self,
        project_name: str,
        po_path: str,
    ) -> None:
        """Download translation file from Weblate

        :param project_name: Name of the project
        :param po_path: Path to the po file to save
        """
        path = (f'projects/{sanitize_slug(project_name)}/file/')
        url = urljoin(self.base_url, path)
        response = self._get(url, raise_error=True)
        if response.status_code == 200:
            with open(po_path, 'wb') as f:
                f.write(response.content)
            print(
                "[INFO] Successfully downloaded translation "
                f"file from: {url}"
            )
            print(f"[INFO] Saved to: {po_path}")
        else:
            print(
                "[ERROR] Failed to download translation file: "
                f"{response.status_code}"
            )
            sys.exit(1)

        return None

    def check_sentence_count(
        self,
        project_name: str,
        category_name: str,
        component_name: str,
        locale: str,
        zanata_po_path: str,
        weblate_po_path: str,
    ) -> None:
        """Check the sentence count of the translation

        :param project_name: Name of the project
        :param category_name: Name of the category
        :param component_name: Name of the component
        :param locale: Name of the locale
        :param zanata_po_path: Path to the zanata po file
        :param weblate_po_path: Path to the weblate po file
        :returns: None
        """
        zanata_po = polib.pofile(
            zanata_po_path, encoding='utf-8')
        weblate_po = polib.pofile(
            weblate_po_path, encoding='utf-8')

        # Zanata keeps the obsolete entries.
        # On the other hand, Weblate deletes them automatically.
        # Filter out obsolete entries for accurate comparison.
        zanata_active = [e for e in zanata_po if not e.obsolete]
        weblate_active = [e for e in weblate_po if not e.obsolete]
        if len(zanata_active) != len(weblate_active):
            error_msg = (
                f"Total sentence count mismatch: "
                f"{len(zanata_active)}(zanata) != "
                f"{len(weblate_active)}(weblate)"
            )
            print(f"[ERROR] {error_msg}")
            return None

        total_count = len(zanata_active)
        zanata_translated = len(
            [e for e in zanata_active if e.translated()])
        weblate_translated = len(
            [e for e in weblate_active if e.translated()])

        if len(zanata_active) != len(weblate_active):
            error_msg = (
                f"Sentence count mismatch: "
                f"{len(zanata_active)}(zanata) != "
                f"{len(weblate_active)}(weblate)"
            )
            print(f"[ERROR] {error_msg}")
            return None

        if zanata_translated != weblate_translated:
            error_msg = (
                f"Translated sentence count mismatch: "
                f"{zanata_translated}(zanata) != "
                f"{weblate_translated}(weblate)"
            )
            print(f"[ERROR] {error_msg}")

            return None

        print(
            f"[INFO] ✓ Count matched(translated/total): "
            f"{zanata_translated}/{len(zanata_active)}"
        )

        return None

    def check_sentence_detail(
        self,
        project_name: str,
        category_name: str,
        component_name: str,
        locale: str,
        zanata_po_path: str,
        weblate_po_path: str,
    ) -> None:
        """Check detailed translation matching and save to TestResult.

        :param project_name: Name of the project
        :param category_name: Name of the category
        :param component_name: Name of the component
        :param locale: Locale code
        :param zanata_po_path: Path to the zanata po file
        :param weblate_po_path: Path to the weblate po file
        """
        zanata_po = polib.pofile(zanata_po_path, encoding='utf-8')
        weblate_po = polib.pofile(weblate_po_path, encoding='utf-8')

        # Filter out obsolete entries for accurate comparison
        zanata_entries = [e for e in zanata_po if not e.obsolete]
        weblate_entries = [e for e in weblate_po if not e.obsolete]

        # Create a dictionary for Weblate entries by msgid for fast lookup
        weblate_dict = {entry.msgid: entry for entry in weblate_entries}

        mismatch_count = 0
        missing_count = 0

        for zanata_entry in zanata_entries:
            msgid = zanata_entry.msgid

            # Check it msgid exists in Weblate
            if msgid not in weblate_dict:
                error_msg = f"Missing in Weblate: msgid='{msgid}'"
                print(f"[ERROR] {error_msg}")
                missing_count += 1
                continue

            weblate_entry = weblate_dict[msgid]

            # Compare msgstr from zanata and weblate
            if zanata_entry.msgstr != weblate_entry.msgstr:
                error_msg = (
                    f"Translation mismatch for msgid: '{msgid}' "
                    f"- Zanata msgstr: '{zanata_entry.msgstr}' "
                    f"- Weblate msgstr: '{weblate_entry.msgstr}'"
                )
                print(f"[ERROR] {error_msg}")
                mismatch_count += 1

        # Check for entries in Weblate but not in Zanata
        zanata_msgids = {e.msgid for e in zanata_entries}
        extra_in_weblate = [
            msgid for msgid in weblate_dict.keys()
            if msgid not in zanata_msgids
        ]

        weblate_extra_count = len(extra_in_weblate)
        if extra_in_weblate:
            print(
                f"[ERROR] {weblate_extra_count} entries in "
                f"Weblate but not in Zanata"
            )

            # show first 5 extra entries on weblate
            for msgid in extra_in_weblate[:5]:
                error_msg = f"Extra msgid on weblate: '{msgid[:50]}'"
                print(f"[ERROR] {error_msg}")

        if (mismatch_count == 0 and missing_count == 0 and
                weblate_extra_count == 0):
            print(
                f"[INFO] ✓ Sentence detail matched: "
                f"{len(zanata_entries)} entries"
            )
        else:
            print(
                "[ERROR] Sentence detail check "
                "completed with issues:"
            )
            if mismatch_count > 0:
                print(f"[ERROR]   - Mismatches: {mismatch_count}")
            if missing_count > 0:
                print(f"[ERROR]   - Missing in Weblate: {missing_count}")
            if weblate_extra_count > 0:
                print(f"[ERROR]   - Extra in Weblate: {weblate_extra_count}")

        return None


def setup_argument_parser():
    """Setup command line argument parser with subcommands."""
    parser = argparse.ArgumentParser(
        description='Weblate management utilities')
    subparser = parser.add_subparsers(
        dest='command', help='Available commands')
    # Create project command
    create_project_parser = subparser.add_parser(
        'create-project', help='Create a new project')
    create_project_parser.add_argument(
        '--project', required=True, help='Name of the project')
    # Create category command
    create_category_parser = subparser.add_parser(
        'create-category', help='Create a new category')
    create_category_parser.add_argument(
        '--project', required=True, help='Name of the project')
    create_category_parser.add_argument(
        '--category', required=True, help='Name of the category')
    # Create component command
    create_component_parser = subparser.add_parser(
        'create-component', help='Create a new component')
    create_component_parser.add_argument(
        '--project', required=True, help='Name of the project')
    create_component_parser.add_argument(
        '--category', required=True, help='Name of the category')
    create_component_parser.add_argument(
        '--component', required=True, help='Name of the component')
    create_component_parser.add_argument(
        '--pot-path', required=True, help='Path to the pot file')
    # Create glossary command
    create_glossary_parser = subparser.add_parser(
        'create-glossary', help='Create a new glossary')
    create_glossary_parser.add_argument(
        '--project', required=True, help='Name of the project')
    # Create translation command
    create_translation_parser = subparser.add_parser(
        'create-translation', help='Create a new translation')
    create_translation_parser.add_argument(
        '--project', required=True, help='Name of the project')
    create_translation_parser.add_argument(
        '--category', required=True, help='Name of the category')
    create_translation_parser.add_argument(
        '--component', required=True, help='Name of the component')
    create_translation_parser.add_argument(
        '--locale', required=True, help='Name of the locale')
    # Upload PO file command
    upload_po_file_parser = subparser.add_parser(
        'upload-po-file', help='Upload a new po file')
    upload_po_file_parser.add_argument(
        '--project', required=True, help='Name of the project')
    upload_po_file_parser.add_argument(
        '--category', required=True, help='Name of the category')
    upload_po_file_parser.add_argument(
        '--component', required=True, help='Name of the component')
    upload_po_file_parser.add_argument(
        '--locale', required=True, help='Name of the locale')
    upload_po_file_parser.add_argument(
        '--po-path', required=True, help='Path to po file')
    # Download translation file command
    download_translation_file_parser = subparser.add_parser(
        'download-translation-file',
        help='Download a translation file from Weblate')
    download_translation_file_parser.add_argument(
        '--project', required=True, help='Name of the project')
    download_translation_file_parser.add_argument(
        '--po-path', required=True, help='Path to po file')
    # Check sentence count command
    check_sentence_count_parser = subparser.add_parser(
        'check-sentence-count', help='Check the sentence count of the translation')
    check_sentence_count_parser.add_argument(
        '--project', required=True, help='Name of the project')
    check_sentence_count_parser.add_argument(
        '--category', required=True, help='Name of the category')
    check_sentence_count_parser.add_argument(
        '--component', required=True, help='Name of the component')
    check_sentence_count_parser.add_argument(
        '--locale', required=True, help='Name of the locale')
    check_sentence_count_parser.add_argument(
        '--zanata-po-path', required=True, help='Path to the zanata po file')
    check_sentence_count_parser.add_argument(
        '--weblate-po-path', required=True, help='Path to weblate po')
    check_sentence_count_parser.add_argument(
        '--result-json', required=False, help='Path to result JSON')
    # Check sentence detail command
    check_sentence_detail_parser = subparser.add_parser(
        'check-sentence-detail',
        help='Check the sentence detail of the translation')
    check_sentence_detail_parser.add_argument(
        '--project', required=True, help='Name of the project')
    check_sentence_detail_parser.add_argument(
        '--category', required=True, help='Name of the category')
    check_sentence_detail_parser.add_argument(
        '--component', required=True, help='Name of the component')
    check_sentence_detail_parser.add_argument(
        '--locale', required=True, help='Name of the locale')
    check_sentence_detail_parser.add_argument(
        '--zanata-po-path', required=True, help='Path to zanata po')
    check_sentence_detail_parser.add_argument(
        '--weblate-po-path', required=True, help='Path to weblate po')
    check_sentence_detail_parser.add_argument(
        '--result-json', required=False, help='Path to result JSON')
    return parser


def main():
    """Main entry point for the script."""
    try:
        config = WeblateConfig()

        parser = setup_argument_parser()
        args = parser.parse_args()

        if not args.command:
            parser.print_help()
            sys.exit(1)

        # Get result JSON path from args if available
        result_json_path = getattr(args, 'result_json', None)
        utils = WeblateUtils(config, result_json_path)

        if args.command == 'create-project':
            utils.create_project(args.project)
        elif args.command == 'create-category':
            utils.create_category(args.project, args.category)
        elif args.command == 'create-component':
            utils.create_component(
                args.project, args.category, args.component, args.pot_path)
        elif args.command == 'create-glossary':
            utils.create_glossary(args.project)
        elif args.command == 'create-translation':
            utils.create_translation(
                args.project, args.category, args.component, args.locale)
        elif args.command == 'upload-po-file':
            utils.upload_po_file(
                args.project, args.category, args.component, args.locale,
                args.po_path)
        elif args.command == 'download-translation-file':
            utils.download_translation_file(
                args.project, args.po_path)
        elif args.command == 'check-sentence-count':
            utils.check_sentence_count(
                args.project, args.category, args.component, args.locale,
                args.zanata_po_path, args.weblate_po_path)

        elif args.command == 'check-sentence-detail':
            utils.check_sentence_detail(
                args.project, args.category, args.component, args.locale,
                args.zanata_po_path, args.weblate_po_path)
        else:
            parser.print_help()
            sys.exit(1)
    except Exception as e:
        print(f"[ERROR] Failed to migrate: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()
