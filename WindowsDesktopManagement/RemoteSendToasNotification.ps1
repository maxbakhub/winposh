# PowerShell script to send a pop-up notification to a remote computer via PowerShell (WinRM must be configured)
# https://smsagent.blog/2019/06/11/just-for-fun-send-a-remote-toast-notification/
# https://woshub.com/popup-notification-powershell/
# To send a message with a custom image, convert the image to base64 format using https://codebeautify.org/image-to-base64-converter and specify the encoded string in the $Base64Image parameter.
# Specify the computer name in the $RemoteComputer parameter.

$RemoteComputer = "PC21-15"
$Sender = "HelpDesk"
$Message = "Don't forget to restart the SAPGUI client to receive updates."

Function New-ToastNotification {
    Param($Sender,$Message)
   
    # Required parameters
    $AudioSource = "ms-winsoundevent:Notification.Default"
    $HeaderFormat = "ImageAndTitle" # Choose from "TitleOnly", "ImageOnly" or "ImageAndTitle"
    $Base64Image ="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"
# Create an image file from base64 string and save to user temp location
    If ($Base64Image)
    {
        $ImageFile = "$env:Temp\ToastLogo.png"
        [byte[]]$Bytes = [convert]::FromBase64String($Base64Image)
        [System.IO.File]::WriteAllBytes($ImageFile,$Bytes)
    }
 
    # Load some required namespaces
    $null = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    $null = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]

    # Register the AppID in the registry for use with the Action Center, if required
    $app =  '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
    $AppID = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\\WindowsPowerShell\\v1.0\\powershell.exe"
    $RegPath = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings'

    if (!(Test-Path -Path "$RegPath\$AppId")) {
        $null = New-Item -Path "$RegPath\$AppId" -Force
        $null = New-ItemProperty -Path "$RegPath\$AppId" -Name 'ShowInActionCenter' -Value 1 -PropertyType 'DWORD'
    }

# Define the toast notification in XML format
[xml]$ToastTemplate = @"
<toast duration="long">
    <visual>
    <binding template="ToastGeneric">
        <text>$Sender</text> 
        <image placement="appLogoOverride" hint-crop="circle" src="$ImageFile"/>    
        <group>
            <subgroup>
                <text hint-style="title" hint-wrap="true" >$Message</text>
            </subgroup>
        </group>
    </binding>
    </visual>
    <audio src="$AudioSource"/>
</toast>
"@

    # Load the notification into the required format
    $ToastXml = New-Object -TypeName Windows.Data.Xml.Dom.XmlDocument
    $ToastXml.LoadXml($ToastTemplate.OuterXml)

    # Display
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($app).Show($ToastXml)
}

Invoke-Command -ComputerName $RemoteComputer -ScriptBlock ${function:New-ToastNotification} -ArgumentList $Sender,$Message
