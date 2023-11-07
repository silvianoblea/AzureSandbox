#!/bin/bash
# *******************************************************************
# Bash Azure CLI script to create an Azure developer environment lab
# 
# LEGAL DISCLAIMER:
# This Sample Code is provided for the purpose of illustration only and is not
# intended to be used in a production environment.  THIS SAMPLE CODE AND ANY
# RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
# EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT
# OF THIRD PARTY RIGHTS.  IN NO EVENT SHALL THE COPYRIGHT HOLDER OR HOLDERS
# INCLUDED IN THIS NOTICE BE LIABLE FOR ANY CLAIM, OR ANY SPECIAL INDIRECT OR
# CONSEQUENTIAL DAMAGES, OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
# DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
# TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
# PERFORMANCE OF THIS SAMPLE CODE.
# *******************************************************************

# Setup usage and help options
display_usage() { 
	echo -e "Usage: $0"
   echo -e "   [Azure AD User]   - The logged in Azure AD account"
   echo -e "   [Subscription]    - Name of the Subsription"
   echo -e "   [Alias Prefix]    - Unique prefix for global resources"
   echo -e "   [Resource Group]  - Resource Group name = <name>_[Prefix]"
   echo -e "   [Region Primary]  - Primary Region (See below)"
   echo -e "   [Region Second]   - Secondary Region (See below)"
   echo -e "   [StorageAccount]  - Storage Account Name (lowercase) = [Prefix]<name>"
   echo -e "   [Password]        - Password to be used for resources (min 12 chars)"
   echo -e ""
	echo "Requirements: This script must be run from a bash shell that is Azure CLI logged into."
   echo "Note: Azure CLI Regions list command: az account list-locations -o table"
	echo "Azure Regions Commercial: westus | westus2 | centralus | eastus | eastus2" 
	echo "Azure Regions Government: usgovarizona | usgovtexas | usgoviowa | usgovvirginia" 
	echo "Azure Regions DoD: usdodcentral | usdodeast"
   echo -e ""
}

# Display usage if user had supplied -h, --help or -usage
if [[ ( $@ == "-help") || ($@ == "--help") || ($@ == "-h") || ($@ == "-usage") ]]
then 
   display_usage
	exit 1
fi 

