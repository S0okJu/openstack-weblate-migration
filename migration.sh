#!/bin/bash

WEBLATE_URL="<url>"
WEBLATE_TOKEN="<token>"

function setup_venv {
    if [ ! -d ".venv" ]; then
        # >= 3.10
        python3.10 -m venv .venv
    fi
    
    .venv/bin/pip3 -r pre-requirements.txt
    
    # Remove existing requirements folder if it exists
    if [ -d "requirements" ]; then
        rm -rf requirements
    fi
    
    # Install the requirements
    git clone https://opendev.org/openstack/requirements
    cd requirements
    sudo apt install -y $(../.venv/bin/bindep -b)
    ../.venv/bin/pip3 install -r upper-constraints.txt
    
    cd ..
    rm -rf requirements

}

function create_project {
    project_name=$1
    curl -X POST -H "Authorization: Token $WEBLATE_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{"name": "'$project_name'", "slug": "'$project_name'", "web": "https://opendev.org/openstack/'$project_name'"}' \
        $WEBLATE_URL/api/projects/
}

# releasenotes 메세지들을 추출한 후 하나의 파일로 만든다. 
function extract_messages_releasenotes {
    local keep_workdir=$1
    
    echo "Extracting releasenotes messages..."
    
    # 메세지 추출 
    cd ${PROJECT_NAME}
    
    # ../.venv/bin/pip3 install sphinx
    ../.venv/bin/sphinx-build -b gettext -d releasenotes/build/doctrees \
        releasenotes/source releasenotes/work
    cd ..
    # 패키지 이름 추출 - to _
    # pot 파일들을 저장하는 work 디렉토리를 생성
    echo "Checking work directory..."
    if [ ! -d ${PROJECT_NAME}/releasenotes/work ]; then
        mkdir -p ${PROJECT_NAME}/releasenotes/work
    fi

    # 기존 빌드 디렉토리 삭제     
    rm -rf ${PROJECT_NAME}/releasenotes/build
    
    # work 디렉토리에 있는 pot 파일을 하나로 합친다. 
    if [ -d ${PROJECT_NAME}/releasenotes/work ] && [ "$(ls -A ${PROJECT_NAME}/releasenotes/work/*.pot 2>/dev/null)" ]; then
        echo "Found .pot files, concatenating..."

        # locale 디렉토리 생성
        mkdir -p ${PROJECT_NAME}/locale
        
        # 중복 제거하면서 합치기
        msgcat --sort-by-file ${PROJECT_NAME}/releasenotes/work/*.pot \
            > ${PROJECT_NAME}/locale/releasenotes.pot
        
        echo "Created releasenotes.pot"
    else
        echo "No .pot files found in work directory"
    fi  
    
    # keep_workdir가 비어 있으면 워크 디렉토리를 삭제한다.
    if [ ! -n "$keep_workdir" ]; then
        rm -rf ${PROJECT_NAME}/releasenotes/work
    fi
}

# 공식 문서 참고
# https://opendev.org/openstack/openstack-zuul-jobs/src/branch/master/roles/prepare-zanata-client/files/common_translation_update.sh#L402
function extract_django_messages {

    KEYWORDS="-k gettext_noop -k gettext_lazy -k ngettext_lazy:1,2"
    KEYWORDS+=" -k ugettext_noop -k ugettext_lazy -k ungettext_lazy:1,2"
    KEYWORDS+=" -k npgettext:1c,2,3 -k pgettext_lazy:1c,2 -k npgettext_lazy:1c,2,3"
    
    # babel-django.cfg 또는 babel-djangojs.cfg 파일 존재 시에만 실행
	# 프로젝트 폴더 내에 존재함 
    for DOMAIN in djangojs django ; do
        if [ -f ${PROJECT_NAME}/babel-${DOMAIN}.cfg ]; then
            pot=${PROJECT_NAME}/locale/${DOMAIN}.pot
            touch ${pot}
			
            .venv/bin/pybabel extract -F ${PROJECT_NAME}/babel-${DOMAIN}.cfg  \
                --add-comments Translators: \
                --msgid-bugs-address="https://bugs.launchpad.net/openstack-i18n/" \
                --project=${PROJECT_NAME} \
                $KEYWORDS \
                -o ${pot} ${PROJECT_NAME} \
                --version master
            
            
			# POT 파일이 비어있는지 검증 
            check_empty_pot ${pot}
        fi
    done
    
}

# 공식 문서 참고
# https://opendev.org/openstack/openstack-zuul-jobs/src/branch/master/roles/prepare-zanata-client/files/common_translation_update.sh#L367
function extract_python_messages {

    local pot=${PROJECT_NAME}/locale/${PROJECT_NAME}.pot

    # In case this is an initial run, the locale directory might not
    # exist, so create it since extract_messages will fail if it does
    # not exist. So, create it if needed.
    mkdir -p ${PROJECT_NAME}/locale

    # Update the .pot files
    # The "_C" and "_P" prefix are for more-gettext-support blueprint,
    # "_C" for message with context, "_P" for plural form message.
    .venv/bin/pybabel ${QUIET} extract \
        --add-comments Translators: \
        --msgid-bugs-address="https://bugs.launchpad.net/openstack-i18n/" \
        --project=${PROJECT_NAME} \
        -k "_C:1c,2" -k "_P:1,2" \
        -o ${pot} ${PROJECT_NAME}
    
    # 중복 제거
    # if [ -f ${pot} ]; then
    #     msgcat --unique --sort-by-file ${pot} -o ${pot}
    # fi
    
    check_empty_pot ${pot}
}

# Delete empty pot files
# 공식 문서 참고
# https://opendev.org/openstack/openstack-zuul-jobs/src/branch/master/roles/prepare-zanata-client/files/common_translation_update.sh#L352
function check_empty_pot {
    local pot=$1

    # We don't need to add or send around empty source files.
    trans=$(msgfmt --statistics -o /dev/null ${pot} 2>&1)
    if [ "$trans" = "0 translated messages." ] ; then
        rm $pot
        # Remove file from git if it's under version control. We previously
        # had all pot files under version control, so remove file also
        # from git if needed.
        if [ -d .git ]; then
            git rm --ignore-unmatch $pot
        fi
    fi
}

function setup_directory {
    mkdir -p ${PROJECT_NAME}/locale
}

function generate_pot {
    extract_messages_releasenotes
    extract_django_messages
    extract_python_messages
}

function convert_pot_files {
    echo "Converting POT files..."
    .venv/bin/python3 convert.py ${PROJECT_NAME}
}


function create_component {
    project_name=$1

    for pot in ${project_name}/locale/*.pot; do
        # delete .pot extension
        component_name=$(basename $pot .pot) 

        echo "Creating component: $component_name from file: $pot"
        
        response=$(curl -X POST \
            -H "Authorization: Token $WEBLATE_TOKEN" \
            -F "docfile=@$pot" \
            -F "name=$component_name" \
            -F "slug=$component_name" \
            -F "file_format=po-mono" \
            -F "source_language=en" \
            -v \
            $WEBLATE_URL/api/projects/$project_name/components/ 2>&1)
        
        echo "Response for $component_name:"
        echo "$response"
        echo "---"
    done
}

# function create_glossary {
#     project_name=$1
    
#     echo "Creating glossary for project: $project_name"
    
#     # Glossary 컴포넌트 생성 (용어집)
#     response=$(curl -X POST \
#         -H "Authorization: Token $WEBLATE_TOKEN" \
#         -H "Content-Type: application/json" \
#         -d '{"name":"Glossary","slug":"glossary","file_format":"po-mono","is_glossary":true}' \
#         $WEBLATE_URL/api/projects/$project_name/components/ 2>&1)
    
#     echo "Glossary creation response:"
#     echo "$response"
#     echo "---"
# }
function prepare_project {
    project_name=$1
    if [ ! -d $project_name ]; then
        git clone https://opendev.org/openstack/$project_name.git
    fi

}
function main() {
    project_name=$1
    
    # PROJECT_NAME 변수 설정
    PROJECT_NAME=$project_name
    
    setup_venv
    # create_project $project_name

    prepare_project $project_name
    generate_pot
    convert_pot_files
    # create_glossary $project_name
    # create_component $project_name
    
}

# Call main function with command line argument
if [ $# -eq 1 ]; then
    main "$1"
else
    echo "Usage: $0 <project_name>"
    exit 1
fi