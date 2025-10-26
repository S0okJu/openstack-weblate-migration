# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import polib
import sys

from weblate_plural_rules import WEBLATE_PLURAL_RULES
# from zanata_plural_rules import ZANATA_PLURAL_RULES


def get_plural_rule(lang_code: str) -> str:
    """Get the plural rule for a given language code.

    If the language code is a compound code (e.g. ko_KR), use the first part.

    :param lang_code: The language code to get the plural rule for
    :raises ValueError: If the language code is not found in the PLURAL_RULES
    :returns: The plural rule for the given language code
    """
    # Handle special cases
    exceptions = ['pt_BR']
    if lang_code in exceptions:
        return WEBLATE_PLURAL_RULES[lang_code]

    # Extract base language code (e.g., 'ko' from 'ko_KR')
    base_lang = lang_code.split('_')[0]
    if base_lang in WEBLATE_PLURAL_RULES:
        return WEBLATE_PLURAL_RULES[base_lang]

    raise ValueError(f"Plural rule not found for language: {lang_code}")


def fix_plural_forms(po_file_path, language_code):
    """Fix the plural forms in a PO file.

    If the language code is a compound code (e.g. ko_KR), use the first part.

    :param po_file_path: The path to the PO file
    :param language_code: The language code to fix the plural forms for
    """
    try:
        po = polib.pofile(po_file_path)

        current_plural = po.metadata.get('Plural-Forms', '')
        new_plural_forms = get_plural_rule(language_code)

        if current_plural != new_plural_forms:
            po.metadata['Plural-Forms'] = new_plural_forms
            po.save()
            print(f"Updated: {current_plural} → {new_plural_forms}")
        else:
            print(f"Skipped: {current_plural}")
    except ValueError as e:
        print(f"Warning: {e}")
    except Exception as e:
        print(f"Error: {e}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(1)

    language_code = sys.argv[1]
    po_file_path = sys.argv[2]

    fix_plural_forms(po_file_path, language_code)
