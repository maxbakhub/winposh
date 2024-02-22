# PowerShell function to download UWP package installation files (APPX/MSIX/MSIXBUNDLE/APPXBUNDLE) with dependencies from the Microsoft Store.
# https://woshub.com/how-to-download-appx-installation-file-for-any-windows-store-app/
# https://serverfault.com/questions/1018220/how-do-i-install-an-app-from-windows-store-using-powershell

# Usage:
# The following command will download the WhatsApp UWP app with dependencies 
# Download-AppxPackage "https://apps.microsoft.com/detail/9NKSQGP7F2NH" "$ENV:USERPROFILE\Desktop"

function Download-AppxPackage {
[CmdletBinding()]
param (
  [string]$Uri,
  [string]$Path = "."
)
   
  process {
    $Path = (Resolve-Path $Path).Path
    #Get Urls to download
    $WebResponse = Invoke-WebRequest -UseBasicParsing -Method 'POST' -Uri 'https://store.rg-adguard.net/api/GetFiles' -Body "type=url&url=$Uri&ring=Retail" -ContentType 'application/x-www-form-urlencoded'
    $LinksMatch = $WebResponse.Links | where {$_ -like '*.appx*' -or $_ -like '*.appxbundle*' -or $_ -like '*.msix*' -or $_ -like '*.msixbundle*'} | where {$_ -like '*_neutral_*' -or $_ -like "*_"+$env:PROCESSOR_ARCHITECTURE.Replace("AMD","X").Replace("IA","X")+"_*"} | Select-String -Pattern '(?<=a href=").+(?=" r)'
    $DownloadLinks = $LinksMatch.matches.value 

    function Resolve-NameConflict{
    #Accepts Path to a FILE and changes it so there are no name conflicts
    param(
    [string]$Path
    )
        $newPath = $Path
        if(Test-Path $Path){
            $i = 0;
            $item = (Get-Item $Path)
            while(Test-Path $newPath){
                $i += 1;
                $newPath = Join-Path $item.DirectoryName ($item.BaseName+"($i)"+$item.Extension)
            }
        }
        return $newPath
    }
    #Download Urls
    foreach($url in $DownloadLinks){
        $FileRequest = Invoke-WebRequest -Uri $url -UseBasicParsing #-Method Head
        $FileName = ($FileRequest.Headers["Content-Disposition"] | Select-String -Pattern  '(?<=filename=).+').matches.value
        $FilePath = Join-Path $Path $FileName; $FilePath = Resolve-NameConflict($FilePath)
        [System.IO.File]::WriteAllBytes($FilePath, $FileRequest.content)
        echo $FilePath
    }
  }
}
