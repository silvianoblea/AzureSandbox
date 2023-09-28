# Azure Monitor commands and documentation
# https://learn.microsoft.com/en-us/azure/azure-monitor/containers/container-insights-log-query
# https://learn.microsoft.com/en-us/azure/container-registry/monitor-service
# https://kustoqueries.com/Databases/Azure-SQL/
# https://learn.microsoft.com/en-us/azure/container-registry/resource-graph-samples?tabs=azure-cli
# https://www.thorsten-hans.com/azure-container-registry-unleashed-integrate-acr-and-azure-monitor/

# https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/resource-logs-categories

# Current list of Azure Monitor settings for the resources
az resource list --resource-type Microsoft.OperationalInsights/workspaces -o table

az monitor diagnostic-settings list --resource ${AZ_STORAGEACCT_NAME} --resource-group ${AZ_RG_NAME} --resource-type Microsoft.Storage/storageaccounts -o table
az monitor diagnostic-settings list --resource ${AZ_KEYVAULT_NAME} --resource-group ${AZ_RG_NAME} --resource-type Microsoft.KeyVault/vaults -o table
az monitor diagnostic-settings list --resource ${ACR_NAME} --resource-group ${AZ_RG_NAME} --resource-type Microsoft.ContainerRegistry/registries -o table
az monitor diagnostic-settings list --resource ${ADF_NAME} --resource-group ${AZ_RG_NAME} --resource-type Microsoft.DataFactory/factories -o table
# WebApp and Functions
az monitor diagnostic-settings list --resource ${APP_WEBAPP_NAME} --resource-group ${AZ_RG_NAME} --resource-type Microsoft.Web/sites -o table
az monitor diagnostic-settings list --resource ${ASP_PLAN_LINUX} --resource-group ${AZ_RG_NAME} --resource-type Microsoft.Web/serverfarms -o table
az monitor diagnostic-settings list --resource ${ASP_PLAN_WINDOWS} --resource-group ${AZ_RG_NAME} --resource-type Microsoft.Web/serverfarms -o table
az monitor diagnostic-settings list --resource ${AFA_WINDOWS} --resource-group ${AZ_RG_NAME} --resource-type Microsoft.Web/sites -o table
az monitor diagnostic-settings list --resource ${AFA_LINUX} --resource-group ${AZ_RG_NAME} --resource-type Microsoft.Web/sites -o table
# VNets
az monitor diagnostic-settings list --resource ${AZ_VNET_NAME} --resource-group ${AZ_RG_NAME} --resource-type Microsoft.Network/virtualNetworks -o table
az monitor diagnostic-settings list --resource ${AZ_BASTION_NAME} --resource-group ${AZ_RG_NAME} --resource-type Microsoft.Network/bastionHosts -o table
az monitor diagnostic-settings list --resource ${AZ_PUBLIC_IP_NAME} --resource-group ${AZ_RG_NAME} --resource-type Microsoft.Network/publicIPAddresses -o table
# Microsoft.Network/networkInterfaces/

# az monitor metrics list-namespaces --resource-uri [--start-time]
