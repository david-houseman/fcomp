#!/bin/sh

for req in */requirements-dpkg.txt
do
    cat req | xargs apt-get -y --no-install-recommends install req
done

for req in */requirements-py.txt
do
    pip3 install -r req
done

cp /usr/share/zoneinfo/Australia/Sydney /etc/localtime
echo "Australia/Sydney" > /etc/timezone

cp dash/gunicorn.service /etc/systemd/system/
