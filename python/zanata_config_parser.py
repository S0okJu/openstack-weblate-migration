import configparser
import os
import sys

# TODO: Error Handling
# Get file path and project name from command line arguments
if len(sys.argv) >= 3:
    zanata_ini = sys.argv[1]
    project_name = sys.argv[2]
else:
    # 기본값 설정
    zanata_ini = os.environ.get('zanata_ini', 'zanata.ini')
    project_name = os.environ.get('project_name', 'default-project')

config = configparser.ConfigParser()
config.read(zanata_ini)

if 'servers' in config:
    section = config['servers']
    print(f'export ZANATA_URL="{section.get("translate_openstack_org.url", "")}"')
    print(f'export ZANATA_USERNAME="{section.get("translate_openstack_org.username", "")}"')
    print(f'export ZANATA_API_KEY="{section.get("translate_openstack_org.key", "")}"')
    print(f'export ZANATA_PROJECT_ID="{project_name}"')
    print(f'export ZANATA_VERSION_ID="master"')
else:
    print('export ZANATA_URL=""')
    print('export ZANATA_USERNAME=""')
    print('export ZANATA_API_KEY=""')
    print(f'export ZANATA_PROJECT_ID="{project_name}"')
    print('export ZANATA_VERSION_ID="master"')