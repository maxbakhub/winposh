# Script to get MFA statuses for all users in AzureAD/Microsoft 365 tenant
#  http://woshub.com/enable-disable-mfa-azure-users/
Connect-MsolService
$Report = @()
$AzUsers = Get-MsolUser -All 
ForEach ($AzUser in $AzUsers) {  
    $DefaultMFAMethod = ($AzUser.StrongAuthenticationMethods | ? { $_.IsDefault -eq "True" }).MethodType
    $MFAState = $AzUser.StrongAuthenticationRequirements.State
    if ($MFAState -eq $null) {$MFAState = "Disabled"} 
    $objReport = [PSCustomObject]@{
        User     = $AzUser.UserPrincipalName
        MFAState = $MFAState
        MFAPhone = $AzUser.StrongAuthenticationUserDetails.PhoneNumber
        MFAMethod = $DefaultMFAMethod 
    }
    $Report += $objReport
}
$Report
