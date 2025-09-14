#!/usr/bin/env python3
import polib
import os
import sys
import glob
from pathlib import Path

from weblate_plural_rules import PLURAL_RULES

def get_plural_rule(lang_code):
    """
    Get the plural rule for a given language code.
    If the language code is a compound code(e.g. ko_KR), use the first part.
    
    Args:
        lang_code: The language code to get the plural rule for
    Returns:
        The plural rule for the given language code
    """
    
    exceptions = ['pt_BR']
    if lang_code in exceptions:
        return PLURAL_RULES[lang_code]
    
    keywords = lang_code.split(sep='_')
    if keywords[0] in PLURAL_RULES:
        return PLURAL_RULES[keywords[0]]
    else:
        raise ValueError(f"Plural does not exist: {lang_code}")

def fix_plural_forms(po_file_path, language_code):
    """
    Fix the plural forms in a PO file.
    If the language code is a compound code(e.g. ko_KR), use the first part.
    
    Args:
        po_file_path: The path to the PO file
        language_code: The language code to fix the plural forms for
    Returns:
        None
    """
    try:
        po = polib.pofile(po_file_path)
        
        current_plural = po.metadata.get('Plural-Forms', '')
        
        try:
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