# Display usage if less than required arguments
if [ $# -le 7 ]
then 
   echo "Number of arguments $# is less than requried."
   display_usage
	exit 1
fi 

# store start time
starttime=`date +%s`

# Default Script output
export SCRIPT_VERSION="1.0.0"
echo "Starting script... $0 Version ${SCRIPT_VERSION}"
# Default Script output
echo "Number of arguments: $#"
# Remove the last string which is the password
args=("$@")
numargs=$#

echo "Echoing arguments (except for sensitive strings):"
# Display arguments info except for last one (password sensative)
for ((i=1; i<numargs; i++)); do
   echo "${args[$((i-1))]}"
done
echo "*** Sensative strings not displayed ***"
echo ""

# Export all our environment variables as global for other scripts
echo "Initializing environment variables... "
# Azure AD User
export AZ_AAD_USER=$1
# Get the Azure subscription
export AZ_SUBSCRIPTION=$2
# User alias or a unique prefix for global resources
export AZ_PREFIX=$3
# Default Resource Group
export AZ_RG_NAME=$4
# Define default locations: westus, westus2, westcentralus, eastus, eastus2
export AZ_REGION_PRIMARY=$5
export AZ_REGION_SECOND=$6
# Define Storage Account name (gets appended to prefix)
export STORAGE_ACCOUNT_NAME=$7
# Define our VM credential password
export AZ_KV_SECRET_VMADMIN_PASSWORD=$8

# *******************************************************************
# Set our secondary region based on the primary region (Commercial, Gov or DoD)
# *******************************************************************
echo ""
if [[ $AZ_REGION_PRIMARY == *"usdod"* ]]; then
   echo "US DoD regions specified"
   echo "Required Secondary regions: usgovarizona | usgovtexas | usgovvirginia"
   export AZ_REGION_SECOND=${AZ_REGION_SECOND}
   CLOUDID=2
elif [[ $AZ_REGION_PRIMARY == *"usgov"* ]]; then
   echo "US Gov regions specified"
   echo "Using Secondary region ${AZ_REGION_SECOND}"
   CLOUDID=1
else 
   echo "Commercial regions specified"
   echo "Using Secondary region ${AZ_REGION_SECOND}"
   CLOUDID=0
fi


# *******************************************************************
# Step #1 would be to Login into the portal and set the subscription
# Perform "az login" if running from local command windows
# Not needed if running from Cloud Shell.
# az ad signed-in-user show --output json | jq -r '.id'
# *******************************************************************
echo ""
echo "Setting Azure Subscription: \"${AZ_SUBSCRIPTION}\""
az account set --subscription "${AZ_SUBSCRIPTION}"
export AZ_CURRENT_SUB="$(az account show --query name -o tsv)"
# Need to account for live.com accounts
export AZ_AAD_USERNAME="$(az account show --query 'user.name' --output tsv | sed 's/^live.com#//')"

# In some instances the RGs need to be unique within a subscription
export AZ_RG_NAME="${AZ_RG_NAME}_${AZ_PREFIX}"

# Default Storage Accounts
echo "Setup of Storage Account environment variables"
export AZ_STORAGEACCT_NAME="${AZ_PREFIX}${STORAGE_ACCOUNT_NAME}"
export AZ_STORAGEACCT_KEY=""
export AZ_SKU_STORAGE='Standard_LRS'
export AZ_STORAGE_FILE_SHARE="fileshare"
export AZ_STORAGE_FILE_SHARE_AKS="kubernetes"
export AZ_STORAGE_CONTAINER_BLOB="blobcontainer"
export AZ_STORAGE_CONTAINER_TF="terraformstate"
export AZ_STORAGE_CONTAINER_UP="userupload"
export AZ_STORAGE_CONTAINER_RAW="raw"
export AZ_STORAGE_CONTAINER_EC="enrichedcurated"
export AZ_STORAGE_QUEUE_DEVOPS="devops-release"

# Define Azure KeyVault
echo "Setting Storage Account environment variables"
export AZ_KV_SECRET_SAKEY='StorageAccountKey'
export AZ_KV_SECRET_VMADMIN_USER='vmadminsa'
# Keyvault names must be globally unique (no dashes)
export AZ_SKU_KEYVAULT='standard'
export AZ_KEYVAULT_NAME="${AZ_PREFIX}KeyVault"
export AZ_KEYVAULT_DEV="${AZ_PREFIX}KVdev"
export AZ_KEYVAULT_TEST="${AZ_PREFIX}KVtest"
export AZ_KEYVAULT_PROD="${AZ_PREFIX}KVprod"

# Define our Log Analytics
echo "Setting Log Analytics environment variables"
export AZ_LOG_ANALYTICS_WORKSPACE="${AZ_PREFIX}LogAnalytics"
# Note: ClientID and Secret set further down during creation

# Define Azure App Service Plan (ASP)
echo "Setting App Service Plan environment variables"
# Valid SKUs: F1, D1, B1, B2, B3, S1, S2, P1V2 P1V3, P2V3
export AZ_SKU_ASP='B1'
export ASP_PLAN_LINUX="MyASPlinux"
export ASP_PLAN_WINDOWS="MyASPwindows"

# Define Azure WebApps 
echo "Setting WebApp environment variables"
export AZ_WEBAPP_NAME="${AZ_PREFIX}WebApp"

# Azure Application Insights
echo "Setting App Insights environment variables"
export AZ_APP_INSIGHTS_NAME="MyAppInsights"

# Define Azure Functions Apps
export AFA_WINDOWS="${AZ_PREFIX}FuncAppWin"
export AFA_LINUX="${AZ_PREFIX}FuncAppLinux"
export AFA_VERSION=4

# Define Azure Container Instance (ACI)
echo "Setting ACA environment variables"
export ACI_NAME="${AZ_PREFIX}aci"

# Define Azure Container Apps (ACA)
echo "Setting ACA environment variables"
export ACA_NAME="${AZ_PREFIX}containerapp"
export ACA_ENV="MyContainerAppEnv"

# Define Azure Container Registry (ACR)
echo "Setting ACR environment variables"
# Valid SKUs: Basic, Standard, Classic, Premium
export AZ_SKU_ACR='Basic'
# Resource name must be all lowercase
export ACR_NAME="${AZ_PREFIX}acr"
export ACR_REGISTRY_USER="${AZ_KV_SECRET_VMADMIN_USER}"
export ACR_REGISTRY_PASSWORD="${AZ_KV_SECRET_VMADMIN_PASSWORD}"
export ACR_SP_NAME="${AZ_PREFIX}ACR_SP"
# Note: ClientID and Secret set further down during creation

echo "Setting SQL Server environment variables"
# Resource name must be all lowercase
export SQLSERVER_NAME="${AZ_PREFIX}sqlserver"
export SQLSERVER_DBNAME="azuresqldb"

# Define Azure Data Factory (ADF)
echo "Setting ADF environment variables"
# Resource name must be all lowercase
export ADF_NAME="${AZ_PREFIX}adf"
export ADF_LINKEDSVC="${ADF_NAME}LinkedService"

# Define our exported environment file
export ENV_FILENAME="env.azure.sh"

# Define our dirs/folders to upload
export AZ_STORAGE_SCRIPTSDIR_DS='datasets'
export AZ_STORAGE_SCRIPTSDIR_BASH='scriptsbash'
export AZ_STORAGE_SCRIPTSDIR_PS='scriptspowershell'
export AZ_STORAGE_SCRIPTSDIR_SQL='scriptssql'

# *******************************************************************
# Create a default resource group just in case
# *******************************************************************
echo ""
echo "Creating Resource Group... ${AZ_RG_NAME}"
export AZ_STATUS="$(az group create --name ${AZ_RG_NAME} --location ${AZ_REGION_PRIMARY} \
--query properties.provisioningState)"
echo ${AZ_STATUS}

# *******************************************************************
# Create a default VNET
# IPv4 address space	Enter 10.1.0.0/16.
# Subnet address range	Enter 10.1.0.0/24.
# Network Information - MS Azure Will grab 5 IPs for reserved
# .0 Network, .1 Gateway, .2/.3 DNS, .255 Broadcast
# *******************************************************************
# create shell variables
export AZ_VNET_NAME="MyVNET"
export AZ_VNET_ADDRESSPREFIX=10.0.0.0/16
# Bastion (RDP) Tier - requires /26 or larger (/25, /24)
export AZ_VNET_SUBNET_CIDR=10.0.0.0/26
# Subnets
export AZ_SUBNET_CIDR_BASTION=${AZ_VNET_SUBNET_CIDR}
export AZ_SUBNET_CIDR_FIREWALL=10.0.1.0/26
export AZ_SUBNET_CIDR_GATEWAY=10.0.2.0/27
# Infrastructure
export AZ_SUBNET_CIDR_INFRA=10.0.3.0/24
# Application Tier
export AZ_SUBNET_CIDR_APP=10.0.4.0/24
# Data Tier
export AZ_SUBNET_CIDR_DATA=10.0.5.0/24
# Private Endponts
export AZ_SUBNET_CIDR_PE=10.0.6.0/24

# Azure Subnet required names
export AZ_SUBNET_BASTION='AzureBastionSubnet'
# Azure Firewall Subnet/26
export AZ_SUBNET_FIREWALL='AzureFirewallManagementSubnet'
# Azure Gateway Subnet/27
export AZ_SUBNET_GATEWAY='GatewaySubnet'

# User defined subnets
export AZ_SUBNET_INFRA=subnetInfra
export AZ_SUBNET_APPLICATION=subnetApplication
export AZ_SUBNET_DATA=subnetData
export AZ_SUBNET_PRIVATE_ENDPOINTS=subnetPrivateEndpoints

# Private Links
export AZ_PRIVATE_DNS_NAME='my.devops.sandbox'
export AZ_PRIVATE_LINK_VNET='vnet-main'
export AZ_PRIVATE_LINK_SQLSERVER='dns-sqlserver'

# Our main VNET
echo "Creating VNET... ${AZ_VNET_NAME} and subnet ${AZ_SUBNET_BASTION}"
export AZ_STATUS="$(az network vnet create --name ${AZ_VNET_NAME} -g ${AZ_RG_NAME} --address-prefixes ${AZ_VNET_ADDRESSPREFIX} \
   --subnet-name ${AZ_SUBNET_BASTION} --subnet-prefixes ${AZ_VNET_SUBNET_CIDR} --location ${AZ_REGION_PRIMARY} \
   --query provisioningState)"
echo ${AZ_STATUS}

# Subnets for Networking (Bastion, Firewall, Gateway)
echo "Creating subnet... ${AZ_SUBNET_BASTION}"
export AZ_STATUS="$(az network vnet subnet create --resource-group ${AZ_RG_NAME} --name ${AZ_SUBNET_BASTION} \
   --vnet-name ${AZ_VNET_NAME} --address-prefixes ${AZ_SUBNET_CIDR_BASTION} \
   --disable-private-endpoint-network-policies false \
   --query provisioningState)"
echo ${AZ_STATUS}

echo "Creating subnet... ${AZ_SUBNET_FIREWALL}"
export AZ_STATUS="$(az network vnet subnet create --resource-group ${AZ_RG_NAME} --name ${AZ_SUBNET_FIREWALL} \
   --vnet-name ${AZ_VNET_NAME} --address-prefixes ${AZ_SUBNET_CIDR_FIREWALL} \
   --disable-private-endpoint-network-policies false \
   --query provisioningState)"
echo ${AZ_STATUS}

echo "Creating subnet... ${AZ_SUBNET_GATEWAY}"
export AZ_STATUS="$(az network vnet subnet create --resource-group ${AZ_RG_NAME} --name ${AZ_SUBNET_GATEWAY} \
   --vnet-name ${AZ_VNET_NAME} --address-prefixes ${AZ_SUBNET_CIDR_GATEWAY} \
   --disable-private-endpoint-network-policies false \
   --query provisioningState)"
echo ${AZ_STATUS}

# Subnets for Infrastructure
echo "Creating subnet... ${AZ_SUBNET_INFRA}"
export AZ_STATUS="$(az network vnet subnet create --resource-group ${AZ_RG_NAME} --name ${AZ_SUBNET_INFRA} \
   --vnet-name ${AZ_VNET_NAME} --address-prefixes ${AZ_SUBNET_CIDR_INFRA} \
   --disable-private-endpoint-network-policies false \
   --query provisioningState)"
echo ${AZ_STATUS}

# Subnets for Application tier
echo "Creating subnet... ${AZ_SUBNET_APPLICATION}"
export AZ_STATUS="$(az network vnet subnet create --resource-group ${AZ_RG_NAME} --name ${AZ_SUBNET_APPLICATION} \
   --vnet-name ${AZ_VNET_NAME} --address-prefixes ${AZ_SUBNET_CIDR_APP} \
   --disable-private-endpoint-network-policies false \
   --query provisioningState)"
echo ${AZ_STATUS}

# Subnets for Data tier
echo "Creating subnet... ${AZ_SUBNET_DATA}"
export AZ_STATUS="$(az network vnet subnet create --resource-group ${AZ_RG_NAME} --name ${AZ_SUBNET_DATA} \
   --vnet-name ${AZ_VNET_NAME} --address-prefixes ${AZ_SUBNET_CIDR_DATA} \
   --service-endpoints Microsoft.SQL \
   --disable-private-endpoint-network-policies false \
   --query provisioningState)"
echo ${AZ_STATUS}

# Subnets for Private Endpoints
echo "Creating subnet... ${AZ_SUBNET_PRIVATE_ENDPOINTS}"
export AZ_STATUS="$(az network vnet subnet create --resource-group ${AZ_RG_NAME} --name ${AZ_SUBNET_PRIVATE_ENDPOINTS} \
   --vnet-name ${AZ_VNET_NAME} --address-prefixes ${AZ_SUBNET_CIDR_PE} \
   --disable-private-endpoint-network-policies false \
   --query provisioningState)"
echo ${AZ_STATUS}


# Create our Private DNS Zones
echo "Creating private DNS zone... ${AZ_PRIVATE_DNS_NAME}"
export AZ_STATUS="$(az network private-dns zone create -g ${AZ_RG_NAME} --name "${AZ_PRIVATE_DNS_NAME}" --query provisioningState)"
echo ${AZ_STATUS}

# Create our Private DNS Link to our VNET
echo "Creating private DNS link... ${AZ_PRIVATE_LINK_VNET}"
export AZ_STATUS="$(az network private-dns link vnet create -g ${AZ_RG_NAME} --name "${AZ_PRIVATE_LINK_VNET}" \
   --virtual-network ${AZ_VNET_NAME} --registration-enabled false \
   --zone-name "${AZ_PRIVATE_DNS_NAME}" \
   --query provisioningState)"
echo ${AZ_STATUS}

# *******************************************************************
# *******************************************************************
echo "Allowing Azure extensions to install with prompt (no tty available)"
az config set extension.use_dynamic_install=yes_without_prompt

# Install any needed extensions
echo "Installing extensions..."
az extension add --name bastion --upgrade
az extension add --name containerapp --upgrade
az extension add --name portal --upgrade

# *******************************************************************
# Azure Bastion Setion.  Subnet must be /26 or larger and requires a
# Public IP (Standard SKU), Bastion default is Standard SKU
# *******************************************************************
echo ""
export AZ_BASTION_IP_NAME=MyBastionIP
export AZ_BASTION_NAME=MyBastion
export AZ_SKU_BASTION='Standard'
export AZ_SKU_PUBLIC_IP='Standard'

echo "Creating PublicIP for Azure Bastion Service...${AZ_BASTION_IP_NAME}"
az network public-ip create -g ${AZ_RG_NAME} --name ${AZ_BASTION_IP_NAME} --sku ${AZ_SKU_PUBLIC_IP} --location ${AZ_REGION_PRIMARY} --query provisioningState

echo "Creating Azure Bastion service ${AZ_BASTION_NAME} in ${AZ_VNET_NAME}... (no wait)"
az network bastion create -g ${AZ_RG_NAME} --name ${AZ_BASTION_NAME} --public-ip-address ${AZ_BASTION_IP_NAME} --vnet-name ${AZ_VNET_NAME} --location ${AZ_REGION_PRIMARY} --sku ${AZ_SKU_BASTION} --no-wait true

# *******************************************************************
# Create an Azure Log Analytics workspace for all diagnostic-settings
# *******************************************************************
# Create the resource
echo ""
echo "Checking Azure Log Analytics workspace avaibility..."

# Resource not avaliable in all clouds and regions
echo "Azure Log Analytics available only in certain regions"
if [[ "$CLOUDID" -eq 2 ]]; then
   AZ_REGION=${AZ_REGION_SECOND}
   echo "Required Secondary region ${AZ_REGION}"
elif [[ "$CLOUDID" -eq 1 ]]; then
   AZ_REGION=${AZ_REGION_SECOND}
   echo "Using Secondary region ${AZ_REGION}"
else
   AZ_REGION=${AZ_REGION_PRIMARY}
   echo "Using Region ${AZ_REGION}"
fi

# Create the resource
echo "Creating Azure Log Analytics workspace... ${AZ_LOG_ANALYTICS_WORKSPACE}"
export AZ_LOG_ANALYTICS_ID="$(az monitor log-analytics workspace create --location ${AZ_REGION} --resource-group ${AZ_RG_NAME} --workspace-name ${AZ_LOG_ANALYTICS_WORKSPACE} --query id --output tsv)"

# Retrieve the ClientID
export AZ_LOG_ANALYTICS_CLIENT_ID="$(az monitor log-analytics workspace show --query customerId -g ${AZ_RG_NAME} -n ${AZ_LOG_ANALYTICS_WORKSPACE} --output tsv)"
# Retrieve the Client Secret
export AZ_LOG_ANALYTICS_CLIENT_SECRET="$(az monitor log-analytics workspace get-shared-keys --query primarySharedKey -g ${AZ_RG_NAME} -n ${AZ_LOG_ANALYTICS_WORKSPACE} --output tsv)"

# List out the LogAnalytics Workspaces
echo "Listing Azure Log Analytics workspaces..."
az resource list --resource-type Microsoft.OperationalInsights/workspaces -o table

# *******************************************************************
# Create a general-purpose storage account in the prevous resource group
# For Azure Data Lake and Container folders need to enable Hierarchial
# Namespace: --enable-hierarchical-namespace or --hns
# *******************************************************************
echo ""
echo "Checking if storage account name is available...${AZ_STORAGEACCT_NAME}"
export AZ_STATUS="$(az storage account check-name --name ${AZ_STORAGEACCT_NAME} --query nameAvailable)"
echo "Storage Account name available = " ${AZ_STATUS}

echo "Creating Storage Account... ${AZ_STORAGEACCT_NAME}"
export AZ_STATUS="$(az storage account create \
   --resource-group ${AZ_RG_NAME} --location ${AZ_REGION_PRIMARY} \
   --sku ${AZ_SKU_STORAGE} --name ${AZ_STORAGEACCT_NAME} \
   --require-infrastructure-encryption true \
   --hns true --query provisioningState)"

# List all the accounts available
echo ${AZ_STATUS}

echo "Retrieving Storage Account ID... "
export AZ_STORAGEACCT_ID="$(az storage account show \
   --name ${AZ_STORAGEACCT_NAME} \
   --resource-group ${AZ_RG_NAME} \
   --query id -o tsv)"

echo "Retrieving Storage Account Key..."
export AZ_STORAGEACCT_KEY="$(az storage account keys list \
   --account-name ${AZ_STORAGEACCT_NAME} \
   --query [0].value -o tsv)"

# Create a Generic File Share
echo "Creating storage file share... ${AZ_STORAGE_FILE_SHARE}"
export AZ_STATUS="$(az storage share create --name ${AZ_STORAGE_FILE_SHARE} \
--account-name ${AZ_STORAGEACCT_NAME} --account-key ${AZ_STORAGEACCT_KEY})"
echo ${AZ_STATUS}

# Create File Share for Kubernetes
echo "Creating storage file share... ${AZ_STORAGE_FILE_SHARE_AKS}"
export AZ_STATUS="$(az storage share create --name ${AZ_STORAGE_FILE_SHARE_AKS} \
--account-name ${AZ_STORAGEACCT_NAME} --account-key ${AZ_STORAGEACCT_KEY})"
echo ${AZ_STATUS}

# Create a Blob Container
echo "Creating storage container... ${AZ_STORAGE_CONTAINER_BLOB}"
export AZ_STATUS="$(az storage container create --name ${AZ_STORAGE_CONTAINER_BLOB} \
  --account-name ${AZ_STORAGEACCT_NAME} --account-key ${AZ_STORAGEACCT_KEY})"
echo ${AZ_STATUS}

# Create the Terraform State Container
echo "Creating storage container... ${AZ_STORAGE_CONTAINER_TF}"
export AZ_STATUS="$(az storage container create --name ${AZ_STORAGE_CONTAINER_TF} \
  --account-name ${AZ_STORAGEACCT_NAME} --account-key ${AZ_STORAGEACCT_KEY})"
echo ${AZ_STATUS}

# Create a user upload Container
echo "Creating storage container... ${AZ_STORAGE_CONTAINER_UP}"
export AZ_STATUS="$(az storage container create --name ${AZ_STORAGE_CONTAINER_UP} \
  --account-name ${AZ_STORAGEACCT_NAME} --account-key ${AZ_STORAGEACCT_KEY})"
echo ${AZ_STATUS}

# Create raw data Container
echo "Creating storage container... ${AZ_STORAGE_CONTAINER_RAW}"
export AZ_STATUS="$(az storage container create --name ${AZ_STORAGE_CONTAINER_RAW} \
  --account-name ${AZ_STORAGEACCT_NAME} --account-key ${AZ_STORAGEACCT_KEY})"
echo ${AZ_STATUS}

# Create an enrichedcurated Container
echo "Creating storage container... ${AZ_STORAGE_CONTAINER_EC}"
export AZ_STATUS="$(az storage container create --name ${AZ_STORAGE_CONTAINER_EC} \
  --account-name ${AZ_STORAGEACCT_NAME} --account-key ${AZ_STORAGEACCT_KEY})"
echo ${AZ_STATUS}

# Create a directory under the specified shared
echo "Creating storage directory... ${AZ_STORAGE_SCRIPTSDIR_DS}"
export AZ_STATUS="$(az storage directory create --account-name ${AZ_STORAGEACCT_NAME} --account-key ${AZ_STORAGEACCT_KEY} \
  --share-name ${AZ_STORAGE_FILE_SHARE} --name ${AZ_STORAGE_SCRIPTSDIR_DS})"
echo ${AZ_STATUS}

echo "Creating storage directory... ${AZ_STORAGE_SCRIPTSDIR_BASH}"
export AZ_STATUS="$(az storage directory create --account-name ${AZ_STORAGEACCT_NAME} --account-key ${AZ_STORAGEACCT_KEY} \
  --share-name ${AZ_STORAGE_FILE_SHARE} --name ${AZ_STORAGE_SCRIPTSDIR_BASH})"
echo ${AZ_STATUS}

echo "Creating storage directory... ${AZ_STORAGE_SCRIPTSDIR_PS}"
export AZ_STATUS="$(az storage directory create --account-name ${AZ_STORAGEACCT_NAME} --account-key ${AZ_STORAGEACCT_KEY} \
  --share-name ${AZ_STORAGE_FILE_SHARE} --name ${AZ_STORAGE_SCRIPTSDIR_PS})"
echo ${AZ_STATUS}

echo "Creating storage directory... ${AZ_STORAGE_SCRIPTSDIR_SQL}"
export AZ_STATUS="$(az storage directory create --account-name ${AZ_STORAGEACCT_NAME} --account-key ${AZ_STORAGEACCT_KEY} \
  --share-name ${AZ_STORAGE_FILE_SHARE} --name ${AZ_STORAGE_SCRIPTSDIR_SQL})"
echo ${AZ_STATUS}

# Create Storage Queue
echo "Creating storage queue... ${AZ_STORAGE_QUEUE_DEVOPS}"
export AZ_STATUS="$(az storage queue create --account-name ${AZ_STORAGEACCT_NAME} --account-key ${AZ_STORAGEACCT_KEY} \
  --name ${AZ_STORAGE_QUEUE_DEVOPS})"
echo ${AZ_STATUS}


# *******************************************************************
# Create Private Endpoint for Storage Account
# *******************************************************************
echo ""
export AZ_PE_STORAGE='MyPE.Storage'
export AZ_PE_NIC_NAME_STORAGE='MyPE.nic.storage'
echo "Creating private endpoint... ${AZ_PE_STORAGE}"
export AZ_STATUS="$(az network private-endpoint create --connection-name storage --name ${AZ_PE_STORAGE} \
    --private-connection-resource-id ${AZ_STORAGEACCT_ID} \
    --resource-group ${AZ_RG_NAME} --location ${AZ_REGION_PRIMARY} \
    --vnet-name ${AZ_VNET_NAME} --subnet ${AZ_SUBNET_PRIVATE_ENDPOINTS} \
    --nic-name ${AZ_PE_NIC_NAME_STORAGE} --group-id file \
    --query properties.provisioningState)"
echo ${AZ_STATUS}

echo "Querying private endpoint IDs and IPs..."
export AZ_PE_INTERFACE_ID=$(az network private-endpoint show -g ${AZ_RG_NAME} --name ${AZ_PE_STORAGE} --query 'networkInterfaces[0].id' -o tsv)
export AZ_PE_INTERFACE_IP=$(az resource show --ids "${AZ_PE_INTERFACE_ID}" --query "properties.ipConfigurations[0].properties.privateIPAddress" -o tsv)

echo "Creating private DNS record... ${AZ_PRIVATE_DNS_NAME}"
az network private-dns record-set a create -g ${AZ_RG_NAME} --name ${AZ_PE_STORAGE} --zone-name "${AZ_PRIVATE_DNS_NAME}" --query fqdn --output tsv

echo "Adding private DNS record... ${AZ_PE_INTERFACE_IP}"
az network private-dns record-set a add-record -g ${AZ_RG_NAME} \
  --record-set-name ${AZ_PE_STORAGE} \
  --zone-name "${AZ_PRIVATE_DNS_NAME}" \
  --ipv4-address ${AZ_PE_INTERFACE_IP} \
  --query aRecords.ipv4Address --output tsv

#echo "Updating Storage Account public network access... Disabled"
#az storage account update --name ${AZ_STORAGEACCT_NAME} -g ${AZ_RG_NAME} --public-network-access Disabled

# *******************************************************************
# Azure Fileshare upload section
# *******************************************************************
echo ""
export AZ_README='readme.txt'
# Upload files - check if exists
if [ -f "${AZ_README}" ]; then
   echo "Fileshare upload: ${AZ_README}"
   az storage file upload --account-name ${AZ_STORAGEACCT_NAME} --account-key ${AZ_STORAGEACCT_KEY} \
     --share-name ${AZ_STORAGE_FILE_SHARE} --source ./${AZ_README}
fi

# Upload Powershell Scripts - check if directory exists
if [ -d "${AZ_STORAGE_SCRIPTSDIR_PS}" ]; then
   echo "Uploading Powershell file... AzMountShare.ps1"
   az storage file upload --account-name ${AZ_STORAGEACCT_NAME} --account-key ${AZ_STORAGEACCT_KEY} \
     --share-name ${AZ_STORAGE_FILE_SHARE} --source ./${AZ_STORAGE_SCRIPTSDIR_PS}/AzMountShare.ps1
   echo "Uploading Powershell file... DomainSetup.ps1"
   az storage file upload --account-name ${AZ_STORAGEACCT_NAME} --account-key ${AZ_STORAGEACCT_KEY} \
     --share-name ${AZ_STORAGE_FILE_SHARE} --source ./${AZ_STORAGE_SCRIPTSDIR_PS}/DomainSetup.ps1
   echo "Uploading Powershell file... DomainJoin.ps1"
   az storage file upload --account-name ${AZ_STORAGEACCT_NAME} --account-key ${AZ_STORAGEACCT_KEY} \
     --share-name ${AZ_STORAGE_FILE_SHARE} --source ./${AZ_STORAGE_SCRIPTSDIR_PS}/DomainJoin.ps1
fi

# Upload Azure Data Factory files
export AZ_ADF_DIR='adf'
# Check if directory exists
# if [ -d "${AZ_ADF_DIR}" ]; then
#    echo "Fileshare upload: ${AZ_ADF_DIR}"
#    # file #1
#    az storage file upload --account-name ${AZ_STORAGEACCT_NAME} --account-key ${AZ_STORAGEACCT_KEY} \
#      --share-name ${AZ_STORAGE_FILE_SHARE} --source ./${AZ_ADF_DIR}/datapipeline1.zip
#    # file #2
#    az storage file upload --account-name ${AZ_STORAGEACCT_NAME} --account-key ${AZ_STORAGEACCT_KEY} \
#      --share-name ${AZ_STORAGE_FILE_SHARE} --source ./${AZ_ADF_DIR}/datapipeline2.zip
# fi

# Upload SQL Script files
export AZ_SQL_FILE1='sqlserver_adf.sql'
# Check if directory exists
if [ -d "${AZ_STORAGE_SCRIPTSDIR_SQL}" ]; then
   echo "Fileshare upload SQL file... ${AZ_SQL_FILE1}"
   az storage file upload --account-name ${AZ_STORAGEACCT_NAME} --account-key ${AZ_STORAGEACCT_KEY} \
     --share-name ${AZ_STORAGE_FILE_SHARE} --source ./${AZ_STORAGE_SCRIPTSDIR_SQL}/${AZ_SQL_FILE1}
fi

# *******************************************************************
# Copy directories from fileshare to local cloudshell env
# Format: azcopy copy 'https://<storage-account-name>.file.core.windows.net/
# <file-share-name>/<directory-path><SAS-token>' '<local-directory-path>' --recursive
# echo "Azcopy from fileshare to local cloudshell environment"
# azcopy copy "https://${AZ_STORAGEACCT_NAME}.file.core.windows.net/${AZ_STORAGE_FILE_SHARE}/${AZ_STORAGE_SCRIPTSDIR_SQL}${AZ_STORAGEACCT_KEY}" "." --recursive
# *******************************************************************

# Enable Diagnostic settings
echo "Creating Azure Monitor diagnostics-settings for ${AZ_STORAGEACCT_NAME} to Workspace ${AZ_LOG_ANALYTICS_WORKSPACE}..."
az monitor diagnostic-settings create --resource ${AZ_STORAGEACCT_NAME} --resource-group ${AZ_RG_NAME} --resource-type Microsoft.Storage/storageaccounts -n "Storage Diagnostics" --workspace ${AZ_LOG_ANALYTICS_WORKSPACE} \
   --metrics '[{"category": "AllMetrics", "enabled": true, "retentionPolicy": {"days": 0, "enabled": false}, "timeGrain": "PT1M"}]'  \
   --output none

# *******************************************************************
# Azure KeyVault Section 
# *******************************************************************
echo ""
echo "Listing current Azure KeyVaults... Must be globally unique"
az keyvault list -o table
echo ""
echo "Listing currently deleted Azure KeyVaults..."
az keyvault list-deleted -o table
echo ""

echo "Checking for deleted Key Vault... ${AZ_KEYVAULT_NAME}"
# Check for deleted keyvaults that may need to be purged (-o table)
unset KV_EXISTS
export KV_EXISTS="$(az keyvault list-deleted -o tsv --query "[?name=='${AZ_KEYVAULT_NAME}']")"
# Checking if Keyvault already exists in deleted state first
if [ ! -z "$KV_EXISTS" ]; then
   echo "Keyvault ${AZ_KEYVAULT_NAME} exists in deleted state: Purging...";
   az keyvault purge --name $AZ_KEYVAULT_NAME
   # default is to wait
fi

# Now we can check if already exist (delete or not)
echo "Checking for an existing Key Vault... ${AZ_KEYVAULT_NAME}"
unset KV_EXISTS
export KV_EXISTS="$(az keyvault list -o tsv --query "[?name=='${AZ_KEYVAULT_NAME}'].{Name:name}")"

# Create an Azure Key Vault if it does not exist
if [ ! -z "$KV_EXISTS" ]; then
   echo "Keyvault already exists... ${AZ_KEYVAULT_NAME}"
   export AZ_KEYVAULT_ID="$(az keyvault show --name $AZ_KEYVAULT_NAME --query id -o tsv)"
   echo "Queried $AZ_KEYVAULT_ID"
else 
   echo "Creating Azure KeyVaults URI... ${AZ_KEYVAULT_NAME}.vault.azure.net"
   export AZ_KEYVAULT_ID="$(az keyvault create --resource-group $AZ_RG_NAME --location ${AZ_REGION_PRIMARY} --name ${AZ_KEYVAULT_NAME} --sku ${AZ_SKU_KEYVAULT} --query id -o tsv)"
fi

# Add a secret to the vault
echo "   Creating an Azure KeyVault Secret... Storage Key"
export AZ_SECRET_ID="$(az keyvault secret set --vault-name ${AZ_KEYVAULT_NAME} --name ${AZ_KV_SECRET_SAKEY} --value ${AZ_STORAGEACCT_KEY} --query id)"
echo "   Creating an Azure KeyVault Secret... VM credentials"
export AZ_SECRET_VMNAME_ID="$(az keyvault secret set --vault-name ${AZ_KEYVAULT_NAME} --name ${AZ_KV_SECRET_VMADMIN_USER} --value ${AZ_KV_SECRET_VMADMIN_PASSWORD} --query id)"

# Shows the value of the secret as plain text
#az keyvault secret show --vault-name ${AZ_KEYVAULT_NAME} --name <NAME> 

echo "Displaying Azure KeyVault Secret Names..."
# Shows all the Keyvault secrets
az keyvault secret list --vault-name ${AZ_KEYVAULT_NAME} --query "[].{Names: name}" --output table

# Enable Diagnostic settings
echo ""
echo "Creating Azure Monitor diagnostics-settings for ${AZ_KEYVAULT_NAME} to Workspace ${AZ_LOG_ANALYTICS_WORKSPACE}..."
az monitor diagnostic-settings create --resource ${AZ_KEYVAULT_NAME} --resource-group ${AZ_RG_NAME} --resource-type Microsoft.KeyVault/vaults -n "KeyVault Diagnostics" --workspace ${AZ_LOG_ANALYTICS_WORKSPACE} \
   --logs '[{"categoryGroup": "audit", "enabled": true, "retentionPolicy": {"days": 0, "enabled": false}}, 
            {"categoryGroup": "allLogs","enabled": true, "retentionPolicy": {"days": 0, "enabled": false}}]' \
   --metrics '[{"category": "AllMetrics", "enabled": true, "retentionPolicy": {"days": 0, "enabled": false}, "timeGrain": "PT1M"}]'  \
   --output none

