#!/usr/bin/env python3
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

"""
Weblate Plural Extractor

이 도구는 Weblate API를 사용하여 모든 언어의 plural 정보를 추출합니다.
추출된 정보는 JSON 형태로 저장되며, 각 언어의 plural 규칙과 메타데이터를 포함합니다.

사용법:
    python weblate_plural_extractor.py [옵션]

옵션:
    --url URL         Weblate API URL (기본값: https://openstack.weblate.cloud/api/)
    --output FILE     출력 파일 경로 (기본값: weblate_plurals.json)
    --format FORMAT   출력 형식: json, csv (기본값: json)
    --verbose         상세한 출력
    --help            도움말 표시

예시:
    python weblate_plural_extractor.py
    python weblate_plural_extractor.py --url https://my-weblate.com/api/ --output plurals.json
    python weblate_plural_extractor.py --format csv --verbose
"""

import argparse
import json
import csv
import sys
import requests
from datetime import datetime
from typing import Dict, List, Any, Optional
from urllib.parse import urljoin


class WeblatePluralExtractor:
    """Weblate API를 사용하여 언어별 plural 정보를 추출하는 클래스"""
    
    def __init__(self, base_url: str = "https://openstack.weblate.cloud/api/", 
                 verbose: bool = False, local_file: Optional[str] = None):
        """
        초기화
        
        Args:
            base_url: Weblate API 기본 URL
            verbose: 상세 출력 여부
            local_file: 로컬 JSON 파일 경로 (API 대신 사용)
        """
        self.base_url = base_url.rstrip('/') + '/'
        self.verbose = verbose
        self.local_file = local_file
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': 'Weblate-Plural-Extractor/1.0',
            'Accept': 'application/json'
        })
    
    def _log(self, message: str) -> None:
        """로그 메시지 출력"""
        if self.verbose:
            print(f"[INFO] {message}")
    
    def _make_request(self, endpoint: str, params: Optional[Dict] = None) -> Dict[str, Any]:
        """
        API 요청 실행
        
        Args:
            endpoint: API 엔드포인트
            params: 요청 매개변수
            
        Returns:
            API 응답 데이터
            
        Raises:
            requests.RequestException: API 요청 실패 시
        """
        url = urljoin(self.base_url, endpoint)
        self._log(f"Requesting: {url}")
        
        try:
            response = self.session.get(url, params=params, timeout=30)
            response.raise_for_status()
            return response.json()
        except requests.RequestException as e:
            raise requests.RequestException(f"API 요청 실패: {e}")
    
    def get_all_languages(self) -> List[Dict[str, Any]]:
        """
        모든 언어 정보 가져오기
        
        Returns:
            언어 정보 리스트
        """
        # 로컬 파일이 지정된 경우 파일에서 읽기
        if self.local_file:
            self._log(f"로컬 파일에서 언어 정보를 읽는 중: {self.local_file}")
            try:
                with open(self.local_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                
                if 'results' in data:
                    languages = data['results']
                else:
                    languages = [data] if isinstance(data, dict) else data
                
                self._log(f"총 {len(languages)}개 언어 정보를 로컬 파일에서 읽었습니다.")
                return languages
            except Exception as e:
                raise Exception(f"로컬 파일 읽기 실패: {e}")
        
        # API에서 가져오기
        self._log("API에서 모든 언어 정보를 가져오는 중...")
        
        all_languages = []
        next_url = "languages/"
        
        while next_url:
            if next_url.startswith('http'):
                # 절대 URL인 경우
                url = next_url
            else:
                # 상대 URL인 경우
                url = urljoin(self.base_url, next_url)
            
            self._log(f"Fetching: {url}")
            
            try:
                response = self.session.get(url, timeout=30)
                response.raise_for_status()
                data = response.json()
                
                if 'results' in data:
                    all_languages.extend(data['results'])
                    next_url = data.get('next')
                else:
                    # 단일 결과인 경우
                    all_languages.append(data)
                    next_url = None
                    
            except requests.RequestException as e:
                raise requests.RequestException(f"언어 정보 가져오기 실패: {e}")
        
        self._log(f"총 {len(all_languages)}개 언어 정보를 API에서 가져왔습니다.")
        return all_languages
    
    def extract_plural_info(self, languages: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        언어 정보에서 plural 정보 추출
        
        Args:
            languages: 언어 정보 리스트
            
        Returns:
            plural 정보가 포함된 언어 리스트
        """
        self._log("Plural 정보를 추출하는 중...")
        
        plural_info = []
        
        for lang in languages:
            # 기본 정보 추출
            lang_info = {
                'code': lang.get('code', ''),
                'name': lang.get('name', ''),
                'id': lang.get('id'),
                'direction': lang.get('direction', 'ltr'),
                'population': lang.get('population'),
                'aliases': lang.get('aliases', []),
                'web_url': lang.get('web_url', ''),
                'api_url': lang.get('url', ''),
                'statistics_url': lang.get('statistics_url', '')
            }
            
            # Plural 정보 추출
            plural_data = lang.get('plural', {})
            if plural_data:
                lang_info['plural'] = {
                    'id': plural_data.get('id'),
                    'source': plural_data.get('source'),
                    'number': plural_data.get('number'),
                    'formula': plural_data.get('formula', ''),
                    'type': plural_data.get('type')
                }
                
                # Plural forms 문자열 생성
                if plural_data.get('number') and plural_data.get('formula'):
                    plural_forms = f"nplurals={plural_data['number']}; plural={plural_data['formula']}"
                    lang_info['plural_forms'] = plural_forms
                else:
                    lang_info['plural_forms'] = None
            else:
                lang_info['plural'] = None
                lang_info['plural_forms'] = None
            
            plural_info.append(lang_info)
        
        self._log(f"Plural 정보 추출 완료: {len(plural_info)}개 언어")
        return plural_info
    
    def save_to_json(self, data: List[Dict[str, Any]], filename: str) -> None:
        """
        JSON 파일로 저장
        
        Args:
            data: 저장할 데이터
            filename: 파일명
        """
        self._log(f"JSON 파일로 저장 중: {filename}")
        
        output_data = {
            'metadata': {
                'source': 'Weblate API' if not self.local_file else 'Local File',
                'api_url': self.base_url if not self.local_file else None,
                'local_file': self.local_file if self.local_file else None,
                'total_languages': len(data),
                'extracted_at': datetime.now().isoformat()
            },
            'languages': data
        }
        
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(output_data, f, ensure_ascii=False, indent=2)
        
        self._log(f"JSON 파일 저장 완료: {filename}")
    
    def save_to_csv(self, data: List[Dict[str, Any]], filename: str) -> None:
        """
        CSV 파일로 저장
        
        Args:
            data: 저장할 데이터
            filename: 파일명
        """
        self._log(f"CSV 파일로 저장 중: {filename}")
        
        if not data:
            self._log("저장할 데이터가 없습니다.")
            return
        
        # CSV 헤더 정의
        fieldnames = [
            'code', 'name', 'id', 'direction', 'population',
            'aliases', 'web_url', 'api_url', 'statistics_url',
            'plural_id', 'plural_source', 'plural_number', 
            'plural_formula', 'plural_type', 'plural_forms'
        ]
        
        with open(filename, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            
            for lang in data:
                row = {
                    'code': lang.get('code', ''),
                    'name': lang.get('name', ''),
                    'id': lang.get('id', ''),
                    'direction': lang.get('direction', ''),
                    'population': lang.get('population', ''),
                    'aliases': '; '.join(lang.get('aliases', [])),
                    'web_url': lang.get('web_url', ''),
                    'api_url': lang.get('api_url', ''),
                    'statistics_url': lang.get('statistics_url', ''),
                    'plural_id': lang.get('plural', {}).get('id', '') if lang.get('plural') else '',
                    'plural_source': lang.get('plural', {}).get('source', '') if lang.get('plural') else '',
                    'plural_number': lang.get('plural', {}).get('number', '') if lang.get('plural') else '',
                    'plural_formula': lang.get('plural', {}).get('formula', '') if lang.get('plural') else '',
                    'plural_type': lang.get('plural', {}).get('type', '') if lang.get('plural') else '',
                    'plural_forms': lang.get('plural_forms', '')
                }
                writer.writerow(row)
        
        self._log(f"CSV 파일 저장 완료: {filename}")
    
    def extract_and_save(self, output_file: str, output_format: str = 'json') -> None:
        """
        Plural 정보 추출 및 저장
        
        Args:
            output_file: 출력 파일명
            output_format: 출력 형식 ('json' 또는 'csv')
        """
        try:
            # 모든 언어 정보 가져오기
            languages = self.get_all_languages()
            
            # Plural 정보 추출
            plural_data = self.extract_plural_info(languages)
            
            # 파일로 저장
            if output_format.lower() == 'csv':
                self.save_to_csv(plural_data, output_file)
            else:
                self.save_to_json(plural_data, output_file)
            
            print(f"✅ 성공적으로 {len(plural_data)}개 언어의 plural 정보를 {output_file}에 저장했습니다.")
            
            # 통계 정보 출력
            languages_with_plural = sum(1 for lang in plural_data if lang.get('plural'))
            print(f"📊 통계:")
            print(f"   - 총 언어 수: {len(plural_data)}")
            print(f"   - Plural 정보가 있는 언어: {languages_with_plural}")
            print(f"   - Plural 정보가 없는 언어: {len(plural_data) - languages_with_plural}")
            
            # 소스 정보 출력
            if self.local_file:
                print(f"   - 데이터 소스: 로컬 파일 ({self.local_file})")
            else:
                print(f"   - 데이터 소스: API ({self.base_url})")
            
        except Exception as e:
            print(f"❌ 오류 발생: {e}")
            sys.exit(1)


def main():
    """메인 함수"""
    parser = argparse.ArgumentParser(
        description='Weblate API를 사용하여 모든 언어의 plural 정보를 추출합니다.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    
    parser.add_argument(
        '--url',
        default='https://openstack.weblate.cloud/api/',
        help='Weblate API URL (기본값: https://openstack.weblate.cloud/api/)'
    )
    
    parser.add_argument(
        '--output', '-o',
        default='weblate_plurals.json',
        help='출력 파일 경로 (기본값: weblate_plurals.json)'
    )
    
    parser.add_argument(
        '--format', '-f',
        choices=['json', 'csv'],
        default='json',
        help='출력 형식 (기본값: json)'
    )
    
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        help='상세한 출력'
    )
    
    parser.add_argument(
        '--local-file', '-l',
        help='로컬 JSON 파일 경로 (API 대신 사용)'
    )
    
    args = parser.parse_args()
    
    # 출력 파일 확장자 자동 설정
    if not args.output.endswith(('.json', '.csv')):
        if args.format == 'csv':
            args.output += '.csv'
        else:
            args.output += '.json'
    
    print("🌐 Weblate Plural Extractor")
    if args.local_file:
        print(f"📄 로컬 파일: {args.local_file}")
    else:
        print(f"📡 API URL: {args.url}")
    print(f"📁 출력 파일: {args.output}")
    print(f"📋 출력 형식: {args.format.upper()}")
    print()
    
    # Extractor 인스턴스 생성 및 실행
    extractor = WeblatePluralExtractor(args.url, args.verbose, args.local_file)
    extractor.extract_and_save(args.output, args.format)


if __name__ == "__main__":
    main()
