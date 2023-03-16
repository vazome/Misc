# This script is made for MDM solutions, mostly Microsoft Intune.
# It will rename built-in local administrator account and change its password and settings.
$ADM_USER = Get-CimInstance -ClassName Win32_UserAccount -Filter "LocalAccount = TRUE and SID like 'S-1-5-%-500'"
$NEW_ADM_NAME = "mdm-admin"
# !!! It's not that easy to provide password by most secure means in Intune, so this is a workaround (at least password is not plain) until I figure out a better solution !!!
$NEW_ADM_PASS = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String('base64-encoded string'))
$NEW_ADM_SEC_PASS = ConvertTo-SecureString -String $NEW_ADM_PASS -AsPlainText -Force

function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Message
    )
    Write-Output "$Message" | Tee-Object -FilePath C:\ProgramData\mdm-admin_v1.txt -Append 
}
function Get-ErrorMessage {
    Write-Output $Error[0].Exception.Message
}

if (-not($ADM_USER | Where-Object { $_.Name -eq $NEW_ADM_NAME })) {
    try {
        Rename-LocalUser -SID $ADM_USER.SID -NewName $NEW_ADM_NAME -ErrorAction Stop
        Enable-LocalUser -SID $ADM_USER.SID -ErrorAction Stop
        Set-LocalUser -Name $NEW_ADM_NAME -FullName $NEW_ADM_NAME -Password $NEW_ADM_SEC_PASS -AccountNeverExpires:$true -PasswordNeverExpires:$true -ErrorAction Stop
        Write-Log -Message "$($ADM_USER.Name) changed to $NEW_ADM_NAME"
    }
    catch {
        Write-Log -Message "Name and password change failed: $(Get-ErrorMessage)"
        exit 1
    }
}