# *******************************************************************
# Azure App Service Plans.
# Create an Azure App Service instance and specify the log workspace
# Use "--is-linux " for Linux image
# *******************************************************************
echo ""
echo "Creating App Service Plans... ${ASP_PLAN_WINDOWS}, ${ASP_PLAN_LINUX}"

# Need to check for Standard, Premium or Isolated SKUs.
# Free, Shared and Basic are not supported for deployment slots
echo "App Service Plan set to: ${AZ_SKU_ASP}"
slot=true
if [[ $AZ_SKU_ASP == "F1" ]]; then
   slot=false
elif [[ $AZ_SKU_ASP == "D1" ]]; then
   slot=false
elif [[ $AZ_SKU_ASP =~ B[1-3] ]]; then
   slot=false
else 
   echo "Deploment slots supported (Standard, Premium or Isoloated Tier)"
   slot=true
fi

echo "Creating App Service Plan... ${ASP_PLAN_WINDOWS}"
# Create the Windows plan
export ASP_WINDOWS_ID="$(az appservice plan create \
   --name ${ASP_PLAN_WINDOWS} \
   --resource-group ${AZ_RG_NAME} \
   --location ${AZ_REGION_PRIMARY} \
   --sku ${AZ_SKU_ASP} --query id --output tsv)"

