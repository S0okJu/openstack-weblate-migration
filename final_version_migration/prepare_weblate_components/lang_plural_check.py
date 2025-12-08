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

import polib
import sys

from zanata_plural_rules import ZANATA_LANG_RULES


def check_lang_exist(lang_code: str) -> bool:
    """Check if the language code exists in ZANATA_LANG_RULES."""
    if lang_code not in ZANATA_LANG_RULES:
        return False

    if lang_code in ZANATA_LANG_RULES[lang_code]['region_code']:
        return True
    
    return False
    

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 lang_plural_check.py <po_file_path>")
        sys.exit(1)

    po_file_path = sys.argv[1]
    po = polib.pofile(po_file_path)

    po_lang_data = po.metadata['Language']
    
    # The language code is lowercase.
    # But in some cases, for example,
    # Thai(Th) is mixed with upper case.
    # So we need to normalize the language code to lowercase.
    lang_code = po_lang_data.split('_')[0].lower()

    # If the language code contains a region code (e.g., en_US),
    # convert the language part to lowercase and region part to uppercase.
    parts = po_lang_data.split('_')
    converted_lang_code=""
    if len(parts) == 2:
        converted_lang_code = f"{parts[0].lower()}_{parts[1].upper()}"
    else:
        converted_lang_code = lang_code
    
    print(f"[INFO] Check {lang_code} validation...")    
    is_exist = check_lang_exist(converted_lang_code)
    if not is_exist:
        print(f"[ERROR] {converted_lang_code} is invalid")

    print(f"[INFO] Convert {po_lang_data} to {converted_lang_code}")
    po.metadata['Language'] = converted_lang_code

    # Compare plural rules
    expected_plurals = ZANATA_LANG_RULES[lang_code]['plurals']
    current_plurals = po.metadata['Plural-Forms']
    if expected_plurals != current_plurals:
        print(
            f"[INFO] Change plural rules from {current_plurals} "
            f"to {expected_plurals}"
        )
        po.metadata['Plural-Forms'] = expected_plurals

    po.save(po_file_path)
    print(f"[INFO] Saved {po_file_path} with new metadata")


if __name__ == "__main__":
    main()
