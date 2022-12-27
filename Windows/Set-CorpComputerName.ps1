# Author: Daniel Vazome
# Invoke-BalloonTip function author: Boe Prox
# Assuming our naming convention depends on computer type Laptop/PC
Add-Type -AssemblyName PresentationFramework
Function Invoke-BalloonTip {
    <#
    .Synopsis
        Display a balloon tip message in the system tray.
    .Description
        This function displays a user-defined message as a balloon popup in the system tray. This function
        requires Windows Vista or later.
    .Parameter Message
        The message text you want to display.  Recommended to keep it short and simple.
    .Parameter Title
        The title for the message balloon.
    .Parameter MessageType
        The type of message. This value determines what type of icon to display. Valid values are
    .Parameter SysTrayIcon
        The path to a file that you will use as the system tray icon. Default is the PowerShell ISE icon.
    .Parameter Duration
        The number of seconds to display the balloon popup. The default is 1000.
    .Inputs
        None
    .Outputs
        None
    .Notes
         NAME:      Invoke-BalloonTip
         VERSION:   1.0
         AUTHOR:    Boe Prox
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$True,HelpMessage="Your computer will reboot very soon, please save your work")]
        [string]$Message,

        [Parameter(HelpMessage="Computer Reboot Scheduled")]
        [string]$Title="Attention $env:username",

        [Parameter(HelpMessage="The message type: Info,Error,Warning,None")]
        [System.Windows.Forms.ToolTipIcon]$MessageType="Warning",
     
        [Parameter(HelpMessage="The path to a file to use its icon in the system tray")]
        [string]$SysTrayIconPath='C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe',     

        [Parameter(HelpMessage="The number of milliseconds to display the message.")]
        [int]$Duration=5000
    )

    Add-Type -AssemblyName System.Windows.Forms

    If (-NOT $global:balloon) {
        $global:balloon = New-Object System.Windows.Forms.NotifyIcon

        #Mouse double click on icon to dispose
        [void](Register-ObjectEvent -InputObject $balloon -EventName MouseDoubleClick -SourceIdentifier IconClicked -Action {
            #Perform cleanup actions on balloon tip
            Write-Verbose 'Disposing of balloon'
            $global:balloon.dispose()
            Unregister-Event -SourceIdentifier IconClicked
            Remove-Job -Name IconClicked
            Remove-Variable -Name balloon -Scope Global
        })
    }

    #Need an icon for the tray
    $path = Get-Process -id $pid | Select-Object -ExpandProperty Path

    #Extract the icon from the file
    $balloon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($SysTrayIconPath)

    #Can only use certain TipIcons: [System.Windows.Forms.ToolTipIcon] | Get-Member -Static -Type Property
    $balloon.BalloonTipIcon  = [System.Windows.Forms.ToolTipIcon]$MessageType
    $balloon.BalloonTipText  = $Message
    $balloon.BalloonTipTitle = $Title
    $balloon.Visible = $true

    #Display the tip and specify in milliseconds on how long balloon will stay visible
    $balloon.ShowBalloonTip($Duration)

    Write-Verbose "Ending function"

}

# Is this a laptop or a PC?
$HardwareType = (Get-CimInstance -ClassName Win32_SystemEnclosure -Namespace 'root\CIMV2' -Property ChassisTypes).ChassisTypes
$PCTypes = 1..4+6,7,13
$LaptopTypes = 8..10+14,31

# Detecting user's "work profile", in our case it's Hybrid AD Account we are looking for
function Get-ComputerType {
    if ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -notlike "DOMAIN\*" ) {
        $registry = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Enrollments"
    
        $findUPN = foreach ($a in $registry) {
        $a.Property | Select-Object @{name="Value";expression={$_}}, @{name="Data";expression={$a.GetValue($_)}}}
    
        $UserLogin = $findUPN | Where-Object {$_.Value -eq "UPN" -and $_.Data -like "*@*domain.com*"} | Select-Object -ExpandProperty Data
        $UserLogin = $UserLogin -replace "@.+", "" #for simple searches it's common to use .Replace("@foo.bar.bruh", "")
    
        Write-Output "$UserLogin - Local user, AD join"
    
    }
    else {
        #else, our user is domain user, meaning it we can get username as is
        $UserLogin = [Environment]::UserName
        $UserLogin
        Write-Output "$UserLogin - AD user, AD join"
    }
    
}

Get-ComputerType

# Set Computer Name
if ($HardwareType[0] -in $PCTypes -and $env:COMPUTERNAME -ne $PCCorpComputerName.ToUpper()) {
    $PCCorpComputerName = ($UserLogin -replace ".+\.") + "-" +($UserLogin -replace "\..+") + "pc"
    Rename-Computer -NewName $PCCorpComputerName.ToUpper() -Force
    $StartReboot = 1
}
elseif ($HardwareType[0] -in $LaptopTypes -and $env:COMPUTERNAME -ne $LaptopCorpComputerName.ToUpper()) {
    $LaptopCorpComputerName = ($UserLogin -replace ".+\.") + "-" +($UserLogin -replace "\..+") + "-lp"
    Rename-Computer -NewName $LaptopCorpComputerName.ToUpper() -Force
    $StartReboot = 1
}
else {
    Write-Output "Couldn't resolve the type of $HardwareType"
}

# Inform User

if ($StartReboot -eq 1) {
    $Message = "Your computer has been renamed according to corporate naming policy, please reboot when possible"
    [System.Windows.MessageBox]::Show($Message)
    Invoke-BalloonTip -Message "Your computer has been renamed according to corporate naming policy, please reboot when possible"
    Write-Output "renamed"
}
else {
    Write-Output "nothing to do"
}