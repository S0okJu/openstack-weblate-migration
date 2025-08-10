#!/usr/bin/env python3
"""
Convert POT files to the required format for Weblate.
"""

import sys
import os
import glob
import re

def translate_text(text):
    """Simple translation function - you can replace this with actual translation logic."""
    # For now, we'll just copy the msgid to msgstr as a placeholder
    # In a real implementation, you would call a translation service here
    return text

def extract_multiline_string(lines, start_index):
    """Extract a multiline string from lines starting at start_index."""
    if start_index >= len(lines):
        return "", start_index
    
    line = lines[start_index]
    if not line.startswith('"'):
        return "", start_index
    
    # Extract the first line
    result = line[1:]  # Remove opening quote
    i = start_index + 1
    
    # Continue reading lines until we find the closing quote
    while i < len(lines):
        line = lines[i]
        if line.endswith('"'):
            # This line ends the string
            result += line[:-1]  # Remove closing quote
            break
        else:
            # This line continues the string
            result += '\n' + line
        i += 1
    
    return result, i

def convert_pot_file(pot_file):
    """Convert a single POT file by adding translations to msgstr."""
    print(f"Converting {pot_file}...")
    
    try:
        with open(pot_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Split content into lines
        lines = content.split('\n')
        new_lines = []
        i = 0
        
        while i < len(lines):
            line = lines[i]
            
            # Check if this is a msgid line
            if line.startswith('msgid '):
                # Extract msgid text
                msgid_text = line[6:]  # Remove 'msgid ' prefix
                
                # Handle multiline msgid
                if msgid_text.startswith('"') and not msgid_text.endswith('"'):
                    # Multiline msgid
                    msgid_content, next_i = extract_multiline_string(lines, i)
                    msgid_text = msgid_content
                    i = next_i
                else:
                    # Single line msgid
                    msgid_text = msgid_text.strip('"')
                
                # Skip if this is an empty msgid and we already have one
                if msgid_text == "" and new_lines and new_lines[-1].startswith('msgid ""'):
                    i += 1
                    continue
                
                # Skip if this msgid is already added (for plural forms)
                if new_lines and new_lines[-1].startswith(f'msgid "{msgid_text}"'):
                    i += 1
                    continue
                
                # Skip if the next line is also msgid (duplicate)
                if i + 1 < len(lines) and lines[i + 1].startswith('msgid '):
                    i += 1
                    continue
                
                # Add the msgid line (원본 형식 유지)
                if msgid_text == "":
                    new_lines.append('msgid ""')
                else:
                    new_lines.append(f'msgid "{msgid_text}"')
                
                # Look for the corresponding msgstr
                if i < len(lines) - 1 and lines[i + 1].startswith('msgstr ""'):
                    # Found empty msgstr, replace with translation
                    i += 1  # Skip the empty msgstr line
                    translated_text = translate_text(msgid_text)
                    new_lines.append(f'msgstr "{translated_text}"')
                    print(f"    Translated: {msgid_text[:50]}... -> {translated_text[:50]}...")
                else:
                    # Add the original msgstr line if it's not empty
                    if i < len(lines):
                        new_lines.append(lines[i])
            else:
                # Add non-msgid lines as they are
                new_lines.append(line)
            
            i += 1
        
        # Write the converted content back to the file
        with open(pot_file, 'w', encoding='utf-8') as f:
            f.write('\n'.join(new_lines))
        
        print(f"    Successfully converted {pot_file}")
        
    except Exception as e:
        print(f"    Error converting {pot_file}: {e}")
        import traceback
        traceback.print_exc()

def convert_pot_files(project_name):
    """Convert POT files for the given project."""
    print(f"Converting POT files for project: {project_name}")
    
    # Check if locale directory exists
    locale_dir = f"{project_name}/locale"
    if not os.path.exists(locale_dir):
        print(f"Locale directory {locale_dir} does not exist")
        return
    
    # Find all POT files
    pot_files = glob.glob(f"{locale_dir}/*.pot")
    
    if not pot_files:
        print("No POT files found to convert")
        return
    
    print(f"Found {len(pot_files)} POT files:")
    for pot_file in pot_files:
        print(f"  - {pot_file}")
        # Here you can add specific conversion logic if needed
        # For now, we'll just verify the files exist and are readable
        try:
            with open(pot_file, 'r', encoding='utf-8') as f:
                content = f.read()
                print(f"    File size: {len(content)} characters")
        except Exception as e:
            print(f"    Error reading file: {e}")
    
    # Convert each POT file
    for pot_file in pot_files:
        convert_pot_file(pot_file)

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 convert.py <project_name>")
        sys.exit(1)
    
    project_name = sys.argv[1]
    convert_pot_files(project_name)

if __name__ == "__main__":
    main()
