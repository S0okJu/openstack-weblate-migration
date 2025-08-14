#!/usr/bin/env python3
"""
Convert POT files by copying msgid content to msgstr using polib.
"""

import sys
import os
import glob
import polib

def convert_pot_file(pot_file):
    """Convert a single POT file by copying msgid content to msgstr."""
    print(f"Converting {pot_file}...")
    
    try:
        # Load the POT file using polib
        po = polib.pofile(pot_file)
        
        # Track changes
        changes_made = 0
        
        # Process each entry
        for entry in po:
            # Skip empty msgids (usually header entries)
            if not entry.msgid:
                continue
            
            # Copy msgid content to msgstr
            entry.msgstr = entry.msgid
            changes_made += 1
            
            print(f"    Copied: {entry.msgid[:50]}... -> {entry.msgstr[:50]}...")
        
        # Save the modified POT file
        po.save(pot_file)
        
        print(f"    Successfully converted {pot_file} ({changes_made} entries copied)")
        
    except Exception as e:
        print(f"    Error converting {pot_file}: {e}")
        import traceback
        traceback.print_exc()

def convert_pot_files(project_name):
    """Convert POT files for the given project."""
    print(f"Converting POT files for project: {project_name}")
    
    locale_dir = f"{project_name}/locale"
    print(f"Looking for locale directory: {locale_dir}")
    if not os.path.exists(locale_dir):
        print(f"Locale directory {locale_dir} does not exist")
        return
    print(f"Locale directory found: {locale_dir}")
    
    # Find all POT files
    pot_files = glob.glob(f"{locale_dir}/*.pot")
    
    if not pot_files:
        print("No POT files found to convert")
        return
    
    print(f"Found {len(pot_files)} POT files:")
    for pot_file in pot_files:
        print(f"  - {pot_file}")
        try:
            po = polib.pofile(pot_file)
            print(f"    File contains {len(po)} entries")
            print(f"    Translated entries: {len([e for e in po if e.msgstr])}")
            print(f"    Untranslated entries: {len([e for e in po if not e.msgstr and e.msgid])}")
        except Exception as e:
            print(f"    Error reading file: {e}")
    
    # Convert each POT file
    for pot_file in pot_files:
        convert_pot_file(pot_file)

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 convert.py <project_name>")
        print("  Converts POT files by copying msgid content to msgstr")
        sys.exit(1)
    
    project_name = sys.argv[1]
    convert_pot_files(project_name)

if __name__ == "__main__":
    main()
