#!/bin/bash
# *******************************************************************
# Bash Azure CLI script to create an Azure Kubernetes cluster lab
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
   echo -e "   [AKS Name]        - Name of the AKS Service"
   echo -e "   [AKS Cluster RG]  - Resource Group for AKS Cluster"
   echo -e "   [Region Primary]  - Primary Region (See below)"
   echo -e "   [Region Second]   - Secondary Region (See below)"
   echo -e "   [ContainerReg]    - Azure Container Registry (ACR)"
   echo -e "   [LogAnaytics Workspace] - Log Analytics Workspace"
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
if [ $# -le 8 ]
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
for ((i=1; i<numargs; i++)); do
   echo "${args[$((i-1))]}"
done

# Export all our environment variables as global for other scripts
echo "Initializing environment variables..."
# Azure AD User
export AZ_AAD_USER=$1
# Get the Azure subscription
export AZ_SUBSCRIPTION=$2
# User alias or a unique prefix for global resources
export AZ_PREFIX=$3
# AKS Name
export AKS_NAME=$4
# DevTest Lab Kubernetes name
export AKS_RESOURCE_GROUP=$5
export AKS_NODE_RG="${AKS_RESOURCE_GROUP}_NodeCluster"
# Set default node size
NODE_COUNT=3
export AKS_NODE_COUNT=$NODE_COUNT

# Define default locations: westus, westus2, westcentralus, eastus, eastus2
export AZ_REGION_PRIMARY=$6
export AZ_REGION_SECOND=$7
# MS WorkshopPLUS Kubernetes name
export LOCATION=$AZ_REGION_PRIMARY

# Define the ACR Name
export AKS_ACR_NAME=$8
# Define our Log Analyltics workspace
export AKS_LOG_ANALYTICS_WORKSPACE=$9

# Set default VM size 
export AZ_SKU_AKS_VMSIZE="Standard_DS2_v2"

# *******************************************************************
# Set our secondary region based on the primary region (Commercial, Gov or DoD)
# *******************************************************************
echo "Determining primary and secondary regions based on Azure cloud..."
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
# *******************************************************************
echo "Setting Azure Subscription: \"${AZ_SUBSCRIPTION}\""
az account set --subscription "${AZ_SUBSCRIPTION}"
export AZ_CURRENT_SUB="$(az account show --query name)"
export AZ_AAD_USERNAME="$(az account show --query 'user.name' --output tsv)"
 
# In some instances the RGs need to be unique within a subscription
echo "Checking for required environment variables..."
if [ -z "$AZ_RG_NAME" ]; then
  echo "Environment variable \${AZ_RG_NAME} not defined..."
  exit 1;
else
  echo "Found rquired environment variables, AZ_RG_NAME, ACR_NAME, AZ_LOG_ANALYTICS_WORKSPACE"
fi

# Define our exported env script file
export ENV_FILENAME="env.aks.sh"

# *******************************************************************
# Create a default resource group just in case
# *******************************************************************
echo "Creating Resource Group... ${AKS_RESOURCE_GROUP}"
export AZ_STATUS="$(az group create --name ${AKS_RESOURCE_GROUP} --location ${AZ_REGION_PRIMARY} \
   --query properties.provisioningState)"
echo ${AZ_STATUS}


# *******************************************************************
# Azure Kubernetes Service (AKS) section
# Create an AKS cluster with ACR and Log Analytics integration
# https://learn.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-create
# AKS Defaults: --vm-set-type VirtualMachineScaleSets, 
# --load-balancer-sku standar, --network-plugin azure 
# *******************************************************************
echo ""

# Resource not avaliable in all clouds and regions
# echo "Azure Kubernetes available only in certain regions"
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

# Store latest version info.  Orchestrator version means the master nodes'
# version (control plane version), Kubernetes means the work nodes' version
echo "Quering latest version of AKS in location ${AZ_REGION}..."
export AKS_VERSION_LATEST="$(az aks get-versions -l ${AZ_REGION}  \
    --query 'orchestrators[?!isPreview] | [-1].orchestratorVersion' -o tsv)"
echo "Latest version of AKS ${AKS_VERSION_LATEST}"

echo "Checking for an existing Azure AKS... ${AKS_NAME}"
export AKS_EXISTS="$(az aks list --output tsv --query "[?name=='${AKS_NAME}']")"

# Check if already exists
if [ ! -z "$AKS_EXISTS" ]; then
  echo "AKS already exists"
   az aks list --output table
else
   export AKS_LOG_ANALYTICS_ID="$(az monitor log-analytics workspace show --resource-group ${AZ_RG_NAME} --workspace-name ${AZ_LOG_ANALYTICS_WORKSPACE} --query id --output tsv)"

   # Enable Multi agent pools
   echo "Registering MultiAgentPools on AKS...(may take upto 15 mins)"
   # az feature list -o table --query "[?contains(name, 'Microsoft.ContainerService/MultiAgentpoolPreview')].{Name:name,State:properties.state}"
   az feature register --name MultiAgentpoolPreview --namespace Microsoft.ContainerService

   # Create an Azure AKS
   echo "Creating AKS Cluster (version n-2)... ${AKS_NAME}, ${AKS_NODE_RG}"
   # Create an AKS cluster with ACR integration and Authenticate using Service Principal
   export AKS_CLUSTER_ID="$(az aks create -n ${AKS_NAME} -l ${AZ_REGION} -g ${AKS_RESOURCE_GROUP} \
     --node-resource-group ${AKS_NODE_RG} \
     --node-count ${AKS_NODE_COUNT} \
     --node-vm-size ${AZ_SKU_AKS_VMSIZE} \
     --enable-managed-identity \
     --generate-ssh-keys --query id --output tsv)"
   #   --enable-addons monitoring \
   #   --enable-msi-auth-for-monitoring true \
   #   --workspace-resource-id ${AKS_LOG_ANALYTICS_ID} \

   echo "Getting AKS credentials...adding to ~/.kube/config"
   az aks get-credentials -n $AKS_NAME -g $AKS_RESOURCE_GROUP --overwrite-existing

   echo "Checking for ACR... ${ACR_NAME}"
   export ACR_EXISTS="$(az acr list --output tsv --query "[?name=='${ACR_NAME}']")"
   # Check if ACR already exists
   if [ ! -z "$ACR_EXISTS" ]; then
      echo "Found ACR and integrating with AKS... ${ACR_NAME}" 
      # Enable ACR integration
      az aks update -n ${AKS_NAME} -g ${AKS_RESOURCE_GROUP} --attach-acr ${AKS_ACR_NAME}
   else
     echo "No ACR found so skipping ACR integration."
   fi

   echo "Enabling AKS Addon for Monitoring to LogAnalytics Workspace ${AKS_LOG_ANALYTICS_WORKSPACE}"
   export AZ_STATUS="$(az aks enable-addons -a monitoring -n ${AKS_NAME} -g ${AKS_RESOURCE_GROUP} --enable-msi-auth-for-monitoring true --workspace-resource-id ${AKS_LOG_ANALYTICS_ID} --query properties.provisioningState)"
   echo $AZ_STATUS

   # Connect AKS to Azure Log Analytics
   echo "Creating Azure Monitoring diagnostics-settings for AKS to Workspace ${AKS_LOG_ANALYTICS_WORKSPACE}"
   az monitor diagnostic-settings create --resource ${AKS_CLUSTER_ID} -n "AKS Diagnostics" --workspace ${AKS_LOG_ANALYTICS_ID} \
      --logs '[{"category": "kube-apiserver", "enabled": true, "retentionPolicy": {"days": 0, "enabled": false}},
         {"category": "kube-controller-manager", "enabled": true, "retentionPolicy": {"days": 0, "enabled": false}}]' \
      --metrics '[{"category": "AllMetrics", "enabled": true, "retentionPolicy": {"days": 0, "enabled": false}, "timeGrain": "PT1M"}]' \
      --query id --output tsv
