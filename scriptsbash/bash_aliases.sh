# Linux general aliases
alias dir='ls -al'
alias ll='ls -alF'
alias src='cd ~/source/repos/'

# Azure CLI aliases
alias azs='az account set --subscription "${AZ_SUB_NAME}"'
alias azl='az account list --query "[?isDefault].{Name:name, ID:id, Default:isDefault}" --output Table'
alias azr='az account list-locations --query "[].{DisplayName:displayName, region:regionalDisplayName, Name:name}" -o table'
alias azrus="az account list-locations --query \"[?contains(regionalDisplayName, 'US')]\" -o table"
alias azadid="az ad signed-in-user show --output json | jq -r '.id'"
alias azmi="az resource list --query \"[?identity.type=='SystemAssigned'].{Name:name,  principalId:identity.principalId}\" --output table"

# Azure Compute
alias azvm-list='az vm list-sizes --location ${AZ_REGION} --query "[?numberOfCores== \`2\`].{Name:name, Cores:numberOfCores}" -o table'

# Azure Extensions
alias ael='az extension list --query "[].{Name:name, Preview:preview, Version:version}" -o table'

# ACR Aliases
alias acrl='az acr list --resource-group $AZ_RG_NAME --query "[].{acrLoginServer:loginServer}" -o table'

# AKS
alias aks-show='az aks show --name ${AKS_NAME} -g ${AKS_RESOURCE_GROUP} -o table'
alias aks-list='az aks list --query "[*].{Name:name,ResourceGroup:resourceGroup,CurrentVersion:currentKubernetesVersion}" -o table'
alias aks-npl='az aks nodepool list -g ${AKS_RESOURCE_GROUP} --cluster-name ${AKS_NAME} -o table'
alias aks-versions='az aks get-versions -l ${AZ_REGION} -o table --query "orchestrators[?!isPreview] | [-1].orchestratorVersion" -o tsv'
alias aks-version='az aks show -g ${AKS_RESOURCE_GROUP} -n ${AKS_NAME} --query  currentKubernetesVersion -o tsv'
alias aks-getupgrades='az aks get-upgrades -g ${AKS_RESOURCE_GROUP} -n ${AKS_NAME} -o table'
alias aks-getcreds='az aks get-credentials -g ${AKS_RESOURCE_GROUP} -n ${AKS_NAME}'
alias aks-stop='az aks stop -g ${AKS_RESOURCE_GROUP} -n ${AKS_NAME}'
alias aks-start='az aks start -g ${AKS_RESOURCE_GROUP} -n ${AKS_NAME}'

# Azure Policies
alias aks-pol='az aks show --query addonProfiles.azurepolicy -g ${AKS_RESOURCE_GROUP} -n ${AKS_NAME}'

# Kubectl commands
alias kub='kubectl'
alias kc='kubectl'
alias k='kubectl'
alias kubconfig='less ~/.kube/config'
alias kpods='kubectl get pods --show-labels'

alias kn='kubectl config set-context --current --namespace '
export dro='--dry-run=client -o yaml'
alias kdr='kubectl create --dry-run=client -o yaml'
# Output to new YAML file > File.yaml
alias kdp='kubectl delete pod --grace-period=0 --force'

# Kube Policies
alias kap='kubectl get pods -n kube-system | grep azure-policy'

# Azure Commercial
# Azure Commercial
alias dlz='echo ./AzureInfrastructure.sh \"\$\{AZ_AAD_USER\}\" \"\$\{AZ_SUB_NAME\}\" sbj devlab eastus2 eastus2 storageacct1 \"\<password\>\" \| tee env.azure.log'
alias klz='echo ./AzureKubernetes.sh     \"\$\{AZ_AAD_USER\}\" \"\$\{AZ_SUB_NAME\}\" sbj AKSservice rgAKS eastus2 eastus2 \"\$\{ACR_NAME\}\" \"\$\{AZ_LOG_ANALYTICS_WORKSPACE\}\" \| tee env.aks.log'

# Azure Gov
alias dlz='echo ./AzureInfrastructure.sh \"\$\{AZ_AAD_USER\}\" \"\$\{AZ_SUB_NAME\}\" sibleajr infra usdodeast usgovvirginia storageacct1 \"\<password\>\" \| tee env.azure.log'
alias klz='echo ./AzKubernetes.sh        \"\$\{AZ_AAD_USER\}\" \"\$\{AZ_SUB_NAME\}\" sibleajr \"AKSservice\" \"rgAKS\" usdodeast usgovvirginia \"\$\{ACR_NAME\}\" \"\$\{AZ_LOG_ANALYTICS_WORKSPACE\}\" \| tee env.aks.log'
