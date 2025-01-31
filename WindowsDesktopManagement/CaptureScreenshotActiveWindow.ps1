# PowerShell script: Take a screenshot of the only active app on the user's screen and save it as a PNG file
# https://woshub.com/take-user-desktop-screenshot-with-powershell/

# Add the necessary assembly for working with Windows Forms
Add-Type -AssemblyName System.Windows.Forms

# Add the C# code to define the User32 class and the required external functions
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class User32 {
    // Import the GetForegroundWindow function to retrieve the handle of the active window
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    
    // Import the GetWindowRect function to retrieve the dimensions of a window
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    
    // Define the RECT struct to hold the coordinates of the window
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }
}
"@

# Get the handle of the currently active (foreground) window
$hWnd = [User32]::GetForegroundWindow()

# Create a new RECT object to hold the window's position and size
$rect = New-Object User32+RECT

# Get the window's rectangle (position and size) using the window handle
[User32]::GetWindowRect($hWnd, [ref]$rect)

# Calculate the width and height of the window based on the RECT values
$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top

# Create a new Bitmap object with the size of the active window
$image = New-Object System.Drawing.Bitmap($width, $height)

# Create a Graphics object from the Bitmap to allow for screen capture
$graphic = [System.Drawing.Graphics]::FromImage($image)

# Define the top-left point of the window to start the screen capture
$point = New-Object System.Drawing.Point($rect.Left, $rect.Top)

# Capture the screen content from the active window into the Bitmap image
$graphic.CopyFromScreen($point, [System.Drawing.Point]::Empty, $image.Size)

# Define the path where the screenshot will be saved
$Path = "C:\ScreenCapture"

# Check if the directory exists; if not, create it
If (!(Test-Path $Path)) {
    New-Item -ItemType Directory -Force -Path $Path
}

# Construct the file name using the computer's name, username, and the current timestamp
$screenFile = "$Path\" + $env:computername + "_" + $env:username + "_" + "$((get-date).tostring('yyyy.MM.dd-HH.mm.ss')).png"

# Save the screenshot as a PNG image
$image.Save($screenFile, [System.Drawing.Imaging.ImageFormat]::Png)

# Dispose of the graphics and image objects to free up resources
$graphic.Dispose()
$image.Dispose()