echo "Creating App Service Plan... ${ASP_PLAN_LINUX}"
# Create the Linux Plan
export ASP_LINUX_ID="$(az appservice plan create \
   --name ${ASP_PLAN_LINUX} \
   --resource-group ${AZ_RG_NAME} \
   --location ${AZ_REGION_PRIMARY} \
   --is-linux \
   --sku ${AZ_SKU_ASP} --query id --output tsv)"

# We need to get the resource ID again
echo "Retrieving App Service Plan IDs..."
export ASP_LINUX_ID="$(az appservice plan show --name ${ASP_PLAN_LINUX} --resource-group ${AZ_RG_NAME} --query id -o tsv)"
export ASP_WINDOWS_ID="$(az appservice plan show --name ${ASP_PLAN_WINDOWS} --resource-group ${AZ_RG_NAME} --query id -o tsv)"

# This does not work using the Log Analytics Resource ID
echo "Creating Azure Monitor diagnostic-settings for ${ASP_PLAN_LINUX} in workspace... ${AZ_LOG_ANALYTICS_WORKSPACE}"
az monitor diagnostic-settings create --resource ${ASP_PLAN_LINUX} --resource-group ${AZ_RG_NAME} --resource-type Microsoft.Web/serverfarms --workspace ${AZ_LOG_ANALYTICS_WORKSPACE} --name "AppServicePlan Diagnostics" \
--metrics '[{"category": "AllMetrics", "enabled": true, "retentionPolicy": {"days": 0,"enabled": false}, "timeGrain": "PT1M"}]' --output none

echo "Creating Azure Monitor diagnostic-settings for ${ASP_PLAN_WINDOWS} in workspace... ${AZ_LOG_ANALYTICS_WORKSPACE}"
az monitor diagnostic-settings create --resource ${ASP_PLAN_WINDOWS} --resource-group ${AZ_RG_NAME} --resource-type Microsoft.Web/serverfarms --workspace ${AZ_LOG_ANALYTICS_WORKSPACE} --name "AppServicePlan Diagnostics" \
--metrics '[{"category": "AllMetrics", "enabled": true, "retentionPolicy": {"days": 0,"enabled": false}, "timeGrain": "PT1M"}]' --output none

# *******************************************************************
# Azure Web Apps tied to App Service Plans
# Install app insights component:
# Command to list runtimes:
# az webapp list-runtimes --subscription "${AZ_SUB_NAME}"
# az webapp list-runtimes --os-type windows|linux
# windows: "dotnet:7|6|3.1", "ASPNET:V4.8"
# linux: "DOTNETCORE:7.0|6.0|3.1"
# *******************************************************************
echo ""
export AZ_WEBAPP_RUNTIME="ASPNET:V4.8"
echo "Creating WebApp ${AZ_WEBAPP_NAME} with runtime ${AZ_WEBAPP_RUNTIME}..."

# Create an empty webapp
export AZ_WEBAPP_RESOURCE_ID="$(az webapp create \
   --name ${AZ_WEBAPP_NAME} \
   --resource-group ${AZ_RG_NAME} \
   --plan ${ASP_PLAN_WINDOWS} \
   --https-only true \
   --runtime ${AZ_WEBAPP_RUNTIME} --query id --out tsv)"

# Create a webapp slot (staging)
if [[ "$slot" == true ]]; then
AZ_WEBAPP_SLOT_NAME="Staging"
echo "Creating webapp deployment slot... ${AZ_WEBAPP_SLOT_NAME}"
export AZ_WEBAPP_SLOT_RESOURCE_ID="$(az webapp deployment slot create \
   --name ${AZ_WEBAPP_NAME} \
   --resource-group ${AZ_RG_NAME} \
   --slot ${AZ_WEBAPP_SLOT_NAME} --query id --out tsv)"
fi

echo "Enabling System Managed identity... creating security principal"
export AZ_SMI_WEBAPP="$(az webapp identity assign -g ${AZ_RG_NAME} -n ${AZ_WEBAPP_NAME}  --query principalId --output tsv)"
# List the Service principal that was created
# az ad sp show --id ${AZ_SMI_WEBAPP} --query servicePrincipalType

# Allow the identity to access Keyvault
# az keyvault set-policy --name ${AZ_KEYVAULT_NAME} -g ${AZ_RG_NAME} --object-id ${AZ_SMI_WEBAPP} --secret-permissions get list delete

# For ASP.NET and ASP.NET Core, setting app settings in App Service will override the ones
# in Web.config or appsettings.json.
echo "Setting appsettings environments..."
# For example: DOTNETCORE_ENVIRONMENT="Production|Test|Staging|Development"
# will use appsettings.<DOTNETCORE_ENVIRONMENT>.json
# --settings mySetting=value @moreSettings.json
az webapp config appsettings set -g ${AZ_RG_NAME} -n ${AZ_WEBAPP_NAME} \
   --settings ASPNETCORE_ENVIRONMENT="Development" --output none
az webapp config appsettings set -g ${AZ_RG_NAME} -n ${AZ_WEBAPP_NAME} \
   --settings DOTNETCORE_ENVIRONMENT="Development" --output none

# List the connection strings
echo "List the appsettings environments..."
az webapp config appsettings list -g ${AZ_RG_NAME} -n ${AZ_WEBAPP_NAME} --output table

