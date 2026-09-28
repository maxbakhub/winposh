## Active Directory: PowerShell Script To Query DCs in a Domain to Report on Users SIDs and SIDHistory to Estimate their Token Size  ##

<#
Overview:
This script will query for the items which make up the token and then calculate the token size based on that dynamic result using the formula in KB327825. It will also give you a total of how many SIDs are in the SIDHistory for the user, how many of each group scope the user has, and whether the account is trusted for delegation or not (if it is the token size may be much larger).
The script has had a major rewrite and now can be ran against a single user or a collection of users to gauge their estimate token size and provide information about where the "bloat" or size is coming from-specific groups, types of groups, group SIDHistory SIDs, user SIDHistory SIDs or Windows Kerberos claims (for Windows 8/Server 2012 or later computers).
Requires: ActiveDirectory PowerShell Module
Usage Example:
.\CheckMaxTokenSize.ps1 -Principals 'cpinckar' -OSEmulation $false -Details $false
.\CheckMaxTokenSize.ps1 -Principals 'cpinckard@intel.com' -OSEmulation $false -Details $false
Resources:
https://gallery.technet.microsoft.com/scriptcenter/Check-for-MaxTokenSize-520e51e5#content
http://support.microsoft.com/kb/327825
https://learn.microsoft.com/en-us/troubleshoot/developer/webapps/iis/www-authentication-authorization/http-bad-request-response-kerberos
https://learn.microsoft.com/en-us/troubleshoot/windows-server/windows-security/kerberos-authentication-problems-if-user-belongs-to-groups
#>

PARAM ([array]$Principals = ($env:USERNAME), $OSEmulation = $false, $Details = $false)

cls

Import-Module ActiveDirectory

Trap [Exception] {
      $Script:ExceptionMessage = $_
      $Error.Clear()
      continue
}

Write-Host "Principals = " $Principals ", OSEmulation = " $OSEmulation ", Details = " $Details
$ExportFile = $pwd.Path + "\" + $env:username + "_TokenSizeDetails.txt"
$global:FormatEnumerationLimit = -1

"Token Details for all Users" | Out-File -FilePath $ExportFile 
"********************" | Out-File -FilePath $ExportFile -Append
"`n"  | Out-File $ExportFile -Append

