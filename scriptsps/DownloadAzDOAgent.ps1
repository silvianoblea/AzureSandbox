# Download and silent install Azure DevOps Server Build Agent

# Download the Azure DevOps Server Build Agent
Invoke-WebRequest -URI https://vstsagentpackage.azureedge.net/agent/2.171.1/vsts-agent-win-x64-2.171.1.zip -OutFile z:\AzDO_AgentWinX64-2.171.1.zip

# Unzip the package
Expand-Archive -Path z:\vsts-agent-win-x64-2.171.1.zip -DestinationPath c:\agent