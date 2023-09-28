#!/bin/bash
# *******************************************************************
# Bash Azure CLI script to create an Azure Data Analytics Project
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
   echo -e "   [Workspace]       - Name of the Azure Data Analytics Workspace"
   echo -e "   [ResourceGroup]   - Resource Group for Azure Data Analytics"
   echo -e "   [Region Primary]  - Primary Region (See below)"
   echo -e "   [Region Second]   - Secondary Region (See below)"
   echo -e "   [KeyVault ID]        - Azure KeyVault name"
   echo -e "   [Container Reg ID]   - Azure Container Registry name"
   echo -e "   [Application Insights ID] - Azure Application Insights name"
   echo -e "   [LogAnaytics ID]    - Azure Log Analytics Workspace name"
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
if [ $# -le 4 ]
then 
   echo "Number of arguments $# is less than requried."
   display_usage
	exit 1
fi 

# store start time
starttime=`date +%s`

# Default Script output
export SCRIPT_VERSION="1.0.0"
echo "Starting script...$0 Version ${SCRIPT_VERSION}"
# Default Script output
echo "Number of arguments: $#"
# Remove the last string which is the password
args=("$@")
numargs=$#

echo "Echoing arguments (except for sensitive strings):"
# Display arguments info except for last one (password sensative)
for ((i=0; i<numargs; i++)); do
   echo "${args[$((i))]}"
done

# Export all our environment variables as global for other scripts
echo "Initializing environment variables..."
# Azure AD User
export AZ_AAD_USER=$1
# Get the Azure subscription
export AZ_SUBSCRIPTION=$2
# User alias or a unique prefix for global resources
export AZ_PREFIX=$3
# Main Workspace name
export AZ_DA_NAME=$4
# Main Resource Group Name
export AZ_DA_RESOURCE_GROUP=$5

# Define default locations: westus, westus2, westcentralus, eastus, eastus2
export AZ_DA_REGION_PRIMARY=$6
export AZ_DA_REGION_SECOND=$7
# Define the Azure services where going to integrate
# export AML_KV_ID=$8
# export AML_ACR_REGISTRY_ID=$9
# export AML_APPINSIGHTS_ID=$10
# export AML_LOGANALYTICS_ID=$1

# Define additonal environments variables
export AZ_DA_WORKSPACE="${AZ_PREFIX}SynapseWorkspace"
export AZ_DA_DATABRICKS="${AZ_PREFIX}DataBricksSvc"
export AZ_DA_SKU_STORAGE='Standard_LRS'
export AZ_DA_STORAGEACCT_NAME="${AZ_PREFIX}analyticsdatalake"
export AZ_DA_FILE_WORKSPACE="azda.workspace.yaml"
export AZ_DA_FILE_DATASTORE="azda.datastore.yaml"
export AZ_DA_FILE_DATASTORE_BLOB="azda.datastore.blob.yaml"
export AZ_DA_FILE_DATASTORE_DATALAKE="azda.datastore.dl.yaml"
export AZ_DA_FILE_DATASTORE_FILE="azda.datastore.file.yaml"

# Define our exported env script file
export AZ_ENV_DA_FILENAME="env.da.sh"

# *******************************************************************
# Set our secondary region based on the primary region (Commercial, Gov or DoD)
# *******************************************************************
echo "Determining primary and secondary regions based on Azure cloud..."
if [[ $AZ_DA_REGION_PRIMARY == *"usdod"* ]]; then
   echo "US DoD regions specified"
   echo "Required Secondary regions: usgovarizona | usgovtexas | usgovvirginia"
   export AZ_DA_REGION_SECOND=${AZ_DA_REGION_SECOND}
   CLOUDID=2
elif [[ $AZ_DA_REGION_PRIMARY == *"usgov"* ]]; then
   echo "US Gov regions specified"
   echo "Using Secondary region ${AZ_DA_REGION_SECOND}"
   CLOUDID=1
else 
   echo "Commercial regions specified"
   echo "Using Secondary region ${AZ_DA_REGION_SECOND}"
   CLOUDID=0
fi


# *******************************************************************
# Step #1 would be to Login into the portal and set the subscription
# Perform "az login" if running from local command windows
# Not needed if running from Cloud Shell.
# *******************************************************************
echo ""
echo "Setting Azure Subscription: \"${AZ_SUBSCRIPTION}\""
az account set --subscription "${AZ_SUBSCRIPTION}"
export AZ_CURRENT_SUB="$(az account show --query name)"
export AZ_AAD_USERNAME="$(az account show --query 'user.name' --output tsv)"
 
# In some instances the RGs need to be unique within a subscription
export AZ_RG_NAME="${AZ_RG_NAME}"


# *******************************************************************
# Create the Azure ML resource group.
# *******************************************************************
cho ""
echo "Creating Resource Group... ${AZ_DA_RESOURCE_GROUP}"
export AZ_STATUS="$(az group create --name ${AZ_DA_RESOURCE_GROUP} --location ${AZ_DA_REGION_PRIMARY} \
   --query properties.provisioningState)"
echo ${AZ_STATUS}

echo ""
# Resource not avaliable in all clouds and regions
# echo "Azure Machine Learning available only in certain regions"
if [[ "$CLOUDID" -eq 2 ]]; then
   AZ_DA_REGION=${AZ_DA_REGION_SECOND}
   echo "Required Secondary region ${AZ_DA_REGION}"
elif [[ "$CLOUDID" -eq 1 ]]; then
   AZ_DA_REGION=${AZ_DA_REGION_SECOND}
   echo "Using Secondary region ${AZ_DA_REGION}"
else
   AZ_DA_REGION=${AZ_DA_REGION_PRIMARY}
   echo "Using Region ${AZ_DA_REGION}"
fi


# *******************************************************************
# Obtain the Keyvault secrets for the SQL credentials.
# *******************************************************************
export AZ_SECRET_VMNAME_ID="$(az keyvault secret get
   --vault-name ${AZ_KEYVAULT_NAME} \
   --name ${AZ_KV_SECRET_VMADMIN_USER} \
   --query id)"

