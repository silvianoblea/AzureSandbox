# Modify and/or Append this to your .bashrc file

# Source our aliases
# source .bash_aliases

# Setup Azure subscription
export AZ_SUB_NAME='Azure Subscription Name'
echo "Setting Azure Subscription '${AZ_SUB_NAME}'"
az account set --subscription "${AZ_SUB_NAME}"
echo "Env variable set: \$AZ_SUB_NAME"

echo "Setting Azure AD User env...."
export AZ_AAD_USER="$(az account show --query 'user.name' --output tsv | sed 's/^live.com#//')"
echo "Env variable set: \$AZ_AAD_USER"
