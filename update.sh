#!/bin/sh

git reset --hard HEAD
git pull

cp dash/gunicorn.service /etc/systemd/system/
systemctl daemon-reload
systemctl restart gunicorn

crontab tasks/cron.tab