echo "Setting connection-strings... sqlserver, sqlazure"
az webapp config connection-string set -g ${AZ_RG_NAME} -n ${AZ_WEBAPP_NAME} -t sqlserver \
  --settings sqlserver='data source=(localdb)\v11.0;initial catalog=master;integrated security=True;' --query sqlserver.type
az webapp config connection-string set -g ${AZ_RG_NAME} -n ${AZ_WEBAPP_NAME} -t sqlazure \
  --settings sqlazure='data source=(localdb)\v11.0;initial catalog=master;integrated security=True;' --query sqlazure.type

# List the connection strings
echo "Listing connection-strings..."
az webapp config connection-string list -g ${AZ_RG_NAME} -n ${AZ_WEBAPP_NAME} --output table

echo ""
echo "Setting Azure WebApp configuration settings...Incoming client certs requried"
az resource update --name ${AZ_WEBAPP_NAME} --resource-group ${AZ_RG_NAME} \
   --namespace Microsoft.Web --resource-type sites \
   --set properties.clientCertEnabled=true \
   properties.clientCertMode=Required \
   --query properties.clientCertMode --output tsv

# Enable Diagnostic settings
echo ""
echo "Creating Azure Monitoring diagnostics-settings for WebApp to Workspace ${AZ_LOG_ANALYTICS_WORKSPACE}"
az monitor diagnostic-settings create --resource ${AZ_WEBAPP_NAME} --resource-group ${AZ_RG_NAME} --resource-type Microsoft.Web/sites -n "WebApp Diagnostics" --workspace ${AZ_LOG_ANALYTICS_WORKSPACE} \
   --logs '[{"category": "AppServiceHTTPLogs", "enabled": true, "retentionPolicy": {"days": 0, "enabled": false}}, 
      {"category": "AppServiceConsoleLogs", "enabled": true, "retentionPolicy": {"days": 0, "enabled": false}},
      {"category": "AppServiceAppLogs", "enabled": true, "retentionPolicy": {"days": 0, "enabled": false}},
      {"category": "AppServiceAuditLogs", "enabled": true, "retentionPolicy": {"days": 0, "enabled": false}}]' \
   --metrics '[{"category": "AllMetrics", "enabled": true, "retentionPolicy": {"days": 0, "enabled": false}, "timeGrain": "PT1M"}]'  \
   --output none

# *******************************************************************
# Azure Application Insights
# *******************************************************************
echo ""
echo "Installing Application Insights Extension..."
az extension add --upgrade -n application-insights

# App Insights not avaliable in all regions
echo "Azure App Insights available only in certain regions"
if [[ "$CLOUDID" -eq 2 ]]; then
   AZ_REGION=${AZ_REGION_SECOND}
   echo "Required Secondary region ${AZ_REGION}"
elif [[ "$CLOUDID" -eq 1 ]]; then
   AZ_REGION=${AZ_REGION_SECOND}
   echo "Using Secondary region ${AZ_REGION}"
else
   AZ_REGION=${AZ_REGION_PRIMARY}
   echo "Using Region ${AZ_REGION}"
fi

# Create the resource
echo "Creating Application Insights... ${AZ_APP_INSIGHTS_NAME}"
export AZ_APP_INSIGHTS_ID="$(az monitor app-insights component create --resource-group ${AZ_RG_NAME} \
   --app ${AZ_APP_INSIGHTS_NAME} \
   --location ${AZ_REGION} \
   --kind web --application-type web \
   --retention-time 120 \
   --query id --output tsv)"

# az monitor app-insights component connect-webapp --resource-group ${AZ_RG_NAME} \
#    --app ${AZ_WEBAPP_NAME} --web-app ContosoApp8765 --enable-debugger false --enable-profiler false

# *******************************************************************
# Azure Functions - We will use our existing Storage Account,
# App Service Plans and App Insights resources.  Create one
# for each type of plan.
# az functionapp list-runtimes
# Supported runtimes for os linux are: ['dotnet-isolated', 'dotnet-isolated',
# 'dotnet', 'node', 'node', 'node', 'python', 'python', 'python', 'python',
# 'java', 'java', 'java', 'powershell', 'custom']
# *******************************************************************
echo ""
echo "Creating Azure Functions App... ${AFA_WINDOWS}"

export AFA_WIN_RESOURCE_ID="$(az functionapp create --name ${AFA_WINDOWS} \
   --resource-group ${AZ_RG_NAME} \
   --storage-account ${AZ_STORAGEACCT_NAME} \
   --app-insights ${AZ_APP_INSIGHTS_NAME} \
   --plan ${ASP_PLAN_WINDOWS} \
   --https-only true \
   --os-type "Windows" \
   --runtime "dotnet" \
   --functions-version ${AFA_VERSION} \
   --query id --output tsv)"

echo "Creating Azure Functions App... ${AFA_LINUX}"
export AFA_LINUX_RESOURCE_ID="$(az functionapp create --name ${AFA_LINUX} \
   --resource-group ${AZ_RG_NAME} \
   --storage-account ${AZ_STORAGEACCT_NAME} \
   --app-insights ${AZ_APP_INSIGHTS_NAME} \
   --plan ${ASP_PLAN_LINUX} \
   --https-only true \
   --os-type "Linux" \
   --runtime "dotnet" \
   --functions-version ${AFA_VERSION} \
   --query id --output tsv)"

echo "Setting Azure Functions configuration settings...ftpsOnly"
az functionapp config set --name ${AFA_WINDOWS} --resource-group ${AZ_RG_NAME} --ftps-state ftpsOnly --query ftpsonly --output tsv
az functionapp config set --name ${AFA_LINUX}   --resource-group ${AZ_RG_NAME} --ftps-state ftpsOnly --query ftpsonly --output tsv
# echo "Setting Azure Functions configuration security...https-only"
# az functionapp update --name ${AFA_WINDOWS} --resource-group ${AZ_RG_NAME} --set httpsOnly=true --query httpsonly --output tsv
# az functionapp update --name ${AFA_LINUX} --resource-group ${AZ_RG_NAME} --set httpsOnly=true --query httpsonly --output tsv

echo "Setting Azure Functions configuration settings...Incoming client certs required"
az resource update --name ${AFA_WINDOWS} --resource-group ${AZ_RG_NAME} \
   --namespace Microsoft.Web --resource-type sites \
   --set properties.clientCertEnabled=true \
   properties.clientCertMode=Required \
   --query properties.clientCertMode --output tsv
az resource update --name ${AFA_LINUX} --resource-group ${AZ_RG_NAME} \
   --namespace Microsoft.Web --resource-type sites \
   --set properties.clientCertEnabled=true \
   properties.clientCertMode=Required \
   --query properties.clientCertMode --output tsv

# Enable Diagnostic settings
echo ""
echo "Creating Azure Monitoring diagnostics-settings for Azure Function ${AFA_WINDOWS} to Workspace ${AZ_LOG_ANALYTICS_WORKSPACE}"
az monitor diagnostic-settings create --resource ${AFA_WINDOWS} --resource-group ${AZ_RG_NAME} --resource-type Microsoft.Web/sites -n "AFA Diagnostics" --workspace ${AZ_LOG_ANALYTICS_WORKSPACE} \
   --logs '[{"category": "FunctionAppLogs", "enabled": true, "retentionPolicy": {"days": 0, "enabled": false}}]' \
   --metrics '[{"category": "AllMetrics", "enabled": true, "retentionPolicy": {"days": 0, "enabled": false}, "timeGrain": "PT1M"}]'  \
   --output none

echo "Creating Azure Monitoring diagnostics-settings for Azure Function ${AFA_LINUX} to Workspace ${AZ_LOG_ANALYTICS_WORKSPACE}"
az monitor diagnostic-settings create --resource ${AFA_LINUX} --resource-group ${AZ_RG_NAME} --resource-type Microsoft.Web/sites -n "AFA Diagnostics" --workspace ${AZ_LOG_ANALYTICS_WORKSPACE} \
   --logs '[{"category": "FunctionAppLogs", "enabled": true, "retentionPolicy": {"days": 0, "enabled": false}}]' \
   --metrics '[{"category": "AllMetrics", "enabled": true, "retentionPolicy": {"days": 0, "enabled": false}, "timeGrain": "PT1M"}]'  \
   --output none

# List our function apps
echo "Listing Azure Functions Apps..."
az functionapp list -o table

# *******************************************************************
# Azure Containers Instance 
# *******************************************************************
echo ""
echo "Creating Container Instance... ${ACI_NAME}"

export ACI_RESOURCE_ID="$(az container create \
   --name ${ACI_NAME} \
   --resource-group ${AZ_RG_NAME}  \
   --image mcr.microsoft.com/azure-cli:latest \
   --query id --output tsv)"

# List our containers
az container list -o table

# *******************************************************************
# Azure Containers App Section - currently need to be in eastus region
# Create an Azure ACA instance and specify the log workspace
# Install Azure Container App extension to CLI
# az extension update --name containerapp
# Register the Microsoft.Web namespace
# az provider register --namespace Microsoft.Web
# az provider show -n Microsoft.App --query 'resourceTypes[?resourceType=='containerApps'].locations'
# *******************************************************************
echo ""

# Only create if in Azure Commercial cloud
if [[ "$CLOUDID" -eq 0 ]]; then

echo "Installing Container App Extension..."
# Requires installing extension
# az extension add --name containerapp --upgrade
# az extension add --yes \
#   --source https://workerappscliextension.blob.core.windows.net/azure-cli-extension/containerapp-0.3.21-py2.py3-none-any.whl

# If the existing version (eg in CloudShell) exists we need to update
az extension update --name containerapp

echo "Creating Container App Environment... ${ACA_ENV} in secondary region ${AZ_REGION_SECOND}"
# Create Container App Environment - Contains 1 or more Container Apps
export ACA_ENV_ID="$(az containerapp env create \
   --name ${ACA_ENV} \
   --resource-group ${AZ_RG_NAME}  \
   --location ${AZ_REGION_SECOND} \
   --logs-destination log-analytics \
   --logs-workspace-id  ${AZ_LOG_ANALYTICS_CLIENT_ID} \
   --logs-workspace-key ${AZ_LOG_ANALYTICS_CLIENT_SECRET} \
   --query id --output tsv)"

   # Create one Container App
echo "Creating Container App... ${ACA_NAME} in ${ACA_ENV}"
export ACA_RESOURCE_ID="$(az containerapp create \
   --name ${ACA_NAME} \
   --resource-group ${AZ_RG_NAME}  \
   --environment ${ACA_ENV} \
   --image mcr.microsoft.com/azuredocs/containerapps-helloworld:latest \
   --target-port 80 \
   --ingress 'external' \
   --query id --output tsv)"
#   --query configuration.ingress.fqdndn \

#Need to get ID again (Preview/Bug in above?)
export ACA_RESOURCE_ID="$(az containerapp show --name ${ACA_NAME} --resource-group ${AZ_RG_NAME} --query id --output tsv)"

else
   echo "ContainerApp Env not avialable in Gov cloud...skipping"
fi

