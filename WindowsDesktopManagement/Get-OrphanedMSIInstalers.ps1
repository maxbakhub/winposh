<#
.SYNOPSIS
    Find orphaned (unreferenced) MSI and MSP files within the C:\Windows\Installer directory.
    For a detailed technical explanation, refer to: https://woshub.com/cleanup-windows-installer/
    
.DESCRIPTION
    This script interfaces directly with the Windows Installer COM API to compile a comprehensive list 
    of all registered cached installation packages:
        - MSI products via ProductInfo(..., 'LocalPackage')
        - MSP patches via PatchInfo(..., 'LocalPackage')
    
    It then cross-references these registered paths against the physical .MSI and .MSP files located in:
        C:\Windows\Installer

    Any file physically present in the Installer directory but absent from the registered LocalPackage 
    map is flagged as potentially orphaned.

    NOTE: This script operates strictly in read-only (scanning) mode.

.NOTES
    Requires Administrator privileges.

    CRITICAL WARNING:
    The C:\Windows\Installer directory is a critical system folder. 
    NEVER delete files from this location without thoroughly validating the generated report. 
    Removing active files will break application modification, repair, or uninstallation routines.
#>

#Requires -RunAsAdministrator

$TargetInstallerDir = "$env:WINDIR\Installer"

Write-Host "Establishing connection to Windows Installer COM API..." -ForegroundColor Cyan
$WinInstaller = New-Object -ComObject WindowsInstaller.Installer

# 1. Enumerate all registered packages (MSI + MSP) via the COM API
Write-Host "Enumerating registered products and patches..." -ForegroundColor Cyan
$RegisteredProductCodes = @($WinInstaller.Products())
$KnownPackagePaths = @{}

foreach ($ProdCode in $RegisteredProductCodes) {
    try {
        $pkgPath = $WinInstaller.ProductInfo($ProdCode, 'LocalPackage')
        if ($pkgPath -and (Test-Path -Path $pkgPath)) {
            $KnownPackagePaths[$pkgPath.ToLower()] = $true
        }
    } catch {
        # Silently continue if a specific product query fails
    }
    
    # Enumerate patches (MSP) associated with the current product
    try {
        $associatedPatches = @($WinInstaller.Patches($ProdCode))
        foreach ($PatchCode in $associatedPatches) {
            try {
                $patchPath = $WinInstaller.PatchInfo($PatchCode, 'LocalPackage')
                if ($patchPath -and (Test-Path -Path $patchPath)) {
                    $KnownPackagePaths[$patchPath.ToLower()] = $true
                }
            } catch {
                # Silently continue if a specific patch query fails
            }
        }
    } catch {
        # Silently continue if patch enumeration fails for this product
    }
}

Write-Host "Successfully mapped $($KnownPackagePaths.Count) registered package paths." -ForegroundColor Green

# 2. Retrieve all physical files within the Installer directory
Write-Host "`nScanning physical contents of $TargetInstallerDir..." -ForegroundColor Cyan
$PhysicalFiles = Get-ChildItem -Path $TargetInstallerDir -File -Force -ErrorAction SilentlyContinue

# 3. Identify orphaned files (present physically, but not in the registered map)
$UnreferencedFiles = $PhysicalFiles | Where-Object {
    $fileExtension = $_.Extension.ToLower()
    $fileExtension -in @('.msi', '.msp') -and $KnownPackagePaths.Keys -notcontains $_.FullName.ToLower()
}

if ($UnreferencedFiles) {
    Write-Host "`nFound $($UnreferencedFiles.Count) potentially orphaned file(s)." -ForegroundColor Yellow
    
    $AnalysisReport = $UnreferencedFiles | ForEach-Object {
        $currentFile = $_
        $productName = 'Unknown'
        $manufacturer = 'Unknown'
        
        try {
            # Open the MSI/MSP database in read-only mode (0)
            $db = $WinInstaller.OpenDatabase($currentFile.FullName, 0)
            
            # Query ProductName
            $viewName = $db.OpenView("SELECT Value FROM Property WHERE Property = 'ProductName'")
            $viewName.Execute()
            $recordName = $viewName.Fetch()
            if ($recordName) { $productName = $recordName.StringData(1) }
            
            # Query Manufacturer
            $viewMfg = $db.OpenView("SELECT Value FROM Property WHERE Property = 'Manufacturer'")
            $viewMfg.Execute()
            $recordMfg = $viewMfg.Fetch()
            if ($recordMfg) { $manufacturer = $recordMfg.StringData(1) }
        } catch {
            # If the database cannot be read (e.g., corrupted or not a valid MSI/MSP), default to N/A
            $productName = 'N/A'
            $manufacturer = 'N/A'
        }
        
        [PSCustomObject]@{
            FilePath     = $currentFile.FullName
            SizeMB       = [math]::Round($currentFile.Length / 1MB, 2)
            Product      = $productName
            Manufacturer = $manufacturer
            LastModified = $currentFile.LastWriteTime
        }
    }
    
    $AnalysisReport | Format-Table -AutoSize -Wrap
    $TotalReclaimableMB = [math]::Round(($UnreferencedFiles | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
    Write-Host "`nTotal potential space reclaimable: $TotalReclaimableMB MB" -ForegroundColor Magenta
} else {
    Write-Host "`nNo orphaned files detected. The Installer directory cache is fully synchronized." -ForegroundColor Green
}