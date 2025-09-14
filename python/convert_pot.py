#!/usr/bin/env python3
"""
Convert POT files by copying msgid content to msgstr using polib.
"""

import sys
import os
import glob
import polib
from pathlib import Path

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

def convert_pot_files(pot_file_path):
    """Convert a single POT file."""
    print(f"Converting POT file: {pot_file_path}")
    
    if not os.path.exists(pot_file_path):
        print(f"POT file {pot_file_path} does not exist")
        return
    
    # Convert the POT file
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