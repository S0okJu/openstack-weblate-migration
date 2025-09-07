# openstack-weblate-migration

- Reference: I refer it [Jana Hussien's weblate migration scripts](https://review.opendev.org/c/openstack/i18n/+/955439)
- This repository is for testing.


## 프로젝트별 파일 위치

| 프로젝트 타입 | 컴포넌트 | POT 파일 경로 | PO 파일 경로 | 생성 함수 |
|---------------|----------|---------------|--------------|-----------|
| **Python** | {modulename} | `{modulename}/locale/{modulename}.pot` | `{modulename}/locale/{locale}/LC_MESSAGES/{modulename}.po` | `extract_messages_python` |
| | releasenotes | `releasenotes/source/locale/releasenotes.pot` | `releasenotes/source/locale/{locale}/LC_MESSAGES/releasenotes.po` | `extract_messages_releasenotes` |
| **Django** | {modulename} | `{modulename}/locale/django.pot`<br>`{modulename}/locale/djangojs.pot` | `{modulename}/locale/{locale}/LC_MESSAGES/django.po`<br>`{modulename}/locale/{locale}/LC_MESSAGES/djangojs.po` | `extract_messages_django` |
| | releasenotes | `releasenotes/source/locale/releasenotes.pot` | `releasenotes/source/locale/{locale}/LC_MESSAGES/releasenotes.po` | `extract_messages_releasenotes` |
| **Documentation** | doc | `doc/source/locale/doc.pot`<br>`doc/source/locale/doc-{directory}.pot` | `doc/source/locale/{locale}/LC_MESSAGES/doc.po`<br>`doc/source/locale/{locale}/LC_MESSAGES/doc-{directory}.po` | `extract_messages_doc` |
| **Manuals** | {DOCNAME} (RST) | `{DocFolder}/{DOCNAME}/source/locale/{DOCNAME}.pot` | `{DocFolder}/{DOCNAME}/source/locale/{locale}/LC_MESSAGES/{DOCNAME}.po` | `tox -e generatepot-rst` |
| | {DOCNAME} (일반) | `{DocFolder}/{DOCNAME}/locale/{DOCNAME}.pot` | `{DocFolder}/{DOCNAME}/locale/{locale}.po` | `./tools/generatepot` |
| **api-site** | api-quick-start | `api-quick-start/locale/api-quick-start.pot` | `api-quick-start/locale/{locale}.po` | `./tools/generatepot` |
| | firstapp | `firstapp/locale/firstapp.pot` | `firstapp/locale/{locale}.po` | `./tools/generatepot` |
| **security-doc** | security-guide | `security-guide/locale/security-guide.pot` | `security-guide/locale/{locale}.po` | `./tools/generatepot` |
| **training-guides** | doc | `doc/upstream-training/source/locale/*.pot` | `doc/upstream-training/source/locale/{locale}/LC_MESSAGES/*.po` | `tox -e generatepot-training` |
| **i18n** | doc | `doc/source/locale/*.pot` | `doc/source/locale/{locale}/LC_MESSAGES/*.po` | `tox -e generatepot` |
| **tripleo-ui** | i18n | `i18n/*.pot` | `i18n/{locale}.po` | `npm run json2pot` |
