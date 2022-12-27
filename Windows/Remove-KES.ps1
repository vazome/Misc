# Kaspersky no more.
# Removing endpoint security
$KL_Username = "Username"
$Code = <# Provide kaspersky tamper protection password by a secure mean, for example:
pre-existing record in Windows Credential Manager (Get-Credential) or with use of 3rd party integrations#>
$KasperskySoftware = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall, HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall |
Get-ItemProperty | Where-Object {$_.DisplayName -like "*Kaspersky Endpoint Security*" } |
Select-Object -Property DisplayName, DisplayVersion, UninstallString

#Get-WMIObject Win32_Product -Filter 'name LIKE "%Kaspersky%"'
foreach ($Program in $KasperskySoftware) {
    cmd.exe /c "$($Program.UninstallString) KLLOGIN=$KL_Username KLPASSWD=$Code /qn" 
    Start-Sleep -Seconds 10
    #cmd.exe /c "$($Program.UninstallString) /qn"
}

# Removing Network Agent
# You will also need this tool https://support.kaspersky.com/ksc11/tools/13088
$PackageID = Get-WMIObject Win32_Product -Filter 'name LIKE "%Kaspersky Security Center%"' | Select-Object -ExpandProperty IdentifyingNumber
try {
    .\cleaner.exe /uc {B9518725-0B76-4793-A409-C6794442FB50}
    .\cleaner.exe /pc $PackageID
}
catch {
    exit 0   
}