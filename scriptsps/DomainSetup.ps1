[CmdletBinding()]

param 
( 
    [Parameter(ValuefromPipeline=$true,Mandatory=$true)] [string]$DomainName,
    [Parameter(ValuefromPipeline=$true,Mandatory=$true)] [string]$AdmincredsUserName,
    [Parameter(ValuefromPipeline=$true,Mandatory=$true)] [string]$AdmincredsPassword
)

$username = $AdmincredsUserName
$password = ConvertTo-SecureString -AsPlainText $AdmincredsPassword -Force
$Cred = New-Object System.Management.Automation.PSCredential ($username, $password)

Install-Windowsfeature AD-Domain-Services,DNS -IncludeManagementTools

Install-ADDSForest `
-DomainName $DomainName `
-SafeModeAdministratorPassword $password `
-CreateDnsDelegation:$false `
-DatabasePath "C:\Windows\NTDS" `
-InstallDns:$true `
-LogPath "C:\Windows\NTDS" `
-NoRebootOnCompletion:$false `
-SysvolPath "C:\Windows\SYSVOL" `
-Force:$true