fi

# Output some usefull info
echo "Listing AKS resources..."
az aks list --query '[*].{Name:name,ResourceGroup:resourceGroup,CurrentVersion:currentKubernetesVersion}' -o table
# Save current version
export AKS_VERSION="$(az aks show -g ${AKS_RESOURCE_GROUP} -n ${AKS_NAME} --query  currentKubernetesVersion -o tsv)"


# *******************************************************************
# Create a few namspaces.  Default should be changed to avoid potential
# security attack footprint.
# *******************************************************************
# First we need to get AKS credentails added to our kube config
# echo "Getting AKS credentials...adding to ~/.kube/config"
# az aks get-credentials -n $AKS_NAME -g $AKS_RESOURCE_GROUP --overwrite-existing

echo "Creating namespaces...dev"
kubectl create namespace dev1
kubectl create namespace dev2


# *******************************************************************
# Azure AD and Managed Identity Role Assignment.  For AKS we need
# 1. Read KV secrets: KV Secret reader
# 2. Read ACR images:  ACR Pull | ACR Contributor (build agents)
# 3. AKS Admin: AKS Cluster Admin
#"Azure Kubernetes Service Cluster User Role"
# *******************************************************************
echo "Creating Azure Kubernetes RBAC role assignments..."
export AKS_CLIENT_ID="$(az aks show -g ${AKS_RESOURCE_GROUP} -n ${AKS_NAME} --query identity.principalId -o tsv)"