# *******************************************************************
# Azure Synapse Workspace section
# *******************************************************************
echo ""
# Create an Azure Synapse Workspace
echo "Creating Azure Synapse Workspace... ${AZ_DA_WORKSPACE}"
# Create an Azure ML Workspace and integrate with ACR and Application Insights
export AZ_DA_WORKSPACE_ID="$(az synapse workspace create \
   --name ${AZ_DA_WORKSPACE} \
   --resource-group ${AZ_DA_RESOURCE_GROUP} \
   --location ${AZ_DA_REGION} \
   --storage-account ${AZ_DA_STORAGEACCT_NAME} \
   --file-system ${AZ_DA_FILESHARE} \
   --sql-admin-login-user ${AZ_KV_SECRET_VMADMIN_USER} \
   --sql-admin-login-password ${AZ_KV_SECRET_VMADMIN_PASSWORD} \
   --query id --output tsv)"

# Now get Web and Dev URL for worskpace
WorkspaceWeb=$(az synapse workspace show --name $SynapseWorkspaceName --resource-group $SynapseResourceGroup | jq -r '.connectivityEndpoints | .web')
WorkspaceDev=$(az synapse workspace show --name $SynapseWorkspaceName --resource-group $SynapseResourceGroup | jq -r '.connectivityEndpoints | .dev')

