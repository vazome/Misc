#!/bin/bash
# Veeam does not have re-IP feature for Linux hosts... let's implement it out way!
# This script was tested with /etc/crontab startup invocation
# @reboot         root    /bin/bash -c "/etc/replication-failover.sh"
# original.domain.name
OLD_IP=""
OLD_GW=""
OLD_DNS1=""
OLD_DNS2=""
# replica.domain.name
NEW_IP=""
NEW_GW=""
NEW_DNS1=""
NEW_DNS2=""

PACKETS=8
TARGET=$(ip route | awk '/default via/ {print $3}')
RET=$(ping -c $PACKETS $TARGET 2>/dev/null | awk '/ received/ {print $4}')

sleep 60

if [ $TARGET == $NEW_GW ]; then
      exit 0
      echo "$(date +%F_%T) Already switched to Replica Gateway" >> /var/log/replication-failover.log
elif [ $TARGET == $OLD_GW ]; then
      echo "$(date +%F_%T) Original Gateway, checking for GW reachability" >> /var/log/replication-failover.log
      if [ "$RET" -eq 0 ]; then
            echo "$(date +%F_%T) Gateway unreachable...changing network" >> /var/log/replication-failover.log
            sed -i "s/$OLD_IP/$NEW_IP/g" /etc/netplan/01-config-name.yaml
            sed -i "s/$OLD_GW/$NEW_GW/g" /etc/netplan/01-config-name.yaml
            sed -i "s/$OLD_DNS1/$NEW_DNS1/g" /etc/netplan/01-config-name.yaml
            sed -i "s/$OLD_DNS2/$NEW_DNS2/g" /etc/netplan/01-config-name.yaml
            netplan apply
            hostnamectl set-hostname replica.domain.name
            echo "$(date +%F_%T) Configuration done, planning reboot in 1 minute" >> /var/log/replication-failover.log
            shutdown -r now
      else
            echo "$(date +%F_%T) Network is up via $OLD_GW" >> /var/log/replication-failover.log
      fi
fi