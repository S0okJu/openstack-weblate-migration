#!/bin/bash

# Exit if any command fails
set -e

# TODO: Replace with actual values
WEBLATE_URL="https://skj.printf.kr"
WEBLATE_TOKEN="wlu_KfwNtvyTabcoLRYUqRGecuM0B7lXYKDn4RE6"

echo "Create glossary in weblate..."
response=$(curl -s -w "%{http_code}" -o /tmp/response_body \
    -H "Authorization: Token $WEBLATE_TOKEN" \
    -F "name=Glossary" \
    -F "slug=glossary" \
    -F "file_format=tbx" \
    -F "is_glossary=true" \
    -F "filemask=*.tbx" \
    -F "repo=local:" \
    -F "vcs=local" \
    $WEBLATE_URL/api/projects/keystone/components/)

http_code="${response: -3}"
response_body=$(cat /tmp/response_body)
        

echo "HTTP Status Code: $http_code"
echo "Response Body:"
# Check if response is valid JSON before using jq
if echo "$response_body" | jq . >/dev/null 2>&1; then
    echo "$response_body" | jq .
else
    echo "$response_body"
fi