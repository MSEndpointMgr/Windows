<#
.SYNOPSIS
    Remove built-in apps (modern apps) from Windows 11 for All Users.

.DESCRIPTION
    This script will remove all built-in apps that are specified in the 'blacklistedapps' variable.

    ##WARNING## 
    Use with caution, restoring deleted provisioning packages is not a simple process.

    ##TIP##
    If removing "MicrosoftTeams", also consider disabling the "Chat" icon on the taskbar, using INtune settingd catalog, as clicking this will re-install the appxpackage for the user.

.NOTES

    Idea based on an original script for Windows 10 app removal / Credit to: Nickolaj Andersen @ MSEndpointMgr
    Modifications to original script to Black list Appx instead of Whitelist

    FileName:    Remove-Appx-AllUsers-CloudSourceList.ps1
    Author:      Ben Whitmore
    Contact:     @byteben
    Date:        27th June 2022

###### Windows 11 Apps######

Microsoft.549981C3F5F10 (Cortana Search)
Microsoft.BingNews
Microsoft.BingWeather
Microsoft.DesktopAppInstaller
Microsoft.GamingApp
Microsoft.GetHelp
Microsoft.Getstarted
Microsoft.HEIFImageExtension
Microsoft.MicrosoftEdge.Stable
Microsoft.MicrosoftOfficeHub
Microsoft.MicrosoftSolitaireCollection
Microsoft.MicrosoftStickyNotes
Microsoft.Paint
Microsoft.People
Microsoft.PowerAutomateDesktop
Microsoft.ScreenSketch
Microsoft.SecHealthUI
Microsoft.StorePurchaseApp
Microsoft.Todos
Microsoft.UI.Xaml.2.4
Microsoft.VCLibs.140.00
Microsoft.VP9VideoExtensions
Microsoft.WebMediaExtensions
Microsoft.WebpImageExtension
Microsoft.Windows.Photos
Microsoft.WindowsAlarms
Microsoft.WindowsCalculator
Microsoft.WindowsCamera
microsoft.windowscommunicationsapps
Microsoft.WindowsFeedbackHub
Microsoft.WindowsMaps
Microsoft.WindowsNotepad
Microsoft.WindowsSoundRecorder
Microsoft.WindowsStore
Microsoft.WindowsTerminal
Microsoft.Xbox.TCUI
Microsoft.XboxGameOverlay
Microsoft.XboxGamingOverlay
Microsoft.XboxIdentityProvider
Microsoft.XboxSpeechToTextOverlay
Microsoft.YourPhone
Microsoft.ZuneMusic
Microsoft.ZuneVideo
MicrosoftTeams
MicrosoftWindows.Client.WebExperience
#>

