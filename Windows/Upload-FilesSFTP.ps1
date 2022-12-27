# Author: Daniel Vazome
# It can be invoked from CLI or Windows Scheduler
param (
    [Parameter( Mandatory = $true, HelpMessage = "Parner name, case-insensetive, one word")]
    [string]$Purpose
)
# creating variables that will not vary.
$PurposeName = $Purpose.ToLower()
$KeyPath = "C:\location\path\credentials\$PurposeName\$PurposeName"
$LogPath = "C:\location\path\$PurposeName`_log.log"
if (!(Test-Path $LogPath)) {
   New-Item -Path "C:\location\path\" -Name "$PurposeName`_log.log" -ItemType "file"
}
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('INFO', 'WARNING', 'ERROR')]
        [string]$Type = 'INFO'
    )
    Write-Output "$(Get-Date -Format u) | $Type | $SftpAddress | $Message" | Out-File -FilePath $LogPath -Append -Encoding utf8
}

function Get-ErrorMessage {
    $LastErrorMessage = $Error[0].Exception.Message
    Write-Output "$LastErrorMessage"
}

#Making sure module is up
function Enable-SFTPModule {
    try {
        if (Get-Module -Name "Posh-SSH") {
            Import-Module -Name Posh-SSH -ErrorAction Stop
        }
        else {
            Install-Module -Name Posh-SSH -ErrorAction Stop
        }
        Write-Log -Message "Loading module: Posh-SSH" -Type INFO
    }
    catch {
        Write-Log -Message "Module has failed to load: Posh-SSH" -Type ERROR
        Write-Log -Message "$(Get-ErrorMessage)" -Type ERROR
    }
}

function Send-ItemSFTP {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('External', 'Internal')]
        [string]$Type,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$SftpAddress,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [int]$Port,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$CredentialTarget,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$SourcePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$DestinyPath
    )
    Enable-SFTPModule
    Set-Location -Path $SourcePath
    $Files = Get-ChildItem -Path $SourcePath | Select-Object -ExpandProperty Name
    $Credential = Get-StoredCredential -Target $CredentialTarget

    # Upload the file to the SFTP path and set proper permissions
    try {
        $SftpSession = New-SFTPSession -ComputerName $SftpAddress -Credential $Credential -KeyFile $KeyPath -Port $Port -AcceptKey -Force -ErrorAction Stop
        Write-Log -Message "SFTP session inintiation" -Type INFO
    }
    catch {
        Write-Log -Message "SFTP session inintiation failed" -Type ERROR
        Write-Log -Message "$(Get-ErrorMessage)" -Type ERROR
    }

    foreach ($File in $Files) {
        # if there was no error, then move file to archive
        Write-Log -Message "SFTP transfer for $File" -Type INFO
        Set-SFTPItem -SessionId ($SftpSession).SessionId -Path $File -Destination $DestinyPath
        if ($?) {
            $ArchiveFolder = "C:\location\path\$PurposeName" + "_archive"
            Move-Item -Path ".\$File" -Destination $ArchiveFolder -Force
            if ($?) {
                Write-Log -Message "File archived $File" -Type INFO
            }
            else {
                Write-Log -Message "File archivation failed $File" -Type WARNING
                Write-Log -Message "$(Get-ErrorMessage)" -Type WARNING
            }
        }
        else {
            Write-Log -Message "SFTP transfer failed for $File" -Type ERROR
        }
        switch ($Type) {
            "Internal" {
                Set-SFTPPathAttribute -SessionId ($SftpSession).SessionId -Path "$DestinyPath/$File" -OthersCanRead $true -OthersCanExecute $true
                if ($?) {
                    Write-Log -Message "FS permissions are set via SFTP for $File" -Type INFO
                }
                else {
                    Write-Log -Message "FS permissions were not set via SFTP for $File" -Type WARNING
                    Write-Log -Message "$(Get-ErrorMessage)" -Type WARNING
                }
            }
            "External" {

            }
        }
    }
    # Disconnect SFTP Session
    try {
        Remove-SFTPSession -SessionId ($SftpSession).SessionId
        Write-Log -Message "Removing SFTP session" -Type INFO
    }
    catch {
        Write-Log -Message "SFTP session removal failed" -Type WARNING
        Write-Log -Message "$(Get-ErrorMessage)" -Type WARNING
    }

}

function Get-ItemSFTP {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$SftpAddress,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [int]$Port,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$CredentialTarget,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$SourcePath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$DestinyPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$MatchName
    )
    Enable-SFTPModule
    #making it to network share
    try {
        Set-Location -Path $DestinyPath -ErrorAction STOP
    }
    catch {
        Write-Log -Message "Failed to set location" -Type ERROR
        Write-Log -Message "$(Get-ErrorMessage)" -Type ERROR
        exit 1
    }
    $Credential = Get-StoredCredential -Target $CredentialTarget

    # Upload the file to the SFTP path and set proper permissions
    try {
        $SftpSession = New-SFTPSession -ComputerName $SftpAddress -Credential $Credential -KeyFile $KeyPath -Port $Port -AcceptKey -Force -ErrorAction Stop
        Write-Log -Message "SFTP session inintiation" -Type INFO
    }
    catch {
        Write-Log -Message "SFTP session inintiation failed" -Type ERROR
        Write-Log -Message "$(Get-ErrorMessage)" -Type ERROR
    }

    $Files = Get-SFTPChildItem -SessionId ($SftpSession).SessionId -Path $SourcePath -File 
    if ($?) {
        foreach ($File in $Files) {
            if ($File.name -match $MatchName) {
                Get-SFTPItem -SessionId ($SftpSession).SessionId -Path $File.FullName -Destination . -ErrorAction Continue
                if ($?) {
                    Write-Log -Message "Remote file $($File.FullName) has been succefuly downloaded $DestinyPath" -Type INFO
                }
                else {
                    if ((Get-ErrorMessage) -like "*already present on local host*") {
                        Write-Log -Message "$(Get-ErrorMessage)" -Type INFO
                    }
                    else {
                        Write-Log -Message "$(Get-ErrorMessage)" -Type ERROR
                    }
                }
            }
        }
    }
    else {
        Write-Log -Message "Could not get SFTP item list for download" -Type ERROR
        Write-Log -Message "$(Get-ErrorMessage)" -Type ERROR
    }
    

    # Disconnect SFTP Session
    try {
        Remove-SFTPSession -SessionId ($SftpSession).SessionId
        Write-Log -Message "Removing SFTP session" -Type INFO
    }
    catch {
        Write-Log -Message "SFTP session removal failed" -Type WARNING
        Write-Log -Message "$(Get-ErrorMessage)" -Type ERROR
    }    
}

# matching is case-insensitive, PurposeName must be explicitly declared
Switch ($Purpose) {
    "partner1" {
        Send-ItemSFTP -Type Internal -SftpAddress "SftpServerIPorDNSAddress" -Port 1337 -CredentialTarget "credential-module-object-target-name" -SourcePath "C:\location\path\$PurposeName" -DestinyPath "SFTPPathWhereToSendDocumentsTo"
    }

    "partner2" {
        Send-ItemSFTP -Type Internal -SftpAddress "SftpServerIPorDNSAddress" -Port 1337 -CredentialTarget "credential-module-object-target-name" -SourcePath "C:\location\path\$PurposeName" -DestinyPath "SFTPPathWhereToSendDocumentsTo"
        
        $MatchName = 'REGEXPATTERN'
        $DestinyPath ="Windows\SMB file destination path"
        Get-ItemSFTP -SftpAddress "SftpServerIPorDNSAddress" -Port 1337 -CredentialTarget "credential-module-object-target-name" -SourcePath "SFTPPathWhereToGetDocumentsFrom" -DestinyPath $DestinyPath -MatchName $MatchName
        
        $MatchName = 'REGEXPATTERN'
        $DestinyPath = "Windows\SMB file destination path"
        Get-ItemSFTP -SftpAddress "SftpServerIPorDNSAddress" -Port 1337 -CredentialTarget "credential-module-object-target-name" -SourcePath "SFTPPathWhereToGetDocumentsFrom" -DestinyPath $DestinyPath -MatchName $MatchName
    }

    "partner3" {
        Send-ItemSFTP -Type External -SftpAddress "SftpServerIPorDNSAddress" -Port 1337 -CredentialTarget "credential-module-object-target-name" -SourcePath "C:\location\path\$PurposeName" -DestinyPath "SFTPPathWhereToSendDocumentsTo"
        
        $MatchName = 'REGEXPATTERN'
        $DestinyPath = "Windows\SMB file destination path"
        Get-ItemSFTP -SftpAddress "SftpServerIPorDNSAddress" -Port 1337 -CredentialTarget "credential-module-object-target-name" -SourcePath "SFTPPathWhereToGetDocumentsFrom" -DestinyPath $DestinyPath -MatchName $MatchName
    }
}