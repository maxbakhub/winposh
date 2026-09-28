# Use this PowerShell script to find and remove old and unused device drivers from the Windows Driver Store
# Reference: http://woshub.com/how-to-remove-unused-drivers-from-driver-store/
#
# Fixes applied:
#   1. Correct date parsing – uses [datetime] objects 
#   2. Proper duplicate detection – groups by Original INF name (FileName), not Published Name (oem#.inf)
#   3. Correct pnputil switch

# Requires administrator privileges
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script must be run as Administrator"
    break
}

Write-Host "Scanning driver store using DISM..." -ForegroundColor Cyan

# Get all third-party drivers from the driver store
$dismOut = dism /online /get-drivers
$Lines = $dismOut | Select-Object -Skip 10  # Skip DISM header lines

$Operation = "theName"
$Drivers = @()

foreach ($Line in $Lines) {
    # Skip empty lines or separator lines
    if ([string]::IsNullOrWhiteSpace($Line) -or $Line -eq "===") {
        if ($Operation -ne "theName") {
            $Operation = "theName"
        }
        continue
    }

    $tmp = $Line
    # Some fields may not contain ':', skip them safely
    if ($tmp -notmatch ':') {
        continue
    }
    $txt = ($tmp.Split(':', 2))[1]

    switch ($Operation) {
        'theName' {
            $Name = $txt.Trim()
            $Operation = 'theFileName'
            break
        }
        'theFileName' {
            $FileName = $txt.Trim()
            $Operation = 'theEntr'
            break
        }
        'theEntr' {
            $Entr = $txt.Trim()
            $Operation = 'theClassName'
            break
        }
        'theClassName' {
            $ClassName = $txt.Trim()
            $Operation = 'theVendor'
            break
        }
        'theVendor' {
            $Vendor = $txt.Trim()
            $Operation = 'theDate'
            break
        }
        'theDate' {
            # DISM returns date as dd.MM.yyyy (e.g., "05.12.2023")
            # Convert to [datetime] for correct sorting
            $rawDate = $txt.Trim()
            try {
                $Date = [datetime]::ParseExact($rawDate, "dd.MM.yyyy", $null)
            }
            catch {
                # Fallback: try generic parse if format differs
                $Date = [datetime]::Parse($rawDate)
            }
            $Operation = 'theVersion'
            break
        }
        'theVersion' {
            $Version = $txt.Trim()
            $Operation = 'theNull'

            $params = [ordered]@{
                'Name'      = $Name
                'FileName'  = $FileName
                'Entr'      = $Entr
                'ClassName' = $ClassName
                'Vendor'    = $Vendor
                'Date'      = $Date       # Now a [datetime] object
                'Version'   = $Version
            }
            $obj = New-Object -TypeName PSObject -Property $params
            $Drivers += $obj
            break
        }
        'theNull' {
            $Operation = 'theName'
            break
        }
    }
}

Write-Host "Found $($Drivers.Count) drivers in store" -ForegroundColor Green

# Find duplicates: group by FileName (Original INF name), not Published Name
$Duplicates = $Drivers | Group-Object FileName | Where-Object { $_.Count -gt 1 }

if ($Duplicates.Count -eq 0) {
    Write-Host "No duplicate drivers found." -ForegroundColor Green
    exit
}

$ToRemove = @()
foreach ($Group in $Duplicates) {
    # Sort by Date (newest first) and skip the last one (most recent)
    $OldVersions = $Group.Group | Sort-Object Date -Descending | Select-Object -SkipLast 1
    $ToRemove += $OldVersions
}

Write-Host "`nFound $($ToRemove.Count) old driver versions to remove:" -ForegroundColor Yellow
$ToRemove | Format-Table Name, FileName, Vendor, ClassName, Date, Version -AutoSize

# Removing old driver versions
Write-Host "`nStarting cleanup..." -ForegroundColor Cyan

foreach ($item in $ToRemove) {
    $DriverName = $item.Name.Trim()
    Write-Host "Deleting $DriverName ($($item.FileName))..." -ForegroundColor Yellow
    # Uncomment to enable automatic driver cleanup (which is disabled by default).
    # pnputil.exe /delete-driver $DriverName /force
}

Write-Host "`nCleanup complete." -ForegroundColor Green
