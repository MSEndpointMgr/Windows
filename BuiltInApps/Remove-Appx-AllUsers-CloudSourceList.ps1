<#
.SYNOPSIS
    Remove built-in apps (modern apps) from Windows 11 for All Users.

.DESCRIPTION
    This script will remove all built-in apps that are specified in the 'blacklistedapps' variable.
    The Black list (txt file) is hosted in Azure Blob storage or GitHub so it can be dynamically updated.
    Built-in apps listed in the txt file that are prefixed with a # will be considered eligible for removal.

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

    # Black List of Appx Provisioned Packages to Remove for All Users
    $BlackListedAppsURL = $null
    $BlackListedAppsURL = "https://raw.githubusercontent.com/MSEndpointMgr/Windows/master/BuiltInApps/blacklist_w11.txt"
    Write-LogEntry -Value "BlackListedAppsURL:$($BlackListedAppsURL)"

    #Attempt to obtain list of BlackListedApps
    Try {
        $BlackListedAppsFile = $null
        $BlackListedAppsFile = (New-Object System.Net.WebClient).DownloadString($BlackListedAppsURL)
    } 
    Catch {
        Write-Warning $_.Exception
    }

    #Read apps from file and split lines
    $BlackListedAppsConvertToArray = $BlackListedAppsFile -split "`n" | Foreach-Object { $_.trim() }
    
    #Create array of bad apps
    $BlackListedAppsArray = New-Object -TypeName System.Collections.ArrayList
    Foreach ($App in $BlackListedAppsConvertToArray) {
        If ($App -like "#*") {
            $App = $App.trimStart("#")
            $BlackListedAppsArray.AddRange(@($App))
        }
    }

    #Define Icons
    $CheckIcon = @{
        Object          = [Char]8730
        ForegroundColor = 'Green'
        NoNewLine       = $true
    }

    #Define App Count
    [int]$AppCount = 0

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
}

Process {

    If ($($BlackListedAppsArray.Count) -ne 0) {

        Write-Output `n"The following $($BlackListedAppsArray.Count) apps were targeted for removal from the device:-"
        Write-LogEntry -Value "The following $($BlackListedAppsArray.Count) apps were targeted for removal from the device:-"
        Write-LogEntry -Value "Apps marked for removal:$($BlackListedAppsArray)"
        Write-Output ""
        $BlackListedAppsArray

        #Initialize list for apps not targeted
        $AppNotTargetedList = New-Object -TypeName System.Collections.ArrayList

        # Get Appx Provisioned Packages
        Write-Output `n"Gathering installed Appx Provisioned Packages..."
        Write-LogEntry -Value "Gathering installed Appx Provisioned Packages..."
        Write-Output ""
        $AppArray = Get-AppxProvisionedPackage -Online | Select-Object -ExpandProperty DisplayName

        # Loop through each Provisioned Package
        foreach ($BlackListedApp in $BlackListedAppsArray) {

            # Function call to Remove Appx Provisioned Packages defined in the Black List
            if (($BlackListedApp -in $AppArray)) {
                $AppCount ++
                Try {
                    Remove-AppxProvisionedPackageCustom -BlackListedApp $BlackListedApp -ErrorAction Stop
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