#!/usr/bin/env python3
"""
Script to update the Language field in PO files with the correct Weblate locale code.
Usage: python language.py <weblate_locale> <po_file>
"""

import sys
import re
import os

def update_language_field(weblate_locale, po_file):
    """
    Update the Language field in a PO file with the specified Weblate locale.
    
    Args:
        weblate_locale (str): The Weblate locale code to set
        po_file (str): Path to the PO file to update
    """
    
    # Check if PO file exists
    if not os.path.exists(po_file):
        print(f"Error: PO file '{po_file}' does not exist.")
        return False
    
    try:
        # Read the PO file
        with open(po_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Pattern to match "Language: " followed by any text
        # This will match both "Language: en\n" and "Language: \n" cases
        language_pattern = r'^("Language: ).*?(\n")'
        
        # Check if Language field exists
        if 'Language:' not in content:
            print(f"Warning: No 'Language:' field found in {po_file}")
            return False
        
        # Replace the Language field
        new_content = re.sub(language_pattern, r'\1' + weblate_locale + r'\2', content, flags=re.MULTILINE)
        
        # Check if any changes were made
        if new_content == content:
            print(f"No changes needed for {po_file} (Language already set to '{weblate_locale}')")
            return True
        
        # Write the updated content back to the file
        with open(po_file, 'w', encoding='utf-8') as f:
            f.write(new_content)
        
        print(f"Successfully updated {po_file} - Language set to '{weblate_locale}'")
        return True
        
    except Exception as e:
        print(f"Error updating {po_file}: {str(e)}")
        return False

def main():
    """Main function to handle command line arguments and execute the update."""
    
    if len(sys.argv) != 3:
        print("Usage: python language.py <weblate_locale> <po_file>")
        print("Example: python language.py zh_Hans locale/zh_CN/LC_MESSAGES/django.po")
        sys.exit(1)
    
    weblate_locale = sys.argv[1]
    po_file = sys.argv[2]
    
    print(f"Updating Language field in {po_file} to '{weblate_locale}'...")
    
    success = update_language_field(weblate_locale, po_file)
    
    if success:
        print("Language field update completed successfully.")
        sys.exit(0)
    else:
        print("Language field update failed.")
        sys.exit(1)

if __name__ == "__main__":
    main()
