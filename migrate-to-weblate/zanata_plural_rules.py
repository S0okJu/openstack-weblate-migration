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

"""Plural rules extracted from Zanata.

Ref: https://github.com/zanata/zanata-platform/blob/master/server/services/
src/main/resources/pluralforms.properties
"""

ZANATA_LANG_RULES = {
    'ach': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n > 1)'
    },
    'af': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'ak': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n > 1)'
    },
    'am': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n > 1)'
    },
    'an': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'anp': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'ar': {
        'region_code': [],
        'plurals': 'nplurals=6; plural= n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 : n%100>=11 ? 4 : 5;'
    },
    'arn': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n > 1)'
    },
    'as': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'ast': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'ay': {
        'region_code': [],
        'plurals': 'nplurals=1; plural=0'
    },
    'az': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'be': {
        'region_code': [],
        'plurals': 'nplurals=3; plural=(n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2)'
    },
    'bg': {
        'region_code': 'bg_BG',
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'bn': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'bo': {
        'region_code': [],
        'plurals': 'nplurals=1; plural=0'
    },
    'br': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n > 1)'
    },
    'brx': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'bs': {
        'region_code': [],
        'plurals': 'nplurals=3; plural=(n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2)'
    },
    'ca': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'cgg': {
        'region_code': [],
        'plurals': 'nplurals=1; plural=0'
    },
    'cs': {
        'region_code': [],
        'plurals': 'nplurals=3; plural=(n==1) ? 0 : (n>=2 && n<=4) ? 1 : 2'
    },
    'csb': {
        'region_code': [],
        'plurals': 'nplurals=3; n==1 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2'
    },
    'cy': {
        'region_code': [],
        'plurals': 'nplurals=4; plural= (n==1) ? 0 : (n==2) ? 1 : (n != 8 && n != 11) ? 2 : 3'
    },
    'da': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'de': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'doi': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'dz': {
        'region_code': [],
        'plurals': 'nplurals=1; plural=0'
    },
    'el': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'en': {
        'region_code': ['en_US', 'en_GB', 'en_AU'],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'eo': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'es': {
        'region_code': ['es', 'ex_MX'],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'et': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'eu': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'fa': {
        'region_code': [],
        'plurals': 'nplurals=1; plural=0'
    },
    'fi': {
        'region_code': ['fi_FI'],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'fil': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=n > 1'
    },
    'fo': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'fr': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n > 1)'
    },
    'fur': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'fy': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'ga': {
        'region_code': [],
        'plurals': 'nplurals=5; plural=n==1 ? 0 : n==2 ? 1 : n<7 ? 2 : n<11 ? 3 : 4'
    },
    'gd': {
        'region_code': [],
        'plurals': 'nplurals=4; plural=(n==1 || n==11) ? 0 : (n==2 || n==12) ? 1 : (n > 2 && n < 20) ? 2 : 3'
    },
    'gl': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'gu': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'gun': {
        'region_code': [],
        'plurals': 'nplurals=2; plural = (n > 1)'
    },
    'ha': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'he': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'hi': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'hne': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'hy': {
        'region_code': [],
        'plurals': 'nplurals=1; plural=0'
    },
    'hr': {
        'region_code': [],
        'plurals': 'nplurals=3; plural=(n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2)'
    },
    'hu': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'ia': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'id': {
        'region_code': [],
        'plurals': 'nplurals=1; plural=0'
    },
    'is': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n%10!=1 || n%100==11)'
    },
    'it': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'ja': {
        'region_code': [],
        'plurals': 'nplurals=1; plural=0'
    },
    'jbo': {
        'region_code': [],
        'plurals': 'nplurals=1; plural=0'
    },
    'jv': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=n!=0'
    },
    'ka': {
        'region_code': ['ka_GE'],
        'plurals': 'nplurals=1; plural=0'
    },
    'kk': {
        'region_code': [],
        'plurals': 'nplurals=1; plural=0'
    },
    'km': {
        'region_code': [],
        'plurals': 'nplurals=1; plural=0'
    },
    'kn': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n!=1)'
    },
    'ko': {
        'region_code': ['ko_KR'],
        'plurals': 'nplurals=1; plural=0'
    },
    'kok': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'ks': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'ku': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n!= 1)'
    },
    'kw': {
        'region_code': [],
        'plurals': 'nplurals=4; plural= (n==1) ? 0 : (n==2) ? 1 : (n == 3) ? 2 : 3'
    },
    'ky': {
        'region_code': [],
        'plurals': 'nplurals=1; plural=0'
    },
    'lb': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'ln': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=n>1;'
    },
    'lo': {
        'region_code': [],
        'plurals': 'nplurals=1; plural=0'
    },
    'lt': {
        'region_code': [],
        'plurals': 'nplurals=3; plural=(n%10==1 && n%100!=11 ? 0 : n%10>=2 && (n%100<10 || n%100>=20) ? 1 : 2)'
    },
    'lv': {
        'region_code': [],
        'plurals': 'nplurals=3; plural=(n%10==1 && n%100!=11 ? 0 : n != 0 ? 1 : 2)'
    },
    'mai': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'me': {
        'region_code': [],
        'plurals': 'nplurals=3; plural=(n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2)'
    },
    'mfe': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n > 1)'
    },
    'mg': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n > 1)'
    },
    'mi': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n > 1)'
    },
    'mk': {
        'region_code': [],
        'plurals': 'nplurals=2; plural= n==1 || n%10==1 ? 0 : 1'
    },
    'ml': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'mn': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'mni': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'mnk': {
        'region_code': [],
        'plurals': 'nplurals=3; plural=(n==0 ? 0 : n==1 ? 1 : 2'
    },
    'mr': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'ms': {
        'region_code': [],
        'plurals': 'nplurals=1; plural=0'
    },
    'mt': {
        'region_code': [],
        'plurals': 'nplurals=4; plural=(n==1 ? 0 : n==0 || ( n%100>1 && n%100<11) ? 1 : (n%100>10 && n%100<20 ) ? 2 : 3)'
    },
    'nah': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'nap': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'nb': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'ne': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'nl': {
        'region_code': ['nl_NL'],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'se': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'nn': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'no': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'nso': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'oc': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n > 1)'
    },
    'or': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'ps': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'pa': {
        'region_code': ['pa_IN'],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'pap': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'pl': {
        'region_code': ['pl_PL'],
        'plurals': 'nplurals=3; plural=(n==1 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2)'
    },
    'pms': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'pt': {
        'region_code': ['pt','pt_BR'],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'pt_BR': {
        'region_code': 'BR',
        'plurals': 'nplurals=2; plural=(n > 1)'
    },
    'rm': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n!=1);'
    },
    'ro': {
        'region_code': [],
        'plurals': 'nplurals=3; plural=(n==1 ? 0 : (n==0 || (n%100 > 0 && n%100 < 20)) ? 1 : 2);'
    },
    'ru': {
        'region_code': [],
        'plurals': 'nplurals=3; plural=(n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2)'
    },
    'sa': {
        'region_code': [],
        'plurals': 'nplurals=3; plural=( n==1 ? 0 : n==2 ? 1 : 2 )'
    },
    'sat': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'sco': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'sd': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'si': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'sk': {
        'region_code': [],
        'plurals': 'nplurals=3; plural=(n==1) ? 0 : (n>=2 && n<=4) ? 1 : 2'
    },
    'sl': {
        'region_code': ['sl_SI'],
        'plurals': 'nplurals=4; plural=(n%100==1 ? 1 : n%100==2 ? 2 : n%100==3 || n%100==4 ? 3 : 0)'
    },
    'so': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=n != 1'
    },
    'son': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'sq': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'sr': {
        'region_code': [],
        'plurals': 'nplurals=3; plural=(n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2)'
    },
    'su': {
        'region_code': [],
        'plurals': 'nplurals=1; plural=0'
    },
    'sw': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'sv': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'ta': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'te': {
        'region_code': ['te_IN'],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'tg': {
        'region_code': [],
        'plurals': 'nplurals=1; plural=0'
    },
    'ti': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=n > 1'
    },
    'th': {
        'region_code': [],
        'plurals': 'nplurals=1; plural=0'
    },
    'tk': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'tr': {
        'region_code': ['tr_TR'],
        'plurals': 'nplurals=2; plural=(n>1)'
    },
    'tt': {
        'region_code': [],
        'plurals': 'nplurals=1; plural=0'
    },
    'ug': {
        'region_code': [],
        'plurals': 'nplurals=1; plural=0;'
    },
    'uk': {
        'region_code': [],
        'plurals': 'nplurals=3; plural=(n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2)'
    },
    'ur': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'uz': {
        'region_code': [],
        'plurals': 'nplurals=1; plural=0;'
    },
    'vi': {
        'region_code': ['vi_VN'],
        'plurals': 'nplurals=1; plural=0'
    },
    'wa': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n > 1)'
    },
    'wo': {
        'region_code': [],
        'plurals': 'nplurals=1; plural=0'
    },
    'yo': {
        'region_code': [],
        'plurals': 'nplurals=2; plural=(n != 1)'
    },
    'zh': {
        'region_code': ['zh_CN', 'zh_TW'],
        'plurals': 'nplurals=1; plural=0'
    },
}
