#!/bin/bash
set -e

ln -sf /usr/share/zoneinfo/Australia/Sydney /etc/localtime
echo "Australia/Sydney" > /etc/timezone

apt-get update
for req in requirements-dpkg.txt */requirements-dpkg.txt
do
    cat "$req" | xargs apt-get -y --no-install-recommends install
done

pip3 install --upgrade pip setuptools
for req in requirements-py.txt */requirements-py.txt
do
    pip3 install --upgrade -r "$req"
done

su postgres -c "createuser root" || true
su postgres -c "createdb -O root root" || true


