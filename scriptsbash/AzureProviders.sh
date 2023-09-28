# set of standard providers
az provider register --namespace 'Microsoft.Storage'
az provider register --namespace 'Microsoft.Compute'
az provider register --namespace 'Microsoft.Network'
az provider register --namespace 'Microsoft.Monitor'
az provider register --namespace 'Microsoft.ManagedIdentity'
az provider register --namespace 'Microsoft.OperationalInsights'
az provider register --namespace 'Microsoft.OperationsManagement'
az provider register --namespace 'Microsoft.KeyVault'
az provider register --namespace 'Microsoft.ContainerService'
az provider register --namespace 'Microsoft.Kubernetes'
az provider register --namespace 'Microsoft.Security'
az provider register --namespace 'Microsoft.Web'
az provider register --namespace 'Microsoft.Sql'
az provider register --namespace 'Microsoft.PolicyInsights'
az provider register --namespace 'Microsoft.ContainerInstance'
az provider register --namespace 'Microsoft.ContainerRegistry'
az provider register --namespace 'Microsoft.DataFactory'

# additional providers
az provider register -n 'Microsoft.RedHatOpenShift' --wait
az provider register -n 'Microsoft.Authorization' --wait
# Required for AKS Multi-agetn pools
#az feature register --name MultiAgentpoolPreview --namespace Microsoft.ContainerService
az provider register -n Microsoft.ContainerService