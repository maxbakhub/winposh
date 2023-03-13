# You can use the script to clean folders in a user profile (cache, temp, downloads, google chrome cache)
# The PowerShell script is run as a user (no administrator privileges are required). Only temporary files and the current user's cache are deleted.
# You can run this script via GPO (logoff script) or with the Task Scheduler
# Use the script on RDS hosts, VDIs, or workstations to clean up user profiles
# It is recommended to test the script in your environment and then delete the WhatIf option to permanently delete files
# Details: https://woshub.com/cleanup-profile-cache-temp-files-powershell-gpo/

$Logfile = "$env:USERPROFILE\cleanup_profile_script.log"
$OldFilesData = (Get-Date).AddDays(-14)

# Complete cleanup of cache folders
[array] $clear_paths = (
    'AppData\Local\Temp',
    'AppData\Local\Microsoft\Terminal Server Client\Cache',
    'AppData\Local\Microsoft\Windows\WER',
    'AppData\Local\Microsoft\Windows\AppCache',
    'AppData\Local\CrashDumps'
    #'AppData\Local\Google\Chrome\User Data\Default\Cache',
    #'AppData\Local\Google\Chrome\User Data\Default\Cache2\entries',
    #'AppData\Local\Google\Chrome\User Data\Default\Cookies',
    #'AppData\Local\Google\Chrome\User Data\Default\Media Cache',
    #'AppData\Local\Google\Chrome\User Data\Default\Cookies-Journal'
)

# Folders where only old files should be removed
[array] $clear_old_paths = (
    'Downloads'
)

function WriteLog {
    Param ([string]$LogString)
    $Stamp = (Get-Date).ToString("yyyy/MM/dd HH:mm:ss")
    $LogMessage = "$Stamp $LogString"
    Add-content $LogFile -value $LogMessage
}

WriteLog "Starting profile cleanup script"

# If you want to clear the Google Chrome cache folder, stop the chrome.exe process
$currentuser = $env:UserDomain + "\"+ $env:UserName
WriteLog "Stopping Chrome.exe Process for $currentuser"
Get-Process -Name chrome -ErrorAction SilentlyContinue | Where-Object {$_.SI -eq (Get-Process -PID $PID).SessionId} | Stop-Process
Start-Sleep -Seconds 5

# Clean up cache folders
ForEach ($path In $clear_paths) {
    If ((Test-Path -Path "$env:USERPROFILE\$path") -eq $true) {
        WriteLog "Clearing $env:USERPROFILE\$path"
        Remove-Item -Path "$env:USERPROFILE\$path" -Recurse -Force -ErrorAction SilentlyContinue -WhatIf -Verbose 4>&1 | Add-Content $Logfile
    }
}

# Delete old files 
ForEach ($path_old In $clear_old_paths) {
    If ((Test-Path -Path "$env:USERPROFILE\$path_old") -eq $true) {
        WriteLog "Clearing $env:USERPROFILE\$path_old"
        Get-ChildItem -Path "$env:USERPROFILE\$path_old" -Recurse -Force -ErrorAction SilentlyContinue | Where-Object {($_.LastWriteTime -lt $OldFilesData)} | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -WhatIf -Verbose 4>&1 | Add-Content $Logfile
    }
}

WriteLog "End profile cleanup script"
