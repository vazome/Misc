<#
.SYNOPSIS
    Checks for licenses on a set of disabled users and removes such licenses if needed.
    Does not matter whether license assigned directly or with group.
    PowerShell 5.1
.DESCRIPTION
    The script will check against all disabled users or a sigle one if provided to UserPrincipalName parameter
    If RunMode provided with True, script will only display license existance under a user.
    Please visit https://docs.microsoft.com/en-us/powershell/azure/active-directory/signing-in-service-principal?view=azureadps-2.0
    If you wish run such script as a scheduled task
    |||Because Microsoft cannot update their products properly this script cant work with PoSh 7.1 https://github.com/PowerShell/PowerShell/issues/10473|||
.PARAMETER UserPrincipalName
    Accepts string value of a user's UPN
.PARAMETER RunMode
    Accepts sting value. Stage for no action (default), Execute for license removal
.EXAMPLE
    .\Remove-AzureADLicenses.ps1 -RunMode "Stage"
.EXAMPLE
    .\Remove-AzureADLicenses.ps1 -RunMode "Execute"
.EXAMPLE
    .\Remove-AzureADLicenses.ps1 -RunMode "Execute" -UserPricipalName "tar@foo.bar"
.NOTES
    FileName:    Remove-AzureADLicenses.ps1
    Author:      Daniel Vazome
    Github:      @vazome
    Created:     2022-02-28
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [parameter(Mandatory = $true, HelpMessage = "Choose run mode for the script, either Stage or Execute.")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet("Stage", "Execute")]
    [string]$RunMode = "Stage",

    [parameter(HelpMessage = "Specify user's UPN for single user action.")]
    [ValidateNotNullOrEmpty()]
    [string]$UserPrincipalName
    )
Begin {

    $Modules = @("AzureAD", "MSOnline", "Microsoft.Graph.Users.Actions","CredentialManager")
    Write-Output "Collecting modules state"

    foreach ($Module in $Modules) {
        #Getting required modules
        if (Get-InstalledModule -Name $Module) {
            Write-Output "$Module is installed"
        }
        else {
            Install-Module -Name $Module -ErrorAction Stop
        }
        #Making it forward compatible (1)
        if ($PSVersionTable.PSVersion.Major -gt 5 ) {
            Import-Module -Name $Module -UseWindowsPowerShell -ErrorAction Stop
        } 
    }
    Write-Output "Modules are ready"

    #2. How Do I get API Access for Graph? Better to have a certificate.. Here: https://docs.microsoft.com/en-us/graph/powershell/app-only?tabs=azure-portal

    #Making credentials usable
    $MyCredential = Get-StoredCredential -Target "target-record-with-credentials"

    Connect-AzureAD -Credential $MyCredential
    Connect-MsolService -Credential $MyCredential
    #Graph are not essential and will be removed from the script in the future.
    Connect-MgGraph -ClientId "id" -TenantId "id" -Certificate $Cert

    #Getting groups which auto-assign licenses to users
    #Come on Microsoft, can you just update AzureAD module to support all MSOL features? MSOL is a past-gen and yet somewhere more effective
    $GroupsCheck = New-Object Microsoft.Open.AzureAD.Model.GroupIdsForMembershipCheck
    $GroupsCheck.GroupIds = (Get-MsolGroup -All | Where-Object {$_.Licenses}).ObjectId

    if($UserPrincipalName){
    $DisabledUsers = Get-AzureADUser -All $true | Where-Object {$_.userprincipalname -eq $UserPrincipalName}
    }
    else {
    $DisabledUsers = Get-AzureADUser -All $true | Where-Object {$_.accountenabled -eq $False}
    }
}
Process {
    Start-Transcript -Path "C:\SomeFolder\Remove-AzureADLicense.log"
    Write-Output "There $($DisabledUsers.Count) disabled users"
    Start-Sleep -Seconds 2
    Write-Output "Viewing licenses"

    #Remove/Check each user from group
    foreach($User in $DisabledUsers) {

        $UserLicenses = Get-AzureADUserLicenseDetail -ObjectId $User.ObjectId | Select-Object -Property SkuPartNumber

        switch ($RunMode) {
            "Stage" {
                if ($UserLicenses){
                    Write-Output "$($User.DisplayName) has license: ✓"
                    }
                else {
                    Write-Output "$($User.DisplayName) has license: X"
                }
            }
            "Execute" {
                if ($UserLicenses){
                    Write-Output "--------------------------------Removing Groups----------------------------------"
                    #Removing group inherited licenses
                    $GroupsDelete = Select-AzureADGroupIdsUserIsMemberOf -ObjectId $User.ObjectId -GroupIdsForMembershipCheck $GroupsCheck 
                    foreach ($Group in $GroupsDelete) {
                        Remove-AzureADGroupMember -ObjectId $Group -MemberId $User.ObjectId
                    }
                    #Neat, license preprocess is supported within PoSh: https://docs.microsoft.com/en-us/graph/api/user-reprocesslicenseassignment?view=graph-rest-beta&tabs=powershell
                    #It Requires Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All" permission scopes
                    Write-Verbose -Message "Reprocessing licenses after inheritance removal" -Verbose
                    Invoke-MgLicenseUser -UserId $User.ObjectId -ErrorAction Continue | Select-Object -Property UserPrincipalName
                    
                    Write-Output "--------------------------------Removing Groups-----------------------------------"
                }
                else {
                    Write-Output "$($User.DisplayName) has license: X"
                }
            }
        }
    }

    #Let's wait 20 seconds, so everything gets reprocessed with MgLicenseUser
    Write-Verbose -Message "Waiting 1 Minute until every user synchronizes" -Verbose
    Start-Sleep -Seconds 20

    foreach($User in $DisabledUsers) {

        $UserLicenses = Get-AzureADUserLicenseDetail -ObjectId $User.ObjectId | Select-Object -Property SkuPartNumber
        Write-Output "$($User.UserPrincipalName) licenses to remove:"
        $UserLicenses | Select-Object -ExpandProperty SkuPartNumber
        switch ($RunMode) {
            "Stage" {
                if ($UserLicenses){
                    Write-Output "$($User.DisplayName) has license: ✓"
                    }
                else {
                    Write-Output "$($User.DisplayName) has license: X"
                }
            }
            "Execute" {
                if ($UserLicenses){
                    Write-Output "--------------------------------Removing Direct----------------------------------"
                    #Removing direct licenses
                    $MSUser = Get-MsolUser -UserPrincipalName $User.UserPrincipalName
                    for ($i=0; $i -lt $MSUser.Count; $i++) {
                        Set-MsolUserLicense -UserPrincipalName $MSUser[$i].UserPrincipalName -RemoveLicenses $MSUser[$i].licenses.accountskuid -ErrorAction Continue
                    }
                    Write-Output "--------------------------------Removing Direct-----------------------------------"
                }
                else {
                    Write-Output "$($User.DisplayName) has license: X"
                }
            }
        }
    }
    Stop-Transcript
}