# Create KeyVault Reader role
# Optional: 'Key Vault Reader' | 'Key Vault Secrets User'
export AZ_AD_ROLEASSIGN_AKS_KV='Key Vault Reader'
echo "Creating AD role assignment (${AZ_AD_ROLEASSIGN_AKS_KV}): AKS Identity to AZ_KEYVAULT_ID"
export AZ_AD_ROLEASSIGN_PRINCIPALID_AKS1="$(az role assignment create --role "${AZ_AD_ROLEASSIGN_AKS_KV}" \
   --assignee-principal-type ServicePrincipal \
   --assignee-object-id ${AKS_CLIENT_ID} --scope ${AZ_KEYVAULT_ID} --query principalId -o tsv)"

# Retrieve the ACR_ID, this should be the same as $ACR_REGISTRY_ID
export AKS_ACR_ID="$(az acr show -g ${AZ_RG_NAME} -n ${AKS_ACR_NAME} --query id -o tsv)"

# Create AKS Contributor role to ACR, or 'Contributor'
# https://learn.microsoft.com/en-us/azure/azure-monitor/containers/container-insights-enable-aks-policy

export AZ_AD_ROLEASSIGN_AKS_ACR2='Azure Kubernetes Service Contributor Role'
echo "Creating AD role assignment (${AZ_AD_ROLEASSIGN_AKS_ACR2}): AKS Identity to ACR_ID"
export AZ_AD_ROLEASSIGN_PRINCIPALID_AKS2="$(az role assignment create --role "${AZ_AD_ROLEASSIGN_AKS_ACR2}" \
    --assignee-principal-type ServicePrincipal \
    --assignee-object-id ${AKS_CLIENT_ID} --scope ${AKS_ACR_ID} --query principalId -o tsv)"

# Create AKS Log Analtics Contributor role to LogAnalytics Workspace
export AZ_AD_ROLEASSIGN_AKS_LOGS='Log Analytics Contributor'
echo "Creating AD role assignment (${AZ_AD_ROLEASSIGN_AKS_LOGS}): AKS Identity to AKS_LOG_ANALYTICS_ID"
export AZ_AD_ROLEASSIGN_PRINCIPALID_AKS2="$(az role assignment create --role "${AZ_AD_ROLEASSIGN_AKS_LOGS}" \
    --assignee-principal-type ServicePrincipal \
    --assignee-object-id ${AKS_CLIENT_ID} --scope ${AKS_LOG_ANALYTICS_ID} --query principalId -o tsv)"


# *******************************************************************
# Enable Azure Policy for AKS
# Kubernetes cluster containers should only use allowed images
# az aks addon list-available -o table
# *******************************************************************
echo "Registering provider... Azure Policy"
az provider register --namespace 'Microsoft.PolicyInsights'

# echo "Enabling Azure Policy for AKS... ${AKS_NAME}"
# az aks addon enable --addon azure-policy -g ${AKS_RESOURCE_GROUP} -n ${AKS_NAME} --no-wait

echo "Enabling Azure KeyVault Secrepts Provider for AKS... ${AKS_NAME}"
az aks enable-addons --addons 'azure-keyvault-secrets-provider' -g ${AKS_RESOURCE_GROUP} -n ${AKS_NAME} --query provisioningState

echo "Listing AKS addons for... ${AKS_NAME}"
az aks addon list -g ${AKS_RESOURCE_GROUP} -n ${AKS_NAME} -o table

# az aks show -g ${AKS_RESOURCE_GROUP} -n ${AKS_NAME} --query "identity"
# az aks show -g ${AKS_RESOURCE_GROUP} -n ${AKS_NAME} --query addonProfiles.azurepolicy
# az aks show -g ${AKS_RESOURCE_GROUP} -n ${AKS_NAME} --query addonProfiles.azurepolicy.enabled


