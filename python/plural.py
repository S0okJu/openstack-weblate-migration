#!/usr/bin/env python3
"""
PO 파일의 복수형 규칙을 CLDR 데이터 기반으로 자동 수정하는 스크립트
사용법: python3 plural.py <language_code> <po_file_path>
"""

import polib
import os
import sys
import glob
from pathlib import Path
from weblate_plural_rules import PLURAL_RULES

def get_language(file_path):
    """파일 경로에서 언어 코드 추출"""
    path_parts = Path(file_path).parts
    for part in path_parts:
        if len(part) == 2 or len(part) == 5:  # 'ko' 또는 'ko_KR'
            lang_code = part
            
            # 복합 언어 코드인 경우 첫 번째 부분만 사용
            if '_' in lang_code:
                primary_lang = lang_code.split('_')[0]
                print(f"  - 복합 언어 코드 감지: {lang_code} → {primary_lang} 사용")
                return primary_lang
            
            return lang_code
    return None

def fix_plural_forms_in_po_file(po_file_path, language_code):
    """PO 파일의 복수형 규칙을 수정"""
    try:
        # PO 파일 로드
        po = polib.pofile(po_file_path)
        
        # 현재 복수형 규칙 확인
        current_plural_forms = po.metadata.get('Plural-Forms', '')
        
        # 언어 코드에 맞는 복수형 규칙 가져오기
        if language_code in PLURAL_RULES:
            new_plural_forms = PLURAL_RULES[language_code]
        else:
            # 언어 코드가 없으면 기본값 사용
            new_plural_forms = PLURAL_RULES['default']
            print(f"  ⚠️  언어 코드 '{language_code}'에 대한 규칙이 없어 기본값 사용")
        
        # 복수형 규칙이 다르면 업데이트
        if current_plural_forms != new_plural_forms:
            po.metadata['Plural-Forms'] = new_plural_forms
            po.save()
            print(f"  ✅ 복수형 규칙 업데이트: {current_plural_forms} → {new_plural_forms}")
            return True
        else:
            print(f"  ℹ️  복수형 규칙이 이미 올바름: {current_plural_forms}")
            return False
            
    except Exception as e:
        print(f"  ❌ 오류 발생: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("사용법: python3 plural.py <language_code> <po_file_path>")
        sys.exit(1)
        
    language_code = sys.argv[1]
    po_file_path = sys.argv[2]
       
    fix_plural_forms_in_po_file(po_file_path, language_code)