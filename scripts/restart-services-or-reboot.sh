#!/bin/bash

## Configurable values

# Random Sleep
# This script will sleep for a random amount of time, it needs a base range
# Which means, it'll sleep a random amount of time between 0-300 seconds
# Default: 300
SLEEP_RANDOM=5

# Reboot on failure 
# If it fails to restart all identify services, just reboot anyway
# Default: 0
REBOOT_ON_FAILURE=0

# Reboot every time
# Don't care, just reboot. Tip, its probably easier to just set reboot in cron
# Default: 0
REBOOT_ALWAYS=0

# Email on failure
# If we fail restarting all service, do you want this script to send an email?
# If you do, you need to configure EMAIL_SUBJECT and EMAIL_RECIPIENT as well
# Default: 0
EMAIL_ON_FAILURE=0

# Email Subject
# Default: "$(basename $0) - $HOSTNAME - Status"
EMAIL_SUBJECT="$(basename $0) - $HOSTNAME - Status"

# Email Recipient
# Default: root@localhost
EMAIL_RECIPIENT="root@localhost"

## The actual script

if [ ! -f /usr/bin/needs-restarting ]
then
  echo Error: Missing command: needs-restarting, please install yum-utils
  exit 99
fi

NEEDS_RESTARTING="$(needs-restarting)"
if [ "$(echo "${NEEDS_RESTARTING}" | wc -l)" = "0" ]
then
  exit 0 
fi


function send_email()
{
  echo "$1" | mailx -s "${EMAIL_SUBJECT}" ${EMAIL_RECIPIENT}
}

function find_parent()
{
  MY_PID=$1
  while true
  do
    MY_PPID=$(ps -o ppid= $MY_PID | awk '{ print $NF }')
    if [ "$MY_PPID" = 1 ] || [ "$MY_PPID" = 0 ]
    then
      MY_PPID=$MY_PID
      break
    else
      MY_PID=$MY_PPID
    fi
  done
}

sleep $((RANDOM%${SLEEP_RANDOM}))

LAST_KERNEL=$(rpm -q --last kernel | sed 's/^kernel-\([a-z0-9._-]*\).*/\1/g' | head -1)
CURRENT_KERNEL=$(uname -r)

if [ "$REBOOT_ALWAYS" = 1 ] || [ $LAST_KERNEL != $CURRENT_KERNEL ] || [ "$(echo "${NEEDS_RESTARTING}" | awk '$1 ~ /^1$/ { print $1 }')" = "1" ]
then
  reboot
  exit 0
fi

for SERVICE_PID in $(echo "${NEEDS_RESTARTING}" | awk '$3 !~ /\:$/ && $3 !~ /^-/ { print $1 }')
do
  if [ "$SERVICE_PID" != "" ]
  then
    if [ "$(uname -r | cut -c 1-3)" = "2.6" ]
    then
      SERVICES=""
      SERVICE_PIDS=""
      service="$(service --status-all 2> /dev/null)"
      find_parent $SERVICE_PID
      SERVICE_PIDS="$SERVICE_PIDS $MY_PID"
      SERVICE=$(echo "$service" | awk '$3 ~ /^'${SERVICE_PID}')$/ { print $1 }')
      if [ "$SERVICE" != "" ]
      then
        if [ -f "/etc/init.d/$SERVICE" ]
        then
          if [ "$(echo $SERVICES | sed 's/ /\n/g' | grep -ce "^${SERVICE}$")" = "0" ]
          then
            service $SERVICE restart
            SERVICES="$SERVICES $SERVICE"
          fi
        else
          cd /etc/init.d
          INITSCRIPT=$(egrep -l "\/${SERVICE}( |$)" *)
          if [ "$(echo $SERVICES | sed 's/ /\n/g' | grep -ce "^${INITSCRIPT}$")" != "0" ]
          then
            INITSCRIPT=$(grep -l $SERVICE *)
          fi
          [ -f /etc/init.d/$INITSCRIPT ] ; /etc/init.d/$INITSCRIPT restart
          SERVICES="$SERVICES $INITSCRIPT"
        fi
      fi
    elif [ "$(uname -r | cut -c 1-3)" = "3.1" ]
    then
      if [ "${SERVICE_PID}" != 1 ]
      then
        SERVICE=$(systemctl status $SERVICE_PID | head -1 | awk '{ print $1 }' 2>&1)
        if [ $? = 0 ]
        then
          if [ "$SERVICE" = "auditd.service" ]
          then
            service $SERVICE restart
          else
            systemctl restart $SERVICE
          fi
        fi
      fi
    fi
  fi
done

if [ "$(needs-restarting | wc -l)" != 0 ]
then
  if [ "$EMAIL_ON_FAILURE" = 1 ]
  then
    send_email "The following services still needs to be restarted: $(needs-restarting)"
  fi
  if [ "$REBOOT_ON_FAILURE" = 1 ]
  then
    reboot
  fi
fi