#If OS is not specified to hypothesize token size let's find the local OS and computer role
if ($OSEmulation -eq $false) {
      # Use appropriate cmdlets based on PowerShell version
      if ($PSVersionTable.PSVersion.Major -ge 6) {
            # PowerShell 6+ (PowerShell Core) - use CIM cmdlets
            $OS = Get-CimInstance -ClassName Win32_OperatingSystem
            $cs = Get-CimInstance -ClassName Win32_ComputerSystem
            $DomainRole = $cs.DomainRole
      }
      else {
            # PowerShell 5.1 and earlier (Windows PowerShell) - use WMI cmdlets
            $OS = Get-WmiObject -Class Win32_OperatingSystem
            $cs = Get-WmiObject -Namespace "root\cimv2" -Class Win32_ComputerSystem
            $DomainRole = $cs.DomainRole
      }

      switch -regex ($DomainRole) {
            [0-1] {
                  #Workstation.
                  $RoleString = "client"
                  if ($OS.BuildNumber -eq 3790) {
                        $OperatingSystem = "Windows XP"
                        [int]$OSBuild = $OS.BuildNumber
                 	}
                  elseif (($OS.BuildNumber -eq 6001) -or ($OS.BuildNumber -eq 6002)) {
                        $OperatingSystem = "Windows Vista"
                        [int]$OSBuild = $OS.BuildNumber
                  }
                  elseif (($OS.BuildNumber -eq 7600) -or ($OS.BuildNumber -eq 7601)) {
                        $OperatingSystem = "Windows 7"
                        [int]$OSBuild = $OS.BuildNumber
                  }
                  elseif ($OS.BuildNumber -eq 9200) {
                        $OperatingSystem = "Windows 8"
                        [int]$OSBuild = $OS.BuildNumber
                  }
                  elseif ($OS.BuildNumber -eq 9600) {
                        $OperatingSystem = "Windows 8.1"
                        [int]$OSBuild = $OS.BuildNumber
                  }
                  elseif ($OS.BuildNumber -eq 10586) {
                        $OperatingSystem = "Windows 10"
                        [int]$OSBuild = $OS.BuildNumber
                  }
                  elseif ($OS.BuildNumber -eq 26100) {
                        $OperatingSystem = "Windows 11"
                        [int]$OSBuild = $OS.BuildNumber
                  }
            }
            [2-3] {
                  #Member server.
                  $RoleString = "member server"
                  if ($OS.BuildNumber -eq 3790) {
                        $OperatingSystem = "Windows Server 2003"
                        [int]$OSBuild = $OS.BuildNumber
                  }
                  elseif (($OS.BuildNumber -eq 6001) -or ($OS.BuildNumber -eq 6002)) {
                        $OperatingSystem = "Windows Server 2008 RTM"
                        [int]$OSBuild = $OS.BuildNumber
                  }
                  elseif (($OS.BuildNumber -eq 7600) -or ($OS.BuildNumber -eq 7601)) {
                        $OperatingSystem = "Windows Server 2008 R2"
                        [int]$OSBuild = $OS.BuildNumber
                  }
                  elseif ($OS.BuildNumber -eq 9200) {
                        $OperatingSystem = "Windows Server 2012"
                        [int]$OSBuild = $OS.BuildNumber
                  }
                  elseif ($OS.BuildNumber -eq 9600) {
                        $OperatingSystem = "Windows Server 2012 R2"
                        [int]$OSBuild = $OS.BuildNumber
                  }
                  elseif ($OS.BuildNumber -eq 20348) {
                        $OperatingSystem = "Windows Server 2022"
                        [int]$OSBuild = $OS.BuildNumber
                  }
            }
            [4-5] {
                  #Domain Controller
                  $RoleString = "domain controller"
                  if ($OS.BuildNumber -eq 3790) {
                        $OperatingSystem = "Windows Server 2003"
                        [int]$OSBuild = $OS.BuildNumber
                  }
                  elseif (($OS.BuildNumber -eq 6001) -or ($OS.BuildNumber -eq 6002)) {
                        $OperatingSystem = "Windows Server 2008"
                        [int]$OSBuild = $OS.BuildNumber
                  }
                  elseif (($OS.BuildNumber -eq 7600) -or ($OS.BuildNumber -eq 7601)) {
                        $OperatingSystem = "Windows Server 2008 R2"
                        [int]$OSBuild = $OS.BuildNumber
                  }
                  elseif ($OS.BuildNumber -eq 9200) {
                        $OperatingSystem = "Windows Server 2012"
                        [int]$OSBuild = $OS.BuildNumber
                  }
                  elseif ($OS.BuildNumber -eq 9600) {
                        $OperatingSystem = "Windows Server 2012 R2"
                        [int]$OSBuild = $OS.BuildNumber
                  }
            }
      }
}

if ($OSEmulation -eq $true) {
      #Prompt user to choose which OS since they chose to emulate.
      $PromptTitle = "Operating System"
      $Message = "Select which operating system to emulate for token sizing (size tolerance is and configuration OS dependant)."
      $12K = New-Object System.Management.Automation.Host.ChoiceDescription "&1 Gauge Kerberos token size using the Windows 7/Windows Server 2008 R2 and earlier default token size of 12K."
      $48KWin11 = New-Object System.Management.Automation.Host.ChoiceDescription "&2 Gauge Kerberos token size using the Windows 11 default token size of 48K. Note: The 48K setting is optionally configurable for many earlier Windows versions."
      $48KWin2012 = New-Object System.Management.Automation.Host.ChoiceDescription "&3 Gauge Kerberos token size using the Windows Server 2022 default token size of 48K. Note: The 48K setting is optionally configurable for many earlier Windows versions."
      $65K = New-Object System.Management.Automation.Host.ChoiceDescription "&4 Gauge Kerberos token size using the Windows 11/Windows Server 2022 maximum recommendation of 65K."
      $OSOptions = [System.Management.Automation.Host.ChoiceDescription[]]($12K, $48KWin11, $48KWin2012, $65K)
      $Result = $Host.UI.PromptForChoice($PromptTitle, $Message, $OSOptions, 0)
      switch ($Result) {
            0 {
                  $OSBuild = 7600
                  "Gauging Kerberos token size using the Windows 7/Windows Server 2008 R2 and earlier default token size of 12K." | Out-File $ExportFile -Append
                  Write-host "Gauging Kerberos token size using the Windows 7/Windows Server 2008 R2 and earlier default token size of 12K." 
            }
            1 {
                  $OSBuild = 26100
                  "Gauge Kerberos token size using the Windows 11 default token size of 48K. Note: The 48K setting is optionally configurable for many earlier Windows versions." | Out-File $ExportFile -Append
                  Write-host "Gauge Kerberos token size using the Windows 11 default token size of 48K. Note: The 48K setting is optionally configurable for many earlier Windows versions."
            }
            2 {
                  $OSBuild = 20348
                  "Gauge Kerberos token size using the Windows Server 2022 default token size of 48K. Note: The 48K setting is optionally configurable for many earlier Windows versions." | Out-File $ExportFile -Append
                  Write-host "Gauge Kerberos token size using the Windows Server 2022 default token size of 48K. Note: The 48K setting is optionally configurable for many earlier Windows versions."
            }
            3 {
                  $OSBuild = 10586
                  "Gauge Kerberos token size using the Windows 11/Windows Server 2022 maximum recommendation of 65K." | Out-File $ExportFile -Append
                  Write-host "Gauge Kerberos token size using the Windows 11/Windows Server 2022 maximum recommendation of 65K."
            }
      }
}
else {
      Write-Host "The computer is $OperatingSystem (OSBuild = $OSBuild) and is a $RoleString."
      "The computer is $OperatingSystem (OSBuild = $OSBuild) and is a $RoleString." | Out-File $ExportFile -Append
}

