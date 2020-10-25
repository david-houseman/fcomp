#!/bin/sh

git reset --hard HEAD
git pull
systemctl restart gunicorn
crontab tasks/cron.tab