# *******************************************************************
# Azure Containers Registry (ACR) Section
# Create an Azure ACR instance
# ACR_NAME: The name of your Azure Container Registry
# SERVICE_PRINCIPAL_NAME: Must be unique within your AD tenant
# *******************************************************************
echo ""

# App Insights not avaliable in all regions
echo "Azure Container Registry available only in certain regions"
if [[ "$CLOUDID" -eq 2 ]]; then
   AZ_REGION=${AZ_REGION_SECOND}
   echo "Required Secondary region ${AZ_REGION}"
elif [[ "$CLOUDID" -eq 1 ]]; then
   AZ_REGION=${AZ_REGION_SECOND}
   echo "Using Secondary region ${AZ_REGION}"
else
   AZ_REGION=${AZ_REGION_PRIMARY}
   echo "Using Region ${AZ_REGION}"
fi

echo "Checking for existing Azure ACR... ${ACR_NAME}"
export ACR_EXISTS="$(az acr list --output tsv --query "[?name=='${ACR_NAME}']")"

# Check if ACR already exists
if [ ! -z "$ACR_EXISTS" ]; then
  echo "ACR already exists" 
  export ACR_REGISTRY_ID="$(az acr show --name ${ACR_NAME} --query id --output tsv)"
  echo "Queried ACR_REGISTRY_ID"
else
   # Create an Azure ACR
   echo "Creating Azure ACR... ${ACR_NAME}"
  # Save the registry ID for subsequent command args
   export ACR_REGISTRY_ID="$(az acr create --name ${ACR_NAME} --location ${AZ_REGION} --resource-group ${AZ_RG_NAME} --sku ${AZ_SKU_ACR} --query id --output tsv)"

# Enable Diagnostic settings
echo "Creating Azure Monitoring diagnostics-settings for ACR to Workspace ${AZ_LOG_ANALYTICS_WORKSPACE}"
az monitor diagnostic-settings create --resource ${ACR_NAME} --resource-group ${AZ_RG_NAME} --resource-type Microsoft.ContainerRegistry/registries -n "ACR Diagnostics" --workspace ${AZ_LOG_ANALYTICS_WORKSPACE} \
   --logs '[{"categoryGroup": "audit", "enabled": true, "retentionPolicy": {"days": 0, "enabled": false}}, 
            {"categoryGroup": "allLogs","enabled": true, "retentionPolicy": {"days": 0, "enabled": false}}]' \
   --metrics '[{"category": "AllMetrics", "enabled": true, "retentionPolicy": {"days": 0, "enabled": false}, "timeGrain": "PT1M"}]'  \
   --output none
fi

# Enable the admin for the ACR
# az acr update -n ${ACR_NAME} --admin-enabled true
# Connect ACR to Azure Log Analytics
# https://www.thorsten-hans.com/azure-container-registry-unleashed-integrate-acr-and-azure-monitor/

# *******************************************************************
# Azure SQL Server and DB section
# *******************************************************************
echo ""

# We need to get the Azure AD user
export AZ_AD_USERID="$(az account show --query id -o tsv)"
#export AZ_AD_USERID="$(az ad user show --id ${AZ_AAD_USERNAME} --query id -o tsv)"

# Create the resource
echo "Creating Azure SQL Server... ${SQLSERVER_NAME}"
export AZ_SQLSERVER_ID="$(az sql server create -g ${AZ_RG_NAME} -l ${AZ_REGION} --name ${SQLSERVER_NAME} \
  --enable-ad-only-auth --external-admin-name ${AZ_AAD_USERNAME} --external-admin-sid ${AZ_AD_USERID} --query id -o tsv)"
#  --admin-user ${AZ_KV_SECRET_VMADMIN_USER} --admin-password ${AZ_KV_SECRET_VMADMIN_PASSWORD} 

# Create databases
echo "Creating Azure SQL Server database... ${SQLSERVER_DBNAME}"
export AZ_SQL_DB="$(az sql db create -g ${AZ_RG_NAME} --server ${SQLSERVER_NAME} --name ${SQLSERVER_DBNAME} --query id -o tsv)"

# Create Private Endpoint for SQL Server
export AZ_PE_SQLSERVER='MyPE.SQLServer'
export AZ_PE_NIC_NAME_SQLSERVER='MyPE.nic.sqlserver'

echo "Creating private endpoint... ${AZ_PE_SQLSERVER}"
export AZ_STATUS="$(az network private-endpoint create --connection-name sql --name ${AZ_PE_SQLSERVER} \
    --private-connection-resource-id ${AZ_SQLSERVER_ID} \
    --resource-group ${AZ_RG_NAME} --location ${AZ_REGION_PRIMARY} \
    --vnet-name ${AZ_VNET_NAME} --subnet ${AZ_SUBNET_PRIVATE_ENDPOINTS} \
    --nic-name ${AZ_PE_NIC_NAME_SQLSERVER} --group-id 'SQLServer' \
    --query properties.provisioningState)"
echo ${AZ_STATUS}

echo "Querying private endpoint IDs and IPs..."
export AZ_PE_SQL_INTERFACE_ID=$(az network private-endpoint show -g ${AZ_RG_NAME} --name ${AZ_PE_SQLSERVER} --query 'networkInterfaces[0].id' -o tsv)
export AZ_PE_SQL_INTERFACE_IP=$(az resource show --ids "${AZ_PE_SQL_INTERFACE_ID}" --query "properties.ipConfigurations[0].properties.privateIPAddress" -o tsv)

echo "Creating private DNS record... ${AZ_PRIVATE_DNS_NAME}"
az network private-dns record-set a create -g ${AZ_RG_NAME} --name ${AZ_PE_SQLSERVER} --zone-name "${AZ_PRIVATE_DNS_NAME}" --query fqdn --output tsv

echo "Adding private DNS record... ${AZ_PE_SQL_INTERFACE_IP}"
az network private-dns record-set a add-record -g ${AZ_RG_NAME} \
  --record-set-name ${AZ_PE_SQLSERVER} \
  --zone-name "${AZ_PRIVATE_DNS_NAME}" \
  --ipv4-address ${AZ_PE_SQL_INTERFACE_IP} --query aRecords.ipv4Address --output tsv

# Add VNet firewall rule to allow service endpoints to connect
echo "Adding SQL Server VNET rule... ${AZ_VNET_NAME} ${AZ_SUBNET_DATA}"
az sql server vnet-rule create -g ${AZ_RG_NAME} --vnet-name ${AZ_VNET_NAME} \
   --subnet ${AZ_SUBNET_DATA} --server ${SQLSERVER_NAME} --name MyVNetRule \
   --query state

# *******************************************************************
# Azure Data Factory (ADF) section
# *******************************************************************
echo ""
echo "Installing/Updating Extension: AzureDataFactory"
az extension add --upgrade --name datafactory

echo "Registering Provider: Microsoft.DataFactory"
az provider register --namespace Microsoft.DataFactory

# Resource not avaliable in all clouds and regions
echo "Azure Data Factory available only in certain regions"
if [[ "$CLOUDID" -eq 2 ]]; then
   AZ_REGION=${AZ_REGION_SECOND}
   echo "Required Secondary region ${AZ_REGION}"
elif [[ "$CLOUDID" -eq 1 ]]; then
   AZ_REGION=${AZ_REGION_SECOND}
   echo "Using Secondary region ${AZ_REGION}"
else
   AZ_REGION=${AZ_REGION_PRIMARY}
   echo "Using Region ${AZ_REGION}"
fi

# Create the resource
AZ_ADF_LINKED_TEMPLATE='jsonfiles/AzureStorageLinkedService.template.json'
AZ_ADF_LINKED_JSON=`echo ${AZ_ADF_LINKED_TEMPLATE} | sed 's/.template//g'`

echo "Creating Azure Data Factory... ${ADF_NAME}"
export AZ_ADF_ID="$(az datafactory create -g ${AZ_RG_NAME} -l ${AZ_REGION} --factory-name ${ADF_NAME} --query identity.principalId --output tsv)"

# Need to create JSON file from template
if [ -f "${AZ_ADF_LINKED_TEMPLATE}" ]; then
   echo "ADF Linked Template found: ${AZ_ADF_LINKED_TEMPLATE}"
   export AZ_SA_BLOB_EP="$(az storage account show -g $AZ_RG_NAME -n $AZ_STORAGEACCT_NAME --query "primaryEndpoints.blob" -o tsv)"
   sed "s|<TOKEN_BLOBSTORAGE_ENDPOINT>|${AZ_SA_BLOB_EP}|g" ${AZ_ADF_LINKED_TEMPLATE} > ${AZ_ADF_LINKED_JSON}
   echo "ADF Linked jsonfile created: ${AZ_ADF_LINKED_JSON}"
fi

AZ_ADF_JSON_PIPELINE='Adfv2QuickStartPipeline.json'
AZ_ADF_JSON_INPUT='InputDataset.json'
AZ_ADF_JSON_OUTPUT='OutputDataset.json'
if [ -f "${AZ_ADF_JSON_PIPELINE}" ]; then
   mv ${AZ_ADF_JSON_PIPELINE} jsonfiles/
fi
if [ -f "${AZ_ADF_JSON_INPUT}" ]; then
   mv ${AZ_ADF_JSON_INPUT} jsonfiles/
fi
if [ -f "${AZ_ADF_JSON_OUTPUT}" ]; then
   mv ${AZ_ADF_JSON_OUTPUT} jsonfiles/
fi

# Create a Linked Service
echo "Creating Azure Data Factory Linked Service... AzureStorageLinkedService"
export AZ_STATUS="$(az datafactory linked-service create --resource-group ${AZ_RG_NAME} \
    --factory-name ${ADF_NAME} --linked-service-name AzureStorageLinkedService \
    --properties @jsonfiles/AzureStorageLinkedService.json \
    --query properties.provisioningState)"
echo $AZ_STATUS

# Create the Datasets
echo "Creating Azure Data Factory Input Dataset... sample"
export AZ_ADF_DS_INPUT1_ID="$(az datafactory dataset create --resource-group ${AZ_RG_NAME} \
   --dataset-name InputDataset --factory-name ${ADF_NAME} \
   --properties @jsonfiles/InputDataset.json)"

echo "Creating Azure Data Factory Output Data Set... sample"
export AZ_ADF_DS_OUTPUT1_ID="$(az datafactory dataset create --resource-group ${AZ_RG_NAME} \
   --dataset-name OutputDataset --factory-name ${ADF_NAME} \
   --properties @jsonfiles/OutputDataset.json)"

# Create an ADF Pipeline
export ADF_PIPELINE='Adfv2QuickStartPipeline'
echo "Creating Azure Data Factory Pipeline... ${ADF_PIPELINE}"
export AZ_ADF_PIPELINEID="$(az datafactory pipeline create --resource-group ${AZ_RG_NAME} \
   --factory-name ${ADF_NAME} --name ${ADF_PIPELINE} \
   --pipeline @jsonfiles/Adfv2QuickStartPipeline.json \
   --query id)"

