# Main

## [Remove-AzureADLicenses](./Microsoft365//Remove-AzureADLicenses.ps1)
### Issue
You can't remove either directly or group assigned licenses from a disabled user in bulk via GUI.

The script does the following:

1. Checks which groups provide licenses for disabled users.
    1. Removes users from the following groups.
2. Just in case, starts license reprocess for disabled users.
3. Checks any direct license assigments.
    1. Removes any direct license assigments for disabled users.

## [DeployApplicationwithS3](./macOS/deploy-applications-s3.sh)
### Issue
MDM services usually suck if the developer of a macOS pkg installer decides that the program must installed with script which comes with the pkg.
It's tedious to provide pre-install scenatios in Jamf/Intune, this script resolves it by downloading all required files and starts custom installation process you provide. 

But where to store the initial pkg files? Let's assume AWS S3 Bucket will be the place.

One thing you want before using the script is to create IAM User with programmatic access and permissions alike:
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "DownloadMDMApps",
            "Effect": "Allow",
            "Action": "s3:GetObject",
            "Resource": [
                "arn:aws:s3:::bucketname",
                "arn:aws:s3:::bucketname/*"
            ]
        }
    ]
}
```
Add programmatic credentials into the script, this way you have control over the download.

## [EqualizeHybridDomains](./Microsoft365/EqualizeHybridDomains.ps1)
### Issue
To prevent duplicate creation by [Azure AD Connect](https://docs.microsoft.com/en-us/azure/active-directory/hybrid/whatis-azure-ad-connect), this script:

1. Gets all users on-premise AD with specified UPN Suffix (user@**foo.bar.com**)
2. Checks by samAccountName whether these users have proper UPN Suffix set in the Azure AD
3. If instead of specified domain they have @somethinig.onmicrosoft.com it will replace it.