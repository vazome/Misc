#Quickly change user mail field depending on their UPN and CSV file

Start-Transcript -Path "$HOME\Documents\TranscriptLog.log" -Append -Force
$UserList = Import-Csv -Path "$HOME\Documents\UserCompare.csv" -Encoding utf8 -Delimiter ","

Import-Module -Name ActiveDirectory
foreach ($User in $UserList) {
    try {
        $UserObject = Get-ADUser -Identity $User.LoginUsername
        $OldUserMail = Get-ADUser -Identity $User.LoginUsername -Properties mail | Select-Object -ExpandProperty mail
        $NewUserMail = $OldUserMail -replace "@.+", "$($User.NewMailDomain)" 
        # Checking whether AD user mail attribute differs from CSV's
        $Miss = $OldUserMail | Where-Object { $OldUserMail -ne $NewUserMail }
        if ($Miss) {
            Write-Output "$(Get-Date -Format u);$($UserObject.Name);$OldUserMail;$NewUserMail" | Tee-Object -FilePath "$HOME\Documents\UserLog.log" -Append
            Set-ADUser -Identity $User.LoginUsername -EmailAddress $NewUserMail -Verbose
        }
    }
    catch {
        Write-Output "Error for $($User.FullName);$($User.LoginUsername)" | Tee-Object -FilePath "$HOME\Documents\UserLog.log" -Append
    }
}

Stop-Transcript 