# Run the ADF Pipeline
echo "Run the Azure Data Factory Pipeline..."
az datafactory pipeline create-run --resource-group ${AZ_RG_NAME} \
   --factory-name ${ADF_NAME} --name ${ADF_PIPELINE} -o table


# *******************************************************************
# Azure AD and Managed Identity Role Assignment
# *******************************************************************
echo ""
echo "Creating Azure Data Factory RBAC role assignments..."

# Create Contributor role for ADF to Storage Account
export AZ_AD_ROLEASSIGN_ADF_SA='Storage Blob Data Contributor'
echo "Creating AD role assignment (${AZ_AD_ROLEASSIGN_ADF_SA}): ADF Identity to storage account"
export AZ_AD_ROLEASSIGN_PRINCIPALID_ADF1="$(az role assignment create --role "${AZ_AD_ROLEASSIGN_ADF_SA}" \
   --assignee-principal-type ServicePrincipal \
   --assignee-object-id ${AZ_ADF_ID} --scope ${AZ_STORAGEACCT_ID} --query principalId -o tsv)"

# Create Contributor role for ADF to SQL Server
export AZ_AD_ROLEASSIGN_ADF_SQL='Contributor'
echo "Creating AD role assignment (${AZ_AD_ROLEASSIGN_ADF_SQL}): ADF Identity to SQL Server"
export AZ_AD_ROLEASSIGN_PRINCIPALID_ADF2="$(az role assignment create --role "${AZ_AD_ROLEASSIGN_ADF_SQL}" \
   --assignee-principal-type ServicePrincipal \
   --assignee-object-id ${AZ_ADF_ID} --scope ${AZ_SQLSERVER_ID} --query principalId -o tsv)"

# Enable Diagnostic settings
echo "Creating Azure Monitoring diagnostics-settings for ADF to Workspace ${AZ_LOG_ANALYTICS_WORKSPACE}"
# az monitor diagnostic-settings create --resource ${ADF_NAME} --resource-group ${AZ_RG_NAME} --resource-type Microsoft.DataFactory/factories -n "ADF Diagnostics" --workspace ${AZ_LOG_ANALYTICS_WORKSPACE} --logs "[{\"category\":\"PipelineRuns\",\"enabled\":true}]"
# az monitor diagnostic-settings create --resource ${ADF_NAME} --resource-group ${AZ_RG_NAME} --resource-type Microsoft.DataFactory/factories -n "ADF Diagnostics" --workspace ${AZ_LOG_ANALYTICS_WORKSPACE} --logs '@diagnostics2.json'"
az monitor diagnostic-settings create --resource ${ADF_NAME} --resource-group ${AZ_RG_NAME} --resource-type Microsoft.DataFactory/factories -n "ADF Diagnostics" --workspace ${AZ_LOG_ANALYTICS_WORKSPACE} \
   --logs '[
     {"category": "PipelineRuns", "enabled": true, "retentionPolicy": {"days": 0, "enabled": false}},
     {"category": "ActivityRuns", "enabled": true, "retentionPolicy": {"days": 0, "enabled": false}},
     {"category": "TriggerRuns", "enabled": true, "retentionPolicy": {"days": 0, "enabled": false}}]' \
   --metrics '[ {"category": "AllMetrics", "enabled": true, "retentionPolicy": {"days": 0, "enabled": false}, "timeGrain": "PT1M"} ]'  \
   --output none


# *******************************************************************
# # Enable additional Diagnostic settings
# *******************************************************************
echo ""
echo "Additional Azure Monitor Diagnostics... ${AZ_VNET_NAME}"
az monitor diagnostic-settings create --resource ${AZ_VNET_NAME} --resource-group ${AZ_RG_NAME} --resource-type Microsoft.Network/virtualNetworks -n "VNET Diagnostics" --workspace ${AZ_LOG_ANALYTICS_WORKSPACE} \
   --logs '[{"categoryGroup": "allLogs","enabled": true, "retentionPolicy": {"days": 0, "enabled": false}}]' \
   --metrics '[{"category": "AllMetrics", "enabled": true, "retentionPolicy": {"days": 0, "enabled": false}, "timeGrain": "PT1M"}]'  \
   --output none

echo "Additional Azure Monitor Diagnostics... ${AZ_BASTION_NAME}"
az monitor diagnostic-settings create --resource ${AZ_BASTION_NAME} --resource-group ${AZ_RG_NAME} --resource-type Microsoft.Network/bastionHosts -n "Bastion Diagnostics" --workspace ${AZ_LOG_ANALYTICS_WORKSPACE} \
   --logs '[{"categoryGroup": "allLogs","enabled": true, "retentionPolicy": {"days": 0, "enabled": false}}]' \
   --metrics '[{"category": "AllMetrics", "enabled": true, "retentionPolicy": {"days": 0, "enabled": false}, "timeGrain": "PT1M"}]'  \
   --output none

echo "Additional Azure Monitor Diagnostics... ${AZ_BASTION_IP_NAME}"
az monitor diagnostic-settings create --resource ${AZ_BASTION_IP_NAME} --resource-group ${AZ_RG_NAME} --resource-type Microsoft.Network/publicIPAddresses -n "PublicIP Diagnostics" --workspace ${AZ_LOG_ANALYTICS_WORKSPACE} \
   --logs '[{"categoryGroup": "audit", "enabled": true, "retentionPolicy": {"days": 0, "enabled": false}}, 
            {"categoryGroup": "allLogs","enabled": true, "retentionPolicy": {"days": 0, "enabled": false}}]' \
   --metrics '[{"category": "AllMetrics", "enabled": true, "retentionPolicy": {"days": 0, "enabled": false}, "timeGrain": "PT1M"}]'  \
   --output none

# NICs


# *******************************************************************
# Azure Dashboards from json files
# *******************************************************************
echo ""
echo "Creating portal dashboard from template.json files..."

# Create the resource
AZ_DASHBOARD_TEMPLATE='jsonfiles/dashboards/Dashboard_Main.template.json'
AZ_DASHBOARD_JSON=`echo ${AZ_DASHBOARD_TEMPLATE} | sed 's/.template//g'`

sed "s|<TOKEN_LOCATION_REGION>|${AZ_REGION_PRIMARY}|g" ${AZ_DASHBOARD_TEMPLATE} > ${AZ_DASHBOARD_JSON}

export AZ_STATUS="$(az portal dashboard import --resource-group ${AZ_RG_NAME} --name 'MyDashboard' \
   --input-path ${AZ_DASHBOARD_JSON} --query properties.provisioningState)"
echo ${AZ_STATUS}

echo "Dashboard jsonfile created: ${AZ_DASHBOARD_JSON}"

# *******************************************************************
# End Script. Output bash environment variables for Azure CLI
# *******************************************************************
echo ""
echo "Completed script"
echo "Creating environment script ${ENV_FILENAME}"

# Output environment variables to a file
echo "# Environmnet varirable script" > ${ENV_FILENAME}
echo "# Set these environment variables for Azure CLI #" >> ${ENV_FILENAME}
echo "export AZ_AAD_USERNAME=${AZ_AAD_USERNAME}" >> ${ENV_FILENAME}
echo "export AZ_CURRENT_SUB='${AZ_CURRENT_SUB}'" >> ${ENV_FILENAME}
echo "export AZ_PREFIX=${AZ_PREFIX}" >> ${ENV_FILENAME}
echo "export AZ_RG_NAME=${AZ_RG_NAME}" >> ${ENV_FILENAME}
echo "export AZ_REGION_PRIMARY=${AZ_REGION_PRIMARY}" >> ${ENV_FILENAME}
echo "export AZ_REGION_SECOND=${AZ_REGION_SECOND}" >> ${ENV_FILENAME}
echo "export AZ_REGION=${AZ_REGION}" >> ${ENV_FILENAME}

# Output our SKU variables
echo "export AZ_SKU_STORAGE=${AZ_SKU_STORAGE}" >> ${ENV_FILENAME}
echo "export AZ_SKU_KEYVAULT=${AZ_SKU_KEYVAULT}" >> ${ENV_FILENAME}
echo "export AZ_SKU_ASP=${AZ_SKU_ASP}" >> ${ENV_FILENAME}
echo "export AZ_SKU_ACR=${AZ_SKU_ACR}" >> ${ENV_FILENAME}
echo "export AZ_SKU_BASTION=${AZ_SKU_BASTION}" >> ${ENV_FILENAME}
echo "export AZ_SKU_PUBLIC_IP=${AZ_SKU_PUBLIC_IP}" >> ${ENV_FILENAME}

# Network, VNets, DNS and Private Endpoints and Links
echo "export AZ_BASTION_NAME=${AZ_BASTION_NAME}" >> ${ENV_FILENAME}
echo "export AZ_BASTION_IP_NAME=${AZ_BASTION_IP_NAME}" >> ${ENV_FILENAME}
echo "export AZ_VNET_NAME=${AZ_VNET_NAME}" >> ${ENV_FILENAME}
echo "export AZ_VNET_ADDRESSPREFIX=${AZ_VNET_ADDRESSPREFIX}" >> ${ENV_FILENAME}
echo "export AZ_VNET_SUBNET_CIDR=${AZ_VNET_SUBNET_CIDR}" >> ${ENV_FILENAME}
echo "export AZ_PRIVATE_DNS_NAME=${AZ_PRIVATE_DNS_NAME}" >> ${ENV_FILENAME}
echo "export AZ_PRIVATE_LINK_VNET=${AZ_PRIVATE_LINK_VNET}" >> ${ENV_FILENAME}
echo "export AZ_PRIVATE_LINK_SQLSERVER=${AZ_PRIVATE_LINK_SQLSERVER}" >> ${ENV_FILENAME}

# Additional Subnets
echo "export AZ_SUBNET_BASTION=${AZ_SUBNET_BASTION}" >> ${ENV_FILENAME}
echo "export AZ_SUBNET_FIREWALL=${AZ_SUBNET_FIREWALL}" >> ${ENV_FILENAME}
echo "export AZ_SUBNET_GATEWAY=${AZ_SUBNET_GATEWAY}" >> ${ENV_FILENAME}
echo "export AZ_SUBNET_INFRA=${AZ_SUBNET_INFRA}" >> ${ENV_FILENAME}
echo "export AZ_SUBNET_APPLICATION=${AZ_SUBNET_APPLICATION}" >> ${ENV_FILENAME}
echo "export AZ_SUBNET_DATA=${AZ_SUBNET_DATA}" >> ${ENV_FILENAME}
# Private Endpoints
echo "export AZ_SUBNET_PRIVATE_ENDPOINTS=${AZ_SUBNET_PRIVATE_ENDPOINTS}" >> ${ENV_FILENAME}
# Subnet CIDRs
echo "export AZ_SUBNET_CIDR_BASTION=${AZ_SUBNET_CIDR_BASTION}" >> ${ENV_FILENAME}
echo "export AZ_SUBNET_CIDR_FIREWALL=${AZ_SUBNET_CIDR_FIREWALL}" >> ${ENV_FILENAME}
echo "export AZ_SUBNET_CIDR_GATEWAY=${AZ_SUBNET_CIDR_GATEWAY}" >> ${ENV_FILENAME}
echo "export AZ_SUBNET_CIDR_INFRA=${AZ_SUBNET_CIDR_INFRA}" >> ${ENV_FILENAME}
echo "export AZ_SUBNET_CIDR_APP=${AZ_SUBNET_CIDR_APP}" >> ${ENV_FILENAME}
echo "export AZ_SUBNET_CIDR_DATA=${AZ_SUBNET_CIDR_DATA}" >> ${ENV_FILENAME}
echo "export AZ_SUBNET_CIDR_PE=${AZ_SUBNET_CIDR_PE}" >> ${ENV_FILENAME}