# Create Firewall rule to allow access to workspace from local machine
ClientIP=$(curl -sb -H "Accept: application/json" "$WorkspaceDev" | jq -r '.message')
ClientIP=${ClientIP##'Client Ip address : '}

echo "Creating a firewall rule to enable access for IP address: $ClientIP"
az synapse workspace firewall-rule create --end-ip-address $ClientIP --start-ip-address $ClientIP --name "Allow Client IP" --resource-group $SynapseResourceGroup --workspace-name $SynapseWorkspaceName

echo "Open your Azure Synapse Workspace Web URL in the browser: $WorkspaceWeb"

# Once deployed additional permissions are required
echo "Additional RBAC permissions are required"


# *******************************************************************
# Create an Azure Databricks Service
# *******************************************************************
echo ""
# Create an Azure Databricks Workspace
echo "Creating Azure Databricks Service... ${AZ_DA_DATABRICKS}"
export AZ_DA_DATABRICKS_ID="$(az databricks workspace create -n ${AZ_DA_DATABRICKS} -g ${AZ_DA_RESOURCE_GROUP} \
   --location ${AZ_DA_REGION_PRIMARY} --sku trial \
   --query id --output tsv)"


# *******************************************************************
# Output final section
# *******************************************************************
echo ""
echo "Listing all Azure Databricks Workspaces..."
az databricks workspace list -g ${AZ_DA_RESOURCE_GROUP} --output table


# *******************************************************************
# End Script. Output bash environment variables for Azure CLI
# *******************************************************************
echo ""
echo "Completed script"
echo "Creating environment script ${AZ_ENV_DA_FILENAME}"
# Output environment variables to a file
echo "# Environmnet variables script" > ${AZ_ENV_DA_FILENAME}
# These should already be defined
# echo "# export AZ_AAD_USERNAME=${AZ_AAD_USERNAME}" >> ${AZ_ENV_DA_FILENAME}
# echo "# export AZ_CURRENT_SUB=${AZ_CURRENT_SUB}" >> ${AZ_ENV_DA_FILENAME}
# echo "# export AZ_PREFIX=${AZ_PREFIX}" >> ${AZ_ENV_DA_FILENAME}

echo "# Current environment variables generated by this script:" >> ${AZ_ENV_DA_FILENAME}
echo "export AZ_DA_RESOURCE_GROUP=${AZ_DA_RESOURCE_GROUP}" >> ${AZ_ENV_DA_FILENAME}
echo "export AZ_DA_REGION_PRIMARY=${AZ_DA_REGION_PRIMARY}" >> ${AZ_ENV_DA_FILENAME}
echo "export AZ_DA_REGION_SECOND=${AZ_DA_REGION_SECOND}" >> ${AZ_ENV_DA_FILENAME}
echo "export AZ_DA_REGION=${AZ_DA_REGION}" >> ${AZ_ENV_DA_FILENAME}
echo "export AZ_DA_WORKSPACE=${AZ_DA_WORKSPACE}" >> ${AZ_ENV_DA_FILENAME}
echo "export AZ_DA_DATABRICKS=${AZ_DA_DATABRICKS}" >> ${AZ_ENV_DA_FILENAME}
echo "export AZ_DA_SKU_STORAGE=${AZ_DA_SKU_STORAGE}" >> ${AZ_ENV_DA_FILENAME}
echo "export AZ_DA_STORAGEACCT_NAME=${AZ_DA_STORAGEACCT_NAME}" >> ${AZ_ENV_DA_FILENAME}

# # These have secret keys and need to be set manually
echo "### Need to set these dynamically ###"  >> ${AZ_ENV_DA_FILENAME}
# echo 'export AZ_DA_WORKSPACE_ID="$(az ml show -g ${AKS_RESOURCE_GROUP} -n ${AKS_NAME} --query identity.principalId -o tsv)" ' >> ${AZ_ENV_DA_FILENAME}

# Display info to execute env
echo "Execute Bash script #. ${AZ_ENV_DA_FILENAME}"

# Calculate and store the end time
endtime=`date +%s`
echo  ""
echo $((endtime-starttime)) | awk '{printf "Execution Time: %d hours %02d minutes %02d seconds", $1/3600, ($1/60)%60, $1%60}'
echo ""
