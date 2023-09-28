# Download and silent install Java Runtime Environement
# Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine
# Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser
# Get-ExecutionPolicy -List

# working directory path
$workd = "c:\temp"

# Check if work directory exists if not create it
If (!(Test-Path -Path $workd -PathType Container))
{ 
New-Item -Path $workd  -ItemType directory 
}

# Create config file for silent install
$text = '
INSTALL_SILENT=Enable
AUTO_UPDATE=Enable
SPONSORS=Disable
REMOVEOUTOFDATEJRES=1
'
$text | Set-Content "$workd\jreinstall.cfg"
    
# Download executable (small online installer)
$source = "https://javadl.oracle.com/webapps/download/AutoDL?BundleId=245448_4d5417147a92418ea8b615e228bb6935"
$destination = "$workd\jreInstall.exe"
$client = New-Object System.Net.WebClient
$client.DownloadFile($source, $destination)

# Install silently
Start-Process -FilePath "$workd\jreInstall.exe" -ArgumentList INSTALLCFG="$workd\jreinstall.cfg" -wait

echo "Java JRE Installed"

# Wait 120 Seconds for the installation to finish
# Start-Sleep -s 180
# Remove the installer
# rm -Force $workd\jre*