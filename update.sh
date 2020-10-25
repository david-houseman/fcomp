#!/bin/sh

git reset --hard HEAD
git pull
crontab tasks/cron.tab

