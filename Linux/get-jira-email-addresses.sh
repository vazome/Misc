#!/bin/bash
# Noting tricky about it.
# Requires user-level API token: https://id.atlassian.com/manage-profile/security/api-tokens
# Documentation: https://developer.atlassian.com/cloud/jira/platform/rest/v2/api-group-users/#api-rest-api-2-users-search-get


spacename = "contoso"
email = ""
APIToken = 

curl --request GET \
  --url "https://$spacename.atlassian.net/rest/api/2/users/search?maxResults=99999" \
  --user "email:APIToken" \
  --header 'Accept: application/json' | jq -r '.[]|[.accountId,.emailAddress]|join(",")'
