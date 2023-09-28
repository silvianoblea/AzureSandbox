[CmdletBinding()]

param 
( 
    [Parameter(ValuefromPipeline=$true,Mandatory=$true)] [string]$DomainName,
    [Parameter(ValuefromPipeline=$true,Mandatory=$true)] [string]$AdmincredsUserName,
    [Parameter(ValuefromPipeline=$true,Mandatory=$true)] [string]$AdmincredsPassword
)

# Script to Join a Domain
$username = $AdmincredsUserName
$password = ConvertTo-SecureString -AsPlainText $AdmincredsPassword -Force
$Credential = New-Object System.Management.Automation.PSCredential ($username, $password)

Add-Computer -domainname $DomainName -Credential $Credential -restart -force