#Create Active Directory OU structure, security groups and assign permissions for a new branch office
# 

# Set the containers name
$Country="DE"
$City = "HH"
$CityFull="Hamburg"


$DomainDN=(Get-ADDomain).DistinguishedName
$ParentOU= "OU="+$Country+",$DomainDN"
$OUs = @(
    "Admins",
    "Computers",
    "Contacts",
    "Groups",
    "Servers",
    "Service Accounts",
    "Users"
)

# Create an OU for a new branch office
$newOU=New-ADOrganizationalUnit -Name $CityFull -path $ParentOU –Description “A container for $CityFull users”  -PassThru 
ForEach ($OU In $OUs) {
  New-ADOrganizationalUnit -Name $OU -Path $newOU
}

#Create administrative groups
$adm_grp=New-ADGroup ($City+ "_admins") -path ("OU=Admins,OU="+$CityFull+","+$ParentOU) -GroupScope Global -PassThru –Verbose
$adm_wks=New-ADGroup ($City+ "_account_managers") -path ("OU=Admins,OU="+$CityFull+","+$ParentOU) -GroupScope Global -PassThru –Verbose
$adm_account=New-ADGroup ($City+ "_wks_admins") -path ("OU=Admins,OU="+$CityFull+","+$ParentOU) -GroupScope Global -PassThru –Verbose

##### An example of assigning password reset permissions for the _account_managers group on the Users OU
$confADRight = "ExtendedRight"
$confDelegatedObjectType = "bf967aba-0de6-11d0-a285-00aa003049e2" # User Object Type GUID
$confExtendedRight = "00299570-246d-11d0-a768-00aa006e0529" # Extended Right PasswordReset GUID
$acl=get-acl ("AD:OU=Users,OU="+$CityFull+","+$ParentOU)
$adm_accountSID = [System.Security.Principal.SecurityIdentifier]$adm_account.SID
#Build an Access Control Entry (ACE)string
$aceIdentity = [System.Security.Principal.IdentityReference] $adm_accountSID
$aceADRight = [System.DirectoryServices.ActiveDirectoryRights] $confADRight
$aceType = [System.Security.AccessControl.AccessControlType] "Allow"
$aceInheritanceType = [System.DirectoryServices.ActiveDirectorySecurityInheritance] "Descendents"
$ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($aceIdentity, $aceADRight, $aceType, $confExtendedRight, $aceInheritanceType,$confDelegatedObjectType)
# Apply ACL
$acl.AddAccessRule($ace)
Set-Acl -Path ("AD:OU=Users,OU="+$CityFull+","+$ParentOU) -AclObject $acl