# Storage section
echo "export AZ_STORAGEACCT_NAME=${AZ_STORAGEACCT_NAME}" >> ${ENV_FILENAME}
echo "export AZ_STORAGE_FILE_SHARE=${AZ_STORAGE_FILE_SHARE}" >> ${ENV_FILENAME}
echo "export AZ_STORAGE_CONTAINER_TF=${AZ_STORAGE_CONTAINER_TF}" >> ${ENV_FILENAME}
echo "export AZ_STORAGE_CONTAINER_BLOB=${AZ_STORAGE_CONTAINER_BLOB}" >> ${ENV_FILENAME}
echo "export AZ_STORAGE_CONTAINER_UP=${AZ_STORAGE_CONTAINER_UP}" >> ${ENV_FILENAME}
echo "export AZ_STORAGE_CONTAINER_RAW=${AZ_STORAGE_CONTAINER_RAW}" >> ${ENV_FILENAME}
echo "export AZ_STORAGE_CONTAINER_EC=${AZ_STORAGE_CONTAINER_EC}" >> ${ENV_FILENAME}
echo "export AZ_STORAGE_SCRIPTSDIR_DS=${AZ_STORAGE_SCRIPTSDIR_DS}" >> ${ENV_FILENAME}
echo "export AZ_STORAGE_SCRIPTSDIR_BASH=${AZ_STORAGE_SCRIPTSDIR_BASH}" >> ${ENV_FILENAME}
echo "export AZ_STORAGE_SCRIPTSDIR_PS=${AZ_STORAGE_SCRIPTSDIR_PS}" >> ${ENV_FILENAME}
echo "export AZ_STORAGE_SCRIPTSDIR_SQL=${SCRIPTSDIR_SQL}" >> ${ENV_FILENAME}
echo "export AZ_STORAGE_QUEUE_DEVOPS=${AZ_STORAGE_QUEUE_DEVOPS}" >> ${ENV_FILENAME}
# Private Endpoints
echo "export AZ_PE_STORAGE=${AZ_PE_STORAGE}" >> ${ENV_FILENAME}

# Keyvault section
echo "export AZ_KEYVAULT_NAME=${AZ_KEYVAULT_NAME}" >> ${ENV_FILENAME}
echo "export AZ_KV_SECRET_SAKEY=${AZ_KV_SECRET_SAKEY}" >> ${ENV_FILENAME}
echo "export AZ_KV_SECRET_VMADMIN_USER=${AZ_KV_SECRET_VMADMIN_USER}" >> ${ENV_FILENAME}

# Log Analytics
echo "export AZ_LOG_ANALYTICS_WORKSPACE=${AZ_LOG_ANALYTICS_WORKSPACE}" >> ${ENV_FILENAME}

# Azure App Service
echo "export ASP_PLAN_LINUX=${ASP_PLAN_LINUX}" >> ${ENV_FILENAME}
echo "export ASP_PLAN_WINDOWS=${ASP_PLAN_WINDOWS}" >> ${ENV_FILENAME}
# echo "export ASP_LINUX_ID=${ASP_LINUX_ID}" >> ${ENV_FILENAME}
# echo "export ASP_WINDOWS_ID=${ASP_WINDOWS_ID}" >> ${ENV_FILENAME}

# Azure WebApps 
echo "export AZ_WEBAPP_NAME=${AZ_WEBAPP_NAME}" >> ${ENV_FILENAME}
# echo "export AZ_WEBAPP_RESOURCE_ID=${AZ_WEBAPP_RESOURCE_ID}" >> ${ENV_FILENAME}
echo "export AZ_WEBAPP_RUNTIME=${AZ_WEBAPP_RUNTIME}" >> ${ENV_FILENAME}
#echo "export AZ_SMI_WEBAPP=${AZ_SMI_WEBAPP}" >> ${ENV_FILENAME}

# Azure Application Insights
echo "export AZ_APP_INSIGHTS_NAME=${AZ_APP_INSIGHTS_NAME}" >> ${ENV_FILENAME}

# Azure Functions
echo "export AFA_WINDOWS=${AFA_WINDOWS}" >> ${ENV_FILENAME}
echo "export AFA_LINUX=${AFA_LINUX}" >> ${ENV_FILENAME}
# echo "export AFA_WIN_RESOURCE_ID=${AFA_WIN_RESOURCE_ID}" >> ${ENV_FILENAME}
# echo "export AFA_LINUX_RESOURCE_ID=${AFA_LINUX_RESOURCE_ID}" >> ${ENV_FILENAME}
echo "export AFA_VERSION=${AFA_VERSION}" >> ${ENV_FILENAME}

# Azure Container Instance, App and Environment
echo "export ACI_NAME=${ACI_NAME}" >> ${ENV_FILENAME}
echo "export ACA_ENV=${ACA_ENV}" >> ${ENV_FILENAME}
echo "export ACA_NAME=${ACA_NAME}" >> ${ENV_FILENAME}
# echo "export ACI_RESOURCE_ID=${ACI_RESOURCE_ID}" >> ${ENV_FILENAME}
# echo "export ACA_RESOURCE_ID=${ACA_RESOURCE_ID}" >> ${ENV_FILENAME}

# Azure Container Registry
echo "export ACR_NAME=${ACR_NAME}" >> ${ENV_FILENAME}

# Azure SQL Server and Databases and Private Endpoints
echo "export SQLSERVER_NAME=${SQLSERVER_NAME}" >> ${ENV_FILENAME}
echo "export SQLSERVER_DBNAME=${SQLSERVER_DBNAME}" >> ${ENV_FILENAME}
# echo "export AZ_SQLSERVER_ID=${AZ_SQLSERVER_ID}" >> ${ENV_FILENAME}
echo "export AZ_PE_SQLSERVER=${AZ_PE_SQLSERVER}" >> ${ENV_FILENAME}
# echo "export AZ_PE_SQL_INTERFACE_ID=${AZ_PE_SQL_INTERFACE_ID}" >> ${ENV_FILENAME}
echo "export AZ_PE_SQL_INTERFACE_IP=${AZ_PE_SQL_INTERFACE_IP}" >> ${ENV_FILENAME}

# Azure Data Factory
echo "export ADF_NAME=${ADF_NAME}" >> ${ENV_FILENAME}
echo "export ADF_PIPELINE=${ADF_PIPELINE}" >> ${ENV_FILENAME}
echo "export AZ_AD_ROLEASSIGN_ADF_SA='${AZ_AD_ROLEASSIGN_ADF_SA}'" >> ${ENV_FILENAME}
echo "export AZ_AD_ROLEASSIGN_ADF_SQL='${AZ_AD_ROLEASSIGN_ADF_SQL}'" >> ${ENV_FILENAME}

# These have senstive info and need to be set dynamically
echo "### Need to set these dynamically ###"  >> ${ENV_FILENAME}
#echo 'export AZ_AD_USERID=$(az ad user show --id ${AZ_AAD_USERNAME} --query id -o tsv)' >> ${ENV_FILENAME}
echo 'export AZ_AD_USERID=$(az account show --query id -o tsv)' >> ${ENV_FILENAME}
echo 'export AZ_KEYVAULT_ID="$(az keyvault show --name $AZ_KEYVAULT_NAME --query id -o tsv)" ' >> ${ENV_FILENAME}
echo 'export AZ_KV_SECRET_VMADMIN_PASSWORD=$(az keyvault secret show --vault-name ${AZ_KEYVAULT_NAME} --name ${AZ_KV_SECRET_VMADMIN_USER} --query value)' >> ${ENV_FILENAME}
echo 'export AZ_STORAGEACCT_ID="$(az storage account show --name ${AZ_STORAGEACCT_NAME} --resource-group ${AZ_RG_NAME} --query id -o tsv)" ' >> ${ENV_FILENAME}
echo 'export AZ_STORAGEACCT_KEY="$(az storage account keys list --account-name ${AZ_STORAGEACCT_NAME} --query [0].value -o tsv)" ' >> ${ENV_FILENAME}
echo 'export AZ_ADF_ID="$(az datafactory show -g ${AZ_RG_NAME} --factory-name ${ADF_NAME} --query identity.principalId --output tsv)" ' >> ${ENV_FILENAME}
echo 'export ACR_REGISTRY_ID="$(az acr show --name ${ACR_NAME} --query id --output tsv)" ' >> ${ENV_FILENAME}
echo 'export AZ_APP_INSIGHTS_REGISTRY_ID="$(az monitor app-insights component show --resource-group ${AZ_RG_NAME} \
   --app ${AZ_APP_INSIGHTS_NAME} --query id --output tsv)" ' >> ${ENV_FILENAME}
echo 'export AZ_LOG_ANALYTICS_ID="$(az monitor log-analytics workspace show --query id -g ${AZ_RG_NAME} -n ${AZ_LOG_ANALYTICS_WORKSPACE} --out tsv)" '>> ${ENV_FILENAME}
echo 'export AZ_LOG_ANALYTICS_CLIENT_ID="$(az monitor log-analytics workspace show --query customerId -g ${AZ_RG_NAME} -n ${AZ_LOG_ANALYTICS_WORKSPACE} --out tsv)" ' >> ${ENV_FILENAME}
echo 'export AZ_LOG_ANALYTICS_CLIENT_SECRET="$(az monitor log-analytics workspace get-shared-keys --query primarySharedKey -g ${AZ_RG_NAME} -n ${AZ_LOG_ANALYTICS_WORKSPACE} --output tsv)" ' >> ${ENV_FILENAME}

# Upload environment script file to storage account
echo "Uploading environment script... ${ENV_FILENAME} to storage account "
az storage file upload --account-name ${AZ_STORAGEACCT_NAME} --account-key ${AZ_STORAGEACCT_KEY} \
 --share-name ${AZ_STORAGE_FILE_SHARE} --source ./${ENV_FILENAME} --output none

# Update file permissions
chmod 700 ${ENV_FILENAME}

# Display info to execute env
echo "Execute Bash script #. ${ENV_FILENAME}"

# Calculate and store the end time
endtime=`date +%s`
echo  ""
echo $((endtime-starttime)) | awk '{printf "Execution Time: %d hours %02d minutes %02d seconds", $1/3600, ($1/60)%60, $1%60}'
echo ""
