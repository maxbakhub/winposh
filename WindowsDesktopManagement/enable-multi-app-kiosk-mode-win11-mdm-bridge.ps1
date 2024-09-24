# PowerShell script to enable Kiosk mode with the Multi-App Launcher in Windows 11
# More details here https://woshub.com/configure-kiosk-mode-windows/

$MultiKioskModeConfig= @"
<?xml version="1.0" encoding="utf-8" ?>
<AssignedAccessConfiguration  
  xmlns="http://schemas.microsoft.com/AssignedAccess/2017/config" xmlns:win11="http://schemas.microsoft.com/AssignedAccess/2022/config">
  <Profiles>
    <Profile Id="{579c1e63-dccc-4403-a565-86b1f5db5fdd}">       
      <AllAppsList>
        <AllowedApps> 
          <App AppUserModelId="Microsoft.WindowsCalculator_8wekyb3d8bbwe!App" /> 
          <App AppUserModelId="Microsoft.WindowsNotepad_8wekyb3d8bbwe!App" /> 
          <App AppUserModelId="Microsoft.Paint_8wekyb3d8bbwe!App" /> 
          <App AppUserModelId="Microsoft.Windows.Photos_8wekyb3d8bbwe!App" /> 
          <App AppUserModelId="windows.immersivecontrolpanel_cw5n1h2txyewy!microsoft.windows.immersivecontrolpanel" /> 
        </AllowedApps> 
      </AllAppsList> 
      <win11:StartPins>
        <![CDATA[  
          { "pinnedList":[
            {"packagedAppId":"Microsoft.WindowsCalculator_8wekyb3d8bbwe!App"},
            {"packagedAppId":"Microsoft.WindowsNotepad_8wekyb3d8bbwe!App"},
            {"packagedAppId":"Microsoft.Paint_8wekyb3d8bbwe!App"},
            {"packagedAppId":"Microsoft.Windows.Photos_8wekyb3d8bbwe!App"},
	          {"packagedAppId":"windows.immersivecontrolpanel_cw5n1h2txyewy!microsoft.windows.immersivecontrolpanel"}
          ] }
        ]]>
      </win11:StartPins>
      <Taskbar ShowTaskbar="true"/>
    </Profile> 
  </Profiles>
  <Configs>
    <Config>
      <AutoLogonAccount/>
      <DefaultProfile Id="{579c1e63-dccc-4403-a565-86b1f5db5fdd}"/>
    </Config>
  </Configs>
</AssignedAccessConfiguration>
"@
$namespaceName="root\cimv2\mdm\dmmap"
$className="MDM_AssignedAccess"
$obj = Get-CimInstance -Namespace $namespaceName -ClassName $className
$obj.Configuration = [System.Net.WebUtility]::HtmlEncode($MultiKioskModeConfig)
Set-CimInstance -CimInstance $obj


# Turn off and clean up the Multi-App Kiosk mode settings in Windows 11
# $obj  = Get-CimInstance -Namespace "root\cimv2\mdm\dmmap" -ClassName "MDM_AssignedAccess"
# $obj.Configuration = $NULL
# Set-CimInstance -CimInstance $obj


