# Download and silent SQL Server Management Studio

# Download SQL Server Management Studio
Invoke-WebRequest -Uri  https://aka.ms/ssmsfullsetup -OutFile c:\temp\SSMS-Setup-ENU.exe

# Set parameters
$media_path = "c:\temp\SSMS-Setup-ENU.exe"
$install_path = "`"C:\Program Files (x86)\Microsoft SQL Server Management Studio 18`""
$params = " /Install /Passive SSMSInstallRoot=$install_path"
        
# Run the install
Start-Process -FilePath $media_path -ArgumentList $params -Wait

# $InstallerSQL = $env:TEMP + “\SSMS-Setup-ENU.exe”; 
# Invoke-WebRequest “https://aka.ms/ssmsfullsetup" -OutFile $InstallerSQL; 
# start $InstallerSQL /Quiet
# Remove-Item $InstallerSQL;


### SSMS_Install.ps1
# Set file and folder path for SSMS installer .exe
$folderpath="c:\windows\temp"
$filepath="$folderpath\SSMS-Setup-ENU.exe"
 
#If SSMS not present, download
if (!(Test-Path $filepath)){
write-host "Downloading SQL Server 2016 SSMS..."
$URL = "https://download.microsoft.com/download/3/1/D/31D734E0-BFE8-4C33-A9DE-2392808ADEE6/SSMS-Setup-ENU.exe"
$clnt = New-Object System.Net.WebClient
$clnt.DownloadFile($url,$filepath)
Write-Host "SSMS installer download complete" -ForegroundColor Green
 
}
else {
 
write-host "Located the SQL SSMS Installer binaries, moving on to install..."
}
 
# start the SSMS installer
write-host "Beginning SSMS 2016 install..." -nonewline
$Parms = " /Install /Quiet /Norestart /Logs log.txt"
$Prms = $Parms.Split(" ")
& "$filepath" $Prms | Out-Null
Write-Host "SSMS installation complete" -ForegroundColor Green