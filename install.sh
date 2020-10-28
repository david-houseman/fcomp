#!/bin/sh
set -e

ln -sf /usr/share/zoneinfo/Australia/Sydney /etc/localtime
echo "Australia/Sydney" > /etc/timezone

for req in requirements-dpkg.txt */requirements-dpkg.txt
do
    cat "$req" | xargs apt-get -y --no-install-recommends install
done

pip3 install --upgrade pip setuptools
virtualenv --always-copy -p python3 venv
source venv/bin/activate

for req in requirements-py.txt */requirements-py.txt
do
    pip3 install --upgrade -r "$req"
done

su postgres -c "createuser david" || true
su postgres -c "createdb -O fcomp david" || true


