#!/bin/sh

cp gunicorn.service /etc/systemd/system/

for req in */requirements-dpkg.txt
do
    cat req | xargs apt-get -y --no-install-recommends install req
done

for req in */requirements-py.txt
do
    pip3 install -r req
done

