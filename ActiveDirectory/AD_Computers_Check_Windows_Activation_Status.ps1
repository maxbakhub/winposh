# Script to get Windows activation status on all computers in Active Directory
# Details: http://woshub.com/check-windows-activation-status/
enum Licensestatus{
    Unlicensed = 0
    Licensed = 1
    Out_Of_Box_Grace_Period = 2
    Out_Of_Tolerance_Grace_Period = 3
    Non_Genuine_Grace_Period = 4
    Notification = 5
    Extended_Grace = 6
}
$Report = @()
$ADComps = Get-ADComputer -Filter {enabled -eq "true" -and OperatingSystem -Like '*Windows*'}
Foreach ($comp in $ADComps) {
If ((Test-NetConnection $comp.name -WarningAction SilentlyContinue).PingSucceeded -eq $true){
    $activation_status= Get-CimInstance -ClassName SoftwareLicensingProduct -ComputerName $comp.name -Filter "Name like 'Windows%'" |where { $_.PartialProductKey } |  select PSComputerName, @{N=’LicenseStatus’; E={[LicenseStatus]$_.LicenseStatus}}
    $windowsversion= Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $comp.name| select Caption, Version
    $objReport = [PSCustomObject]@{
    ComputerName = $activation_status.PSComputerName
    LicenseStatus= $activation_status.LicenseStatus
    Version = $windowsversion.caption
    Build = $windowsversion.Version
    }
}
else {
    $objReport = [PSCustomObject]@{
     ComputerName = $comp.name
     LicenseStatus = "Computer offline"
      }
}
$Report += $objReport
}
$Report |Out-GridView 
