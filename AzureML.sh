#!/bin/bash
# *******************************************************************
# Bash Azure CLI script to create an Azure Machine Learning Workspace
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
   echo -e "   [ML Workspace]    - Name of the Azure ML Workspace"
   echo -e "   [ML RG]           - Resource Group for Azure ML"
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
# Main ML Workspace name
export AZ_ML_NAME=$4
# DevTest Lab Kubernetes name
export AZ_ML_RESOURCE_GROUP=$5
# Set default node size

# Define default locations: westus, westus2, westcentralus, eastus, eastus2
export AZ_ML_REGION_PRIMARY=$6
export AZ_ML_REGION_SECOND=$7
# Define the Azure services where going to integrate
# export AML_KV_ID=$8
# export AML_ACR_REGISTRY_ID=$9
# export AML_APPINSIGHTS_ID=$10
# export AML_LOGANALYTICS_ID=$1

# Define additonal environments variables
export AZ_ML_WORKSPACE="${AZ_PREFIX}MLWorkspace"
export AZ_ML_DATASTORE="${AZ_PREFIX}MLDatastore"
export AZ_ML_SKU_STORAGE='Standard_LRS'
export AZ_ML_STORAGEACCT_NAME="${AZ_PREFIX}mlstorage"
export AZ_ML_FILE_WORKSPACE="azml.workspace.yaml"
export AZ_ML_FILE_DATASTORE="azml.datastore.yaml"
export AZ_ML_FILE_DATASTORE_BLOB="azml.datastore.blob.yaml"
export AZ_ML_FILE_DATASTORE_DATALAKE="azml.datastore.dl.yaml"
export AZ_ML_FILE_DATASTORE_FILE="azml.datastore.file.yaml"

# Define our exported env script file
export AZ_ENV_ML_FILENAME="env.ml.sh"

# *******************************************************************
# Set our secondary region based on the primary region (Commercial, Gov or DoD)
# *******************************************************************
echo "Determining primary and secondary regions based on Azure cloud..."
if [[ $AZ_ML_REGION_PRIMARY == *"usdod"* ]]; then
   echo "US DoD regions specified"
   echo "Required Secondary regions: usgovarizona | usgovtexas | usgovvirginia"
   export AZ_ML_REGION_SECOND=${AZ_ML_REGION_SECOND}
   CLOUDID=2
elif [[ $AZ_ML_REGION_PRIMARY == *"usgov"* ]]; then
   echo "US Gov regions specified"
   echo "Using Secondary region ${AZ_ML_REGION_SECOND}"
   CLOUDID=1
else 
   echo "Commercial regions specified"
   echo "Using Secondary region ${AZ_ML_REGION_SECOND}"
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
echo ""
echo "Creating Resource Group... ${AZ_ML_RESOURCE_GROUP}"
export AZ_STATUS="$(az group create --name ${AZ_ML_RESOURCE_GROUP} --location ${AZ_ML_REGION_PRIMARY} \
   --query properties.provisioningState)"
echo ${AZ_STATUS}

echo ""
# Resource not avaliable in all clouds and regions
# echo "Azure Machine Learning available only in certain regions"
if [[ "$CLOUDID" -eq 2 ]]; then
   AZ_ML_REGION=${AZ_ML_REGION_SECOND}
   echo "Required Secondary region ${AZ_ML_REGION}"
elif [[ "$CLOUDID" -eq 1 ]]; then
   AZ_ML_REGION=${AZ_ML_REGION_SECOND}
   echo "Using Secondary region ${AZ_ML_REGION}"
else
   AZ_ML_REGION=${AZ_ML_REGION_PRIMARY}
   echo "Using Region ${AZ_ML_REGION}"
fi

# *******************************************************************
# Create a Azure Data Lake storage account in this resource group
# For Azure Machine Learning we need to disable the Hierarchial
# Namespace: --enable-hierarchical-namespace or --hns
# *******************************************************************
echo ""
echo "Checking if storage account name is available...${AZ_ML_STORAGEACCT_NAME}"
export AZ_STATUS="$(az storage account check-name --name ${AZ_ML_STORAGEACCT_NAME} --query nameAvailable)"
echo "Storage Account name available = " ${AZ_STATUS}

echo "Creating Storage Account... ${AZ_ML_STORAGEACCT_NAME}"
export AZ_STATUS="$(az storage account create \
   --resource-group ${AZ_ML_RESOURCE_GROUP} --location ${AZ_ML_REGION_PRIMARY} \
   --sku ${AZ_ML_SKU_STORAGE} --name ${AZ_ML_STORAGEACCT_NAME} \
   --hns false --query provisioningState)"

