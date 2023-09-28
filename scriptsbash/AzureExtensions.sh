#!/bin/sh

# Allow installing extensions without prompting
# az config set extension.use_dynamic_install=yes_without_prompt

# az extension list-available -o table
# az extension list -o table

az extension add --name application-insights --upgrade
az extension add --name azure-devops --upgrade
az extension add --name bastion --upgrade
az extension add --name containerapp --upgrade
az extension add --name datafactory --upgrade
az extension add --name portal --upgrade
az extension add --name ssh --upgrade
az extension add --name webapp --upgrade
az extension add --name aks-preview --upgrade
az extension add --name databricks --upgrade
az extension add --name ml -y

# echo "Sourcing .bash_aliases"
# source ~/.bash_aliases

# Azure VM Extentions
# az vm extension set \
#    --publisher Microsoft.Azure.ActiveDirectory \
#    --name AADLoginForWindows \
#    --resource-group <RG_NAME\
#    --vm-nmae <VMNAME>
# admin:  net localgroup "remote desktop users" /add "AzureAD\user@domain.com"
# RDP file changes:
# enablecredsspsupport:i:0
# authentication level:i:2

# echo "Creating directories"
# mkdir adf; mkdir datasets; mkdir jsonfiles; mkdir scriptssql

# # move our files
# mv *.json jsonfiles; mv *.sql scriptssql