Begin {

    #Log Function
    function Write-LogEntry {
        param (
            [parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [string]$Value,
            [parameter(Mandatory = $false)]
            [ValidateNotNullOrEmpty()]
            [string]$FileName = "AppXRemoval.log",
            [switch]$Stamp
        )
    
        #Build Log File appending System Date/Time to output
        $LogFile = Join-Path -Path $env:SystemRoot -ChildPath $("Temp\$FileName")
        $Time = -join @((Get-Date -Format "HH:mm:ss.fff"), " ", (Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias))
        $Date = (Get-Date -Format "MM-dd-yyyy")
    
        If ($Stamp) {
            $LogText = "<$($Value)> <time=""$($Time)"" date=""$($Date)"">"
        }
        else {
            $LogText = "$($Value)"   
        }
        
        Try {
            Out-File -InputObject $LogText -Append -NoClobber -Encoding Default -FilePath $LogFile -ErrorAction Stop
        }
        Catch [System.Exception] {
            Write-Warning -Message "Unable to add log entry to $LogFile.log file. Error message at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
        }
    }

    #Function to Remove AppxProvisionedPackage
    Function Remove-AppxProvisionedPackageCustom {

        # Attempt to remove AppxProvisioningPackage
        if (!([string]::IsNullOrEmpty($BlackListedApp))) {
            try {
            
                # Get Package Name
                $AppProvisioningPackageName = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $BlackListedApp } | Select-Object -ExpandProperty PackageName -First 1
                Write-Host "$($BlackListedApp) found. Attempting removal ... " -NoNewline
                Write-LogEntry -Value "$($BlackListedApp) found. Attempting removal ... "

                # Attempt removeal
                $RemoveAppx = Remove-AppxProvisionedPackage -PackageName $AppProvisioningPackageName -Online -AllUsers
                
                #Re-check existence
                $AppProvisioningPackageNameReCheck = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $BlackListedApp } | Select-Object -ExpandProperty PackageName -First 1

                If ([string]::IsNullOrEmpty($AppProvisioningPackageNameReCheck) -and ($RemoveAppx.Online -eq $true)) {
                    Write-Host @CheckIcon
                    Write-Host " (Removed)"
                    Write-LogEntry -Value "$($BlackListedApp) removed"
                }
            }
            catch [System.Exception] {
                Write-Host " (Failed)"
                Write-LogEntry -Value "Failed to remove $($BlackListedApp)"
            }
        }
    }

    Write-LogEntry -Value "##################################"
    Write-LogEntry -Stamp -Value "Remove-Appx Started"
    Write-LogEntry -Value "##################################"

    #OS Check
    $OS = (Get-CimInstance -ClassName Win32_OperatingSystem).BuildNumber
    Switch -Wildcard ( $OS ) {
        '21*' {
            $OSVer = "Windows 10"
            Write-Warning "This script is intended for use on Windows 11 devices. $($OSVer) was detected..."
            Write-LogEntry -Value "This script is intended for use on Windows 11 devices. $($OSVer) was detected..."
            Exit 1
        }
    }
    # Black List of Appx Provisioned Packages to Remove for All Users
    $BlackListedApps = $null
    $BlackListedApps = New-Object -TypeName System.Collections.ArrayList
    $BlackListedApps.AddRange(@(
            "Microsoft.BingNews",
            "Microsoft.GamingApp",
            "Microsoft.MicrosoftSolitaireCollection",
            "Microsoft.WindowsCommunicationsApps",
            "Microsoft.WindowsFeedbackHub",
            "Microsoft.XboxGameOverlay",
            "Microsoft.XboxGamingOverlay",
            "Microsoft.XboxIdentityProvider",
            "Microsoft.XboxSpeechToTextOverlay",
            "Microsoft.YourPhone",
            "Microsoft.ZuneMusic",
            "Microsoft.ZuneVideo",
            "MicrosoftTeams"
        ))
 
    #Define Icons
    $CheckIcon = @{
        Object          = [Char]8730
        ForegroundColor = 'Green'
        NoNewLine       = $true
    }
 
    #Define App Count
    [int]$AppCount = 0

}

Process {

    If ($($BlackListedApps.Count) -ne 0) {

        Write-Output `n"The following $($BlackListedApps.Count) apps were targeted for removal from the device:-"
        Write-LogEntry -Value "The following $($BlackListedApps.Count) apps were targeted for removal from the device:-"
        Write-LogEntry -Value "Apps marked for removal:$($BlackListedApps)"
        Write-Output ""
        $BlackListedApps

        #Initialize list for apps not targeted
        $AppNotTargetedList = New-Object -TypeName System.Collections.ArrayList

        # Get Appx Provisioned Packages
        Write-Output `n"Gathering installed Appx Provisioned Packages..."
        Write-LogEntry -Value "Gathering installed Appx Provisioned Packages..."
        Write-Output ""
        $AppArray = Get-AppxProvisionedPackage -Online | Select-Object -ExpandProperty DisplayName

        # Loop through each Provisioned Package
        foreach ($BlackListedApp in $BlackListedApps) {

            # Function call to Remove Appx Provisioned Packages defined in the Black List
            if (($BlackListedApp -in $AppArray)) {
                $AppCount ++
                Try {
                    Remove-AppxProvisionedPackageCustom -BlackListedApp $BlackListedApp
                }
                Catch {
                    Write-Warning `n"There was an error while attempting to remove $($BlakListedApp)"
                    Write-LogEntry -Value "There was an error when attempting to remove $($BlakListedApp)"
                }
            }
            else {
                $AppNotTargetedList.AddRange(@($BlackListedApp))
            }
        }

        #Update Output Information
        If (!([string]::IsNullOrEmpty($AppNotTargetedList))) { 
            Write-Output `n"The following apps were not removed. Either they were already removed or the Package Name is invalid:-"
            Write-LogEntry -Value "The following apps were not removed. Either they were already removed or the Package Name is invalid:-"
            Write-LogEntry -Value "$($AppNotTargetedList)"
            Write-Output ""
            $AppNotTargetedList
        }
        If ($AppCount -eq 0) {
            Write-Output `n"No apps were removed. Most likely reason is they had been removed previously."
            Write-LogEntry -Value "No apps were removed. Most likely reason is they had been removed previously."
        }
    }
    else {
        Write-Output "No Black List Apps defined in array"
        Write-LogEntry -Value "No Black List Apps defined in array"
    }
}