# *******************************************************************
# Need to register provider to get MultiAgentPools change propagated
# *******************************************************************
echo "Registering provider... Microsoft.ContainerService"
az provider register -n Microsoft.ContainerService

# Create another pool
export AKS_NODEPOOL2="nodepool2"
echo "Creating AKS nodepool... ${AKS_NODEPOOL2}"
az aks nodepool add --name ${AKS_NODEPOOL2} -g ${AKS_RESOURCE_GROUP} --cluster-name ${AKS_NAME} \
   --node-vm-size ${AZ_SKU_AKS_VMSIZE} --os-sku Ubuntu \
   --enable-cluster-autoscaler --node-count ${AKS_NODE_COUNT} --min-count 1 --max-count ${AKS_NODE_COUNT} \
   --no-wait


# *******************************************************************
# End Script. Output bash environment variables for Azure CLI
# *******************************************************************
echo ""
echo "Completed script"
echo "Creating environment script ${ENV_FILENAME}"
# Output environment variables to a file
echo "# Environmnet variables script" > ${ENV_FILENAME}
echo "# Current environment variables used for script:" >> ${ENV_FILENAME}
echo "# export AZ_AAD_USERNAME=${AZ_AAD_USERNAME}" >> ${ENV_FILENAME}
echo "# export AZ_CURRENT_SUB=${AZ_CURRENT_SUB}" >> ${ENV_FILENAME}
echo "# export AZ_PREFIX=${AZ_PREFIX}" >> ${ENV_FILENAME}
echo "# export AZ_RG_NAME=${AZ_RG_NAME}" >> ${ENV_FILENAME}
echo "# export AZ_REGION_PRIMARY=${AZ_REGION_PRIMARY}" >> ${ENV_FILENAME}
echo "# export AZ_REGION_SECOND=${AZ_REGION_SECOND}" >> ${ENV_FILENAME}
echo "# export AZ_REGION=${AZ_REGION}" >> ${ENV_FILENAME}

echo "# Environmnet variables created" >> ${ENV_FILENAME}
# Azure Log Analytics - should already bee defined
#echo "export AKS_LOG_ANALYTICS_ID=${AKS_LOG_ANALYTICS_ID}" >> ${ENV_FILENAME}
echo "export AKS_LOG_ANALYTICS_WORKSPACE=${AKS_LOG_ANALYTICS_WORKSPACE}" >> ${ENV_FILENAME}
# Azure Container Registry
echo "export AKS_ACR_NAME=${AKS_ACR_NAME}" >> ${ENV_FILENAME}
#echo "export AKS_ACR_ID=${AKS_ACR_ID}" >> ${ENV_FILENAME}
# Azure Kubernetes Services
echo "export AKS_NAME=${AKS_NAME}" >> ${ENV_FILENAME}
echo "export AKS_RESOURCE_GROUP=${AKS_RESOURCE_GROUP}" >> ${ENV_FILENAME}
echo "export AKS_NODE_RG=${AKS_NODE_RG}" >> ${ENV_FILENAME}
echo "export AZ_SKU_AKS_VMSIZE=${AZ_SKU_AKS_VMSIZE}" >> ${ENV_FILENAME}
echo "export AKS_NODE_COUNT=${AKS_NODE_COUNT}" >> ${ENV_FILENAME}
#echo "export AKS_CLUSTER_ID=${AKS_CLUSTER_ID}" >> ${ENV_FILENAME}
echo "export AKS_VERSION_LATEST=${AKS_VERSION_LATEST}" >> ${ENV_FILENAME}
echo "export AKS_VERSION=${AKS_VERSION}" >> ${ENV_FILENAME}
echo "export AZ_AD_ROLEASSIGN_AKS_KV='${AZ_AD_ROLEASSIGN_AKS_KV}'" >> ${ENV_FILENAME}

# These have secret keys and need to be set manually
echo "### Need to set these dynamically ###"  >> ${ENV_FILENAME}
echo 'export AKS_CLIENT_ID="$(az aks show -g ${AKS_RESOURCE_GROUP} -n ${AKS_NAME} --query identity.principalId -o tsv)" ' >> ${ENV_FILENAME}

# Display info to execute env
echo "Execute Bash script #. ${ENV_FILENAME}"

# Calculate and store the end time
endtime=`date +%s`
echo  ""
echo $((endtime-starttime)) | awk '{printf "Execution Time: %d hours %02d minutes %02d seconds", $1/3600, ($1/60)%60, $1%60}'
echo ""
