import json
from zanata_plural_rules import ZANATA_PLURAL_RULES
class PluralParser:
    def __init__(self, filename: str = 'weblate_languages.json'):
        self.languages_list = self._read(filename)

    def _read(self, filename: str):
        
        with open(filename, 'r') as f:
            results = json.load(f)['results']
            return {lang['code']: lang for lang in results}
    
    def _get_plural_forms(self, lang_code: str):
        # Zanata -> Weblate 언어 코드 매핑
        lang_mapping = {
            "me": "cnr",      # Montenegrin
            "zh": "zh_Hans"   # Chinese (Simplified)
        }
        
        # 매핑이 필요한 경우 변환
        if lang_code in lang_mapping:
            lang_code = lang_mapping[lang_code]
            
        plural = self.languages_list[lang_code]['plural']
        
        return f"nplurals={plural['number']}; plural={plural['formula']};"
    
    def make_plural_rules(self, lang_code_list: list):
        rules = {}
        for lang_code in lang_code_list:
            plural_forms = self._get_plural_forms(lang_code)
            rules[lang_code] = plural_forms
        
        with open('weblate_plural_rules.py', 'w') as f:
            for lang_code in sorted(rules.keys()):
                f.write(f"    '{lang_code}': '{rules[lang_code]}',\n")
            f.write("}\n")

def get_zanata_rules():
    rules = []
    for lang, _ in ZANATA_PLURAL_RULES.items():
        rules.append(lang)
    return rules

if __name__ == "__main__":
    parser = PluralParser()
    zanata_rules = get_zanata_rules()    
    parser.make_plural_rules(zanata_rules)
