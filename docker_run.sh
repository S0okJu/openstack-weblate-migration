# Reference: https://paste.openstack.org/show/828550/
docker pull ubuntu:24.04
docker run -it ubuntu:24.04 /bin/bash

apt-get update
apt-get install -y git python3-venv python3-pip locales unzip gettext curl

locale-gen en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8
export LC_ALL=en_US.UTF-8
echo 'export LANG=en_US.UTF-8' >> ~/.bashrc
echo 'export LANGUAGE=en_US.UTF-8' >> ~/.bashrc
echo 'export LC_ALL=en_US.UTF-8' >> ~/.bashrc
source ~/.bashrc

cd /root
git clone https://opendev.org/openstack/openstack-zuul-jobs
git clone https://opendev.org/openstack/project-config
git clone https://opendev.org/openstack/horizon

python3 -m venv /root/tvenv
source /root/tvenv/bin/activate
pip install --upgrade pip
pip install Sphinx==8.1.3 python-subunit os-testr lxml requests reno openstackdocstheme

rm -rf /root/.venv
ln -s /root/tvenv /root/.venv

cp /root/project-config/roles/copy-proposal-common-scripts/files/common.sh /root/openstack-zuul-jobs/roles/prepare-zanata-client/files/

export WEBLATE_TOKEN=YOUR_WEBLATE_TOKEN

# from host
docker cp path/to/first_time_migration_script CONTAINER_ID:/root/openstack-zuul-jobs/roles/prepare-zanata-client/files/weblate_first_time_migration.sh
docker cp path/to/common_translation_script CONTAINER_ID:/root/openstack-zuul-jobs/roles/prepare-zanata-client/files/common_translation_update.sh

chmod +x /root/openstack-zuul-jobs/roles/prepare-zanata-client/files/weblate_first_time_migration.sh
cd /root/horizon

curl -o /root/horizon/upper-constraints.txt https://opendev.org/openstack/requirements/raw/branch/master/upper-constraints.txt

# To process one branch (e.g. master)
git checkout master
/root/openstack-zuul-jobs/roles/prepare-zanata-client/files/weblate_first_time_migration.sh horizon master /root/horizon

# To process all branches (except unmaintained)
git fetch --all
for branch in $(git for-each-ref --format='%(refname:short)' refs/heads/ | grep -v '^proposals$' | grep -v '^unmaintained/'); do
    echo "Processing: $branch"
    git checkout "$branch"
    LOGFILE="weblate_migration_summary_${branch}_$(date +%Y%m%d_%H%M%S).txt"
    /root/openstack-zuul-jobs/roles/prepare-zanata-client/files/weblate_first_time_migration.sh horizon "$branch" /root/horizon \
        | tee >(awk '/==== Language Enable Summary ====/,EOF' > "$LOGFILE") || echo "Migration failed for $branch, continuing..."
done