# List all the accounts available
echo ${AZ_STATUS}

echo "Retrieving Storage Account ID... "
export AML_STORAGEACCT_ID="$(az storage account show \
   --name ${AZ_ML_STORAGEACCT_NAME} \
   --resource-group ${AZ_ML_RESOURCE_GROUP} \
   --query id -o tsv)"

echo "Retrieving Storage Account Key..."
export AML_STORAGEACCT_KEY="$(az storage account keys list \
   --account-name ${AZ_ML_STORAGEACCT_NAME} \
   --query [0].value -o tsv)"


# *******************************************************************
# Azure Machine Learning (Azure ML) section
# Create workspace and integrate with Keyault, Storage Account, LogAnalytics
# https://learn.microsoft.com/en-us/cli/azure/ml/datastore?view=azure-cli-latest
# *******************************************************************
echo ""
# We need to generate the YAML file
echo "Generating Azure ML Workspace yaml file... ${AZ_ML_FILE_WORKSPACE}"
echo '$schema: https://azuremlschemas.azureedge.net/latest/workspace.schema.json' > ${AZ_ML_FILE_WORKSPACE}
echo "name: ${AZ_ML_WORKSPACE}" >> ${AZ_ML_FILE_WORKSPACE}
echo "location: ${AZ_ML_REGION_PRIMARY}" >> ${AZ_ML_FILE_WORKSPACE}
echo "display_name: Bring your own dependent resources-example" >> ${AZ_ML_FILE_WORKSPACE}
echo "description: This configuration specifies a workspace with existing dependent resources" >> ${AZ_ML_FILE_WORKSPACE}
echo "storage_account: ${AML_STORAGEACCT_ID}" >> ${AZ_ML_FILE_WORKSPACE}
echo "container_registry: ${ACR_REGISTRY_ID}" >> ${AZ_ML_FILE_WORKSPACE}
echo "key_vault: ${AZ_KEYVAULT_ID}" >> ${AZ_ML_FILE_WORKSPACE}
echo "application_insights: ${AZ_APP_INSIGHTS_REGISTRY_ID}" >> ${AZ_ML_FILE_WORKSPACE}
echo "tags:" >> ${AZ_ML_FILE_WORKSPACE}
echo "   purpose: MLSandbox" >> ${AZ_ML_FILE_WORKSPACE}

# storage_account: /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>/providers/Microsoft.Storage/storageAccounts/<STORAGE_ACCOUNT>
# container_registry: /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>/providers/Microsoft.ContainerRegistry/registries/<CONTAINER_REGISTRY>
# key_vault: /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>/providers/Microsoft.KeyVault/vaults/<KEY_VAULT>
# application_insights: /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>/providers/Microsoft.insights/components/<APP_INSIGHTS>
 
# Create an Azure ML Workspace
echo "Creating Azure ML Workspace... ${AZ_ML_WORKSPACE}"
# Create an Azure ML Workspace and integrate with ACR and Application Insights
export AZ_ML_WORKSPACE_ID="$(az ml workspace create -g ${AZ_ML_RESOURCE_GROUP} --file ${AZ_ML_FILE_WORKSPACE} --query id --output tsv)"


# *******************************************************************
# Create an Azure ML Datastore.  We must first reate the YAML files
# to input to the Azure CLI command.
# https://learn.microsoft.com/en-us/azure/machine-learning/how-to-datastore?view=azureml-api-2&tabs=cli-identity-based-access%2Ccli-adls-identity-based-access%2Ccli-azfiles-account-key%2Ccli-adlsgen1-identity-based-access
# *******************************************************************
echo ""
# We need to generate the YAML file
# my_adls_datastore.yml
echo "Generating Azure ML Datastore yaml file... ${AZ_ML_FILE_DATASTORE}"
echo '$schema: https://azuremlschemas.azureedge.net/latest/azureDataLakeGen2.schema.json' > ${AZ_ML_FILE_DATASTORE}
echo "name: ${AZ_ML_DATASTORE}" >> ${AZ_ML_FILE_DATASTORE}
echo "type: azure_data_lake_gen2" >> ${AZ_ML_FILE_DATASTORE} 
echo "description: Credential-less datastore pointing to an Azure Data Lake Storage Gen2." >> ${AZ_ML_FILE_DATASTORE}
echo "account_name: ${AZ_ML_STORAGEACCT_NAME}" >> ${AZ_ML_FILE_DATASTORE}
echo "filesystem: datalakegen2" >> ${AZ_ML_FILE_DATASTORE}
# echo "container_name: ml-container" >> ${AZ_ML_FILE_DATASTORE}
# echo "file_share_name: ml-fileshare" >> ${AZ_ML_FILE_DATASTORE}


