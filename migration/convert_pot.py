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

import os
import polib
import sys


def convert_pot_file(pot_file):
    """Convert a single POT file by copying msgid content to msgstr."""
    print(f"Converting {pot_file}...")

    try:
        po = polib.pofile(pot_file)
        changes_made = 0

        for entry in po:
            if not entry.msgid:
                continue

            entry.msgstr = entry.msgid
            changes_made += 1

        po.save(pot_file)
    except Exception as e:
        print(f"    Error converting {pot_file}: {e}")
        import traceback
        traceback.print_exc()


def convert_pot_files(pot_file_path):
    """Convert a single POT file."""
    print(f"Converting POT file: {pot_file_path}")

    if not os.path.exists(pot_file_path):
        print(f"POT file {pot_file_path} does not exist")
        return

    convert_pot_file(pot_file_path)


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 polib.py <pot_file_path>")
        print("  Converts POT files by copying msgid content to msgstr")
        sys.exit(1)

    pot_file_path = sys.argv[1]
    convert_pot_files(pot_file_path)


if __name__ == "__main__":
    main()
