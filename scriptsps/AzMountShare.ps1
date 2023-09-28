param 
( 
    [Parameter(ValuefromPipeline=$true,Mandatory=$true)] [string]$FileShareName,
    [Parameter(ValuefromPipeline=$true,Mandatory=$true)] [string]$StorageAccountName,
    [Parameter(ValuefromPipeline=$true,Mandatory=$true)] [string]$StorageAccountKey,
    [Parameter(ValuefromPipeline=$true,Mandatory=$true)] [string]$DriveLetter,

)

$connectTestResult = Test-NetConnection -ComputerName "$StorageAccountName.file.core.windows.net" -Port 445

if ($connectTestResult.TcpTestSuccceeded) {
  # Save the password so the drive will persit on reboot
  cmd.exe /C "cmdkey /add:`"$($StorageAccountName).file.core.windows.net`" /user:`"localhost\$StorageAccountName`" /pass:`"$StorageAccountKey`""
  Write-Host Mount the drive
  New-PSDrive -Name $DriveLtter -PSProvider FileSystem -Root "\\$StorageAccountName.file.core.windows.net\$FileShareName" -Persist
}
else {
  Write-Error -Message "Unable to reach the Azure storage account via port 445. Check to make sure your organization or ISP is not blocking port 445, or use Azure P2S VPN, Azure S2S VPN, or Express Route to tunnel SMB traffic over a different port."    
}
