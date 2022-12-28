#!/bin/bash
# The purpose is to change (managed) users' emails across Atlassion products
# Requires organization-level API token: https://admin.atlassian.com/o/{ORD-ID}/admin-api
# Documentation: https://developer.atlassian.com/cloud/admin/user-management/rest/api-group-users/#api-users-account-id-manage-email-put
# There are many environments so you need to choose appropriate option to pass emails into script.
token=""


user="$1"
user_new_email="${2}"

generate_post_data()
{
  cat <<EOF
{
  "email": "$user_new_email"
}
EOF
}

echo "Processing: $user_new_email" | tee -a $HOME/Documents/JiraUserLogFinal.log
curl --location --request PUT "https://api.atlassian.com/users/$user/manage/email" \
--header "Authorization: Bearer $token" \
--header 'Content-Type: application/json' \
--data-raw "$(generate_post_data)"