# Create an Azure ML Datastore
echo "Creating Azure ML Datastore... ${AZ_ML_DATASTORE}"
export AZ_ML_DATASTORE_ID="$(az ml datastore create -n ${AZ_ML_DATASTORE} -g ${AZ_ML_RESOURCE_GROUP} \
   -w ${AZ_ML_WORKSPACE} --file ${AZ_ML_FILE_DATASTORE} \
   --query id --output tsv)"



# *******************************************************************
# Create Service Principal for AzDO Server or GH connections.
# Copy the JSON output and save and add to credentials.
# https://learn.microsoft.com/en-us/training/modules/introduction-development-operations-principles-for-machine-learn/4-integrate-azure-development-operations-tools
# *******************************************************************
# az ad sp create-for-rbac --name "github-aml-sp" --role contributor \
#    --scopes /subscriptions/<subscription-id>/resourceGroups/<group-name>/providers/Microsoft.MachineLearningServices/workspaces/<workspace-name> \
#    --sdk-auth

# *******************************************************************
# Output final section
# *******************************************************************
# echo ""
# echo "Listing all Azure ML Workspaces..."
# az ml workspace list -g ${AZ_ML_RESOURCE_GROUP} --output table


# *******************************************************************
# End Script. Output bash environment variables for Azure CLI
# *******************************************************************
echo ""
echo "Completed script"
echo "Creating environment script ${AZ_ENV_ML_FILENAME}"
# Output environment variables to a file
echo "# Environmnet variables script" > ${AZ_ENV_ML_FILENAME}
# These should already be defined
# echo "# export AZ_AAD_USERNAME=${AZ_AAD_USERNAME}" >> ${AZ_ENV_ML_FILENAME}
# echo "# export AZ_CURRENT_SUB=${AZ_CURRENT_SUB}" >> ${AZ_ENV_ML_FILENAME}
# echo "# export AZ_PREFIX=${AZ_PREFIX}" >> ${AZ_ENV_ML_FILENAME}

echo "# Current environment variables generated by this script:" >> ${AZ_ENV_ML_FILENAME}
echo "export AZ_ML_RESOURCE_GROUP=${AZ_ML_RESOURCE_GROUP}" >> ${AZ_ENV_ML_FILENAME}
echo "export AZ_ML_REGION_PRIMARY=${AZ_ML_REGION_PRIMARY}" >> ${AZ_ENV_ML_FILENAME}
echo "export AZ_ML_REGION_SECOND=${AZ_ML_REGION_SECOND}" >> ${AZ_ENV_ML_FILENAME}
echo "export AZ_ML_REGION=${AZ_ML_REGION}" >> ${AZ_ENV_ML_FILENAME}
echo "export AZ_ML_WORKSPACE=${AZ_ML_WORKSPACE}" >> ${AZ_ENV_ML_FILENAME}
echo "export AZ_ML_DATASTORE=${AZ_ML_DATASTORE}" >> ${AZ_ENV_ML_FILENAME}
echo "export AZ_ML_SKU_STORAGE=${AZ_ML_SKU_STORAGE}" >> ${AZ_ENV_ML_FILENAME}
echo "export AZ_ML_STORAGEACCT_NAME=${AZ_ML_STORAGEACCT_NAME}" >> ${AZ_ENV_ML_FILENAME}

# # These have secret keys and need to be set manually
echo "### Need to set these dynamically ###"  >> ${AZ_ENV_ML_FILENAME}
# echo 'export AZ_ML_WORKSPACE_ID="$(az ml show -g ${AKS_RESOURCE_GROUP} -n ${AKS_NAME} --query identity.principalId -o tsv)" ' >> ${AZ_ENV_ML_FILENAME}

# Display info to execute env
echo "Execute Bash script #. ${AZ_ENV_ML_FILENAME}"

# Calculate and store the end time
endtime=`date +%s`
echo  ""
echo $((endtime-starttime)) | awk '{printf "Execution Time: %d hours %02d minutes %02d seconds", $1/3600, ($1/60)%60, $1%60}'
echo ""