function GetSIDHistorySIDs {
      param ([string]$objectname)
      Trap [Exception] {
            $Script:ExceptionMessage = $_
            $Error.Clear()
            continue
      }
      $DomainInfo = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
      $RootString = "LDAP://" + $DomainInfo.Name
      $Root = New-Object  System.DirectoryServices.DirectoryEntry($RootString)
      $searcher = New-Object DirectoryServices.DirectorySearcher($Root)
      $searcher.Filter = "(|(userprincipalname=$objectname)(name=$objectname))"
      $results = $searcher.findone()
      if ($null -ne $results) {
            $SIDHistoryResults = $results.properties.sidhistory
      }
      #Clean up the SIDs so they are formatted correctly
      $SIDHistorySids = @()
      foreach ($SIDHistorySid in $SIDHistoryResults) {
            $SIDString = (New-Object System.Security.Principal.SecurityIdentifier($SIDHistorySid, 0)).Value
            $SIDHistorySids += $SIDString
      }
      return $SIDHistorySids
}

foreach ($Principal in $Principals) {
      #Obtain domain SID for group SID comparisons.
      $UserIdentity = New-Object System.Security.Principal.WindowsIdentity($Principal)
      $Groups = $UserIdentity.get_Groups()
      $DomainSID = $UserIdentity.User.AccountDomainSid
      $GroupCount = $Groups.Count
      if ($Details -eq $true) {
            $GroupDetails = New-Object PSObject
            Write-Progress -Activity "Getting SIDHistory, and group details for review."  -Status "Detailed results requested. This may take awhile." -ErrorAction SilentlyContinue
      }
  
      $AllGroupSIDHistories = @()
      $SecurityGlobalScope = 0
      $SecurityDomainLocalScope = 0
      $SecurityUniversalInternalScope = 0
      $SecurityUniversalExternalScope = 0
  
      foreach ($GroupSid in $Groups) {     
            $Group = [adsi]"LDAP://<SID=$GroupSid>"
            $GroupType = $Group.groupType
            if ($null -ne $Group.name) {
                  $SIDHistorySids = GetSIDHistorySIDs $Group.name
                  If (($SIDHistorySids | Measure-Object).Count -gt 0) 
                  { $AllGroupSIDHistories += $SIDHistorySids }
                  $GroupName = $Group.name.ToString()
	  
                  #Resolve SIDHistories if possible to give more detail.
                  if (($Details -eq $true) -and ($null -ne $SIDHistorySids)) {
                        $GroupSIDHistoryDetails = New-Object PSObject
                        foreach ($GroupSIDHistory in $AllGroupSIDHistories) {
                              $SIDHistGroup = New-Object System.Security.Principal.SecurityIdentifier($GroupSIDHistory)
                              $SIDHistGroupName = $SIDHistGroup.Translate([System.Security.Principal.NTAccount])
                              $GroupSIDHISTString = $GroupName + "--> " + $SIDHistGroupName
                              add-Member -InputObject $GroupSIDHistoryDetails -MemberType NoteProperty -Name $GroupSIDHistory  -Value $GroupSIDHISTString -force
                        }
                  }
            }
	              
            #Count number of security groups in different scopes.
            switch -exact ($GroupType) {
                  "-2147483646" {
                        #Domain Global scope
                        $SecurityGlobalScope++
                        if ($Details -eq $true) {
                              #Domain Global scope
                        				  $GroupNameString = $GroupName + " (" + ($GroupSID.ToString()) + ")"
                        				  add-Member -InputObject $GroupDetails -MemberType NoteProperty -Name $GroupNameString  -Value "Domain Global Group"
                              $GroupNameString = $null
                        }
                  }
                  "-2147483644" {
                        #Domain Local scope
                        $SecurityDomainLocalScope++
                        if ($Details -eq $true) {
                        				  $GroupNameString = $GroupName + " (" + ($GroupSID.ToString()) + ")"
                        				  Add-Member -InputObject $GroupDetails -MemberType NoteProperty -Name $GroupNameString  -Value "Domain Local Group"
                       					  $GroupNameString = $null
                        }
                  }
                  "-2147483640" {
                        #Universal scope; must separate local
                        #domain universal groups from others.
                        if ($GroupSid -match $DomainSID) {
                              $SecurityUniversalInternalScope++
                              if ($Details -eq $true) {
                                    $GroupNameString = $GroupName + " (" + ($GroupSID.ToString()) + ")"
                                    Add-Member -InputObject $GroupDetails -MemberType NoteProperty -Name  $GroupNameString -Value "Local Universal Group"
                                    $GroupNameString = $null
                              }
                        }
                        else {
                              $SecurityUniversalExternalScope++
                              if ($Details -eq $true) {
                                    $GroupNameString = $GroupName + " (" + ($GroupSID.ToString()) + ")"
                                    Add-Member -InputObject $GroupDetails -MemberType NoteProperty -Name  $GroupNameString -Value "External Universal Group"
                                    $GroupNameString = $null
                              }
                        }
                  }
            }
      }

      #Get user object SIDHistories
      $SIDHistoryResults = GetSIDHistorySIDs $Principal
      $SIDCounter = $SIDHistoryResults.count
      
      #Resolve SIDHistories if possible to give more detail.
      if (($Details -eq $true) -and ($null -ne $SIDHistoryResults)) {
            $UserSIDHistoryDetails = New-Object PSObject
            foreach ($SIDHistory in $SIDHistoryResults) {
                  $SIDHist = New-Object System.Security.Principal.SecurityIdentifier($SIDHistory)
                  $SIDHistName = $SIDHist.Translate([System.Security.Principal.NTAccount])
                  add-Member -InputObject $UserSIDHistoryDetails -MemberType NoteProperty -Name $SIDHistName  -Value $SIDHistory -force
            }
      }
                        
      $GroupSidHistoryCounter = $AllGroupSIDHistories.Count 
      $AllSIDHistories = $SIDCounter + $GroupSidHistoryCounter
 
      #Calculate the current token size.
      $TokenSize = 0 #Set to zero in case the script is *gasp* ran twice in the same PS.
      $TokenSize = 1200 + (40 * ($SecurityDomainLocalScope + $SecurityUniversalExternalScope + $GroupSidHistoryCounter)) + (8 * ($SecurityGlobalScope + $SecurityUniversalInternalScope))
      $DelegatedTokenSize = 2 * $TokenSize
      #Begin output of details regarding the user into prompt and outfile.
      "`n"  | Out-File $ExportFile -Append
      Write-Host " "
      Write-host  "Token Details for user $Principal" 
      "Token Details for user $Principal"  | Out-File $ExportFile -Append
      Write-host  "**********************************" 
      "**********************************"  | Out-File $ExportFile -Append
      $Username = $UserIdentity.name
      $PrincipalsDomain = $Username.Split('\')[0]
      Write-Host "User's domain is $PrincipalsDomain."
      "User's domain is $PrincipalsDomain." | Out-File $ExportFile -Append
      
      Write-Host "The total estimated token size is: $Tokensize."
      "The total estimated token size is $Tokensize." | Out-File $ExportFile -Append

      Write-Host "However, for access to domain controllers and delegatable resources (e.g., a GAR account going to AMR) the total estimated token delegation size is: $DelegatedTokenSize."
      "However, for access to domain controllers and delegatable resources (e.g., a GAR account going to AMR) the total estimated token delegation size is $DelegatedTokenSize." | Out-File $ExportFile -Append
	  
      $KerbKey = get-item -Path Registry::HKLM\SYSTEM\CurrentControlSet\Control\LSA\Kerberos\Parameters
      $MaxTokenSizeValue = $KerbKey.GetValue('MaxTokenSize')
      #If machine doesn't have MaxTokenSize defined in the registry, then use the default based on the OS.
      if ($null -eq $MaxTokenSizeValue) {
            if ($OSBuild -lt 9200) {
                  $MaxTokenSizeValue = 12000
            }
            elseif ($OSBuild -ge 9200) {
                  $MaxTokenSizeValue = 48000
            }
      }
      Write-Host "The effective MaxTokenSize value is: $Maxtokensizevalue (OSBuild $OSBuild)."
      "The effective MaxTokenSize value is: $Maxtokensizevalue (OSBuild $OSBuild)." | Out-File $ExportFile -Append

      #Assess OS so we can alert based on default for proper OS version. Windows 8 and Server 2012 allow for a larger token size safely.
      if (($Tokensize -gt $MaxTokenSizeValue) -or ($DelegatedTokenSize -gt $MaxTokenSizeValue)) {
            Write-Host "Problem detected. The token was too large for consistent authorization (i.e., $Tokensize > $MaxTokenSizeValue or $DelegatedTokenSize > $MaxTokenSizeValue). Alter the maximum size per KB http://support.microsoft.com/kb/327825 and consider reducing direct and transitive group memberships." -ForegroundColor "red"
      }
      else {
            Write-Host "Problem not detected." -backgroundcolor "green"
      }
      
      if ($Details -eq $true) {
            "`n"  | Out-File $ExportFile -Append
            Write-Host " "    
            Write-Host "*Token Details for $principal*"
            "*Token Details*" | Out-File $ExportFile -Append
            Write-Host "There are $GroupCount groups in the token."
            "There are $GroupCount groups in the token." | Out-File $ExportFile -Append
            Write-host "There are $SIDCounter SIDs in the users SIDHistory."
            "There are $SIDCounter SIDs in the users SIDHistory."  | Out-File $ExportFile -Append
            Write-host "There are $GroupSidHistoryCounter SIDs in the users groups SIDHistory attributes."
            "There are $GroupSidHistoryCounter SIDs in the users groups SIDHistory attributes."  | Out-File $ExportFile -Append
            Write-host "There are $AllSIDHistories total SIDHistories for user and groups user is a member of."
            "There are $AllSIDHistories total SIDHistories for user and groups user is a member of."  | Out-File $ExportFile -Append
            Write-Host "$SecurityGlobalScope are domain global scope security groups."
            "$SecurityDomainLocalScope are domain local security groups." | Out-File $ExportFile -Append
            Write-Host "$SecurityDomainLocalScope are domain local security groups."
            "$SecurityUniversalInternalScope are universal security groups inside of the users domain." | Out-File $ExportFile -Append
            Write-Host "$SecurityUniversalInternalScope are universal security groups inside of the users domain."
            "$SecurityUniversalExternalScope are universal security groups outside of the users domain." | Out-File $ExportFile -Append
            Write-Host "$SecurityUniversalExternalScope are universal security groups outside of the users domain."

            Write-Host "Summary and all other token content details can be found in the output file at $ExportFile"
            "`n"  | Out-File $ExportFile -Append
            "Group Details" | Out-File $ExportFile  -Append 
            $GroupDetails | Format-List * | Out-File -FilePath $ExportFile  -width 500 -Append
            "`n"  | Out-File $ExportFile -Append
            
            "Group SIDHistory Details" | Out-File $ExportFile -Append
            if ($null -eq $GroupSIDHistoryDetails) { 
                  "[NONE FOUND]" | Out-File $ExportFile -Append 
            }
            else {
                  $GroupSIDHistoryDetails | Format-List * | Out-File -FilePath $ExportFile  -width 500 -Append 
            }
            "`n"  | Out-File $ExportFile -Append
            "User SIDHistory Details" | Out-File $ExportFile -Append
            if ($null -eq $UserSIDHistoryDetails) { 
                  "[NONE FOUND]" | Out-File $ExportFile -Append 
            }
            else { 
                  $UserSIDHistoryDetails | Format-List * | Out-File -FilePath $ExportFile  -width 500 -Append 
            }
            "`n"  | Out-File $ExportFile -Append
      }
}
