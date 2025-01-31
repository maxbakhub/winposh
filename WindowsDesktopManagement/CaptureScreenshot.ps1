# Powershell script to take a screenshot of the user's screen and save it as a PNG file
# https://woshub.com/take-user-desktop-screenshot-with-powershell/

$Path = "C:\ScreenCapture"
# Make sure the directory for saving screenshots has been created, otherwise create it
If (!(test-path $path)) {
  New-Item -ItemType Directory -Force -Path $path
}
Add-Type -AssemblyName System.Windows.Forms
$screen = [Windows.Forms.SystemInformation]::VirtualScreen
# Get current screen resolution
$image = New-Object System.Drawing.Bitmap($screen.Width, $screen.Height)
# Create a graphic object
$graphic = [System.Drawing.Graphics]::FromImage($image)
$point = New-Object System.Drawing.Point(0, 0)
$graphic.CopyFromScreen($point, $point, $image.Size);
$cursorBounds = New-Object System.Drawing.Rectangle([System.Windows.Forms.Cursor]::Position, [System.Windows.Forms.Cursor]::Current.Size)
# Take a screenshot
[System.Windows.Forms.Cursors]::Default.Draw($graphic, $cursorBounds)
$screen_file = "$Path\" + $env:computername + "_" + $env:username + "_" + "$((get-date).tostring('yyyy.MM.dd-HH.mm.ss')).png"
# Save the screenshot as a PNG file
$image.Save($screen_file, [System.Drawing.Imaging.ImageFormat]::Png)
# Freeing up memory
$graphic.Dispose()
$image.Dispose()
