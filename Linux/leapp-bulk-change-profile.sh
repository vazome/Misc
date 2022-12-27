#!/bin/bash
# I was using this script for AWS SSO sessions in leapp
# Having leapp and leeapp CLI is a must - leapp.cloud
# Use case: you have multiple identical SSO roles in different AWS accounts in your organization. And you want them all to have specific named profile
## So instead of clicking on each role in the Leapp you can just change it in bulk

lesession=( $(leapp session list -x --filter="role=SomethingAdministrator" | awk -F ' ' '{print $1}' | grep -v -E "ID|──" ) )
for i in $lesession
do
  leapp session change-profile --sessionId="$i" --profileId="profileId" #You can get profile ID with "leapp profile list -x"
done
