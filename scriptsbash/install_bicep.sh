# Manual Install Bicep CLI
az bicep install

# Windows Install Bicep
choco install bicep
winget install -e --id Microsoft.Bicep
bicep --help

# Linux Install Bicep
curl -Lo bicep https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64
chmod +x ./bicep
sudo mv ./bicep /usr/local/bin/bicep
bicep --help