#!/usr/bin/env python3
"""
Zanata to Weblate language mapping dictionary
This file contains the mapping between Zanata localeId and Weblate language codes
"""

import sys
    
ZANATA_TO_WEBLATE_MAPPING = {
    "sq": "sq",
    "ar": "ar",
    "as": "as",
    "bn-IN": "bn_IN",
    "brx": "brx",
    "bg-BG": "bg",
    "ca": "ca",
    "zh-CN": "zh_Hans", # !NOTICE
    "zh-TW": "zh_Hant",
    "cs": "cs",
    "nl-NL": "nl",
    "en-AU": "en_AU",
    "en-GB": "en_GB",
    "en-US": "en_US",
    "eo": "eo",
    "fil": "fil",
    "fi-FI": "fi",
    "fr": "fr",
    "ka-GE": "ka",
    "de": "de",
    "el": "el",
    "gu": "gu",
    "he": "he",
    "hi": "hi",
    "hu": "hu",
    "id": "id",
    "it": "it",
    "ja": "ja",
    "kn": "kn",
    "ks": "ks",
    "kok": "kok",
    "ko-KR": "ko",
    "lo": "lo",
    "mai": "mai",
    "mni": "mni",
    "mr": "mr",
    "ne": "ne",
    "fa": "fa",
    "pl-PL": "pl",
    "pt": "pt",
    "pt-BR": "pt_BR",
    "pa-IN": "pa",
    "Ro": "ro",
    "ru": "ru",
    "sr": "sr",
    "sl-SI": "sl",
    "es": "es",
    "es-MX": "es_MX",
    "ta": "ta",
    "te-IN": "te",
    "Th": "th",
    "tr-TR": "tr",
    "ur": "ur",
    "vi-VN": "vi"
}

def get_migration_info(zanata_locale_id):
    """Get complete migration information for a Zanata localeId"""
    return ZANATA_TO_WEBLATE_MAPPING.get(zanata_locale_id)

# Main function
if __name__ == "__main__":
    if len(sys.argv) > 1:
        zanata_code = sys.argv[1]
        lang_info = get_migration_info(zanata_code)
        
        if lang_info:
            # zanata code를 입력하면 weblate code만 반환
            print(lang_info)
        else:
            print(f"Unknown language code: {zanata_code}")
            sys.exit(1)
    else:
        print("Usage: python3 language_mapping.py <zanata_code>")
        print("Example: python3 language_mapping.py ko-KR")
        print("Output: ko")
