#!/bin/bash

# Variables
resourceGroupName="demo-dp-203-rg"
location="EastUS"
storageAccountName="ehradlsgen2"
synapseWorkspaceName="ehrsynapsews"
synapseSqlAdminUser="ehrSqlAdmin"
synapseSqlAdminPassword="!QAZ@WSX3edc4rfv"
fileSystemName="synapsefs"
dataContainerName="data"
githubRepoUrl="https://github.com/agahgnango/hack-deng.git"
localDataPath="./sample-data"

# Get current user's object ID from Azure AD
USER_OBJECT_ID=$(az ad signed-in-user show --query objectId --output tsv)

# Get the current public IP address
CURRENT_IP=$(curl -s https://api.ipify.org)

# Get the current Azure Subscription ID
SUBSCRIPTION_ID=$(az account show --query id --output tsv)

# Login to Azure
az login

# Create Resource Group
az group create --name $resourceGroupName --location $location

# Create Storage Account with Hierarchical Namespace enabled
az storage account create --name $storageAccountName --resource-group $resourceGroupName --location $location --sku Standard_LRS --kind StorageV2 --hns true

# Get Storage Account Key
storageAccountKey=$(az storage account keys list --resource-group $resourceGroupName --account-name $storageAccountName --query '[0].value' --output tsv)

# Create Synapse file system container
az storage container create --name $fileSystemName --account-name $storageAccountName --account-key $storageAccountKey

# Create Data container for uploads
az storage container create --name $dataContainerName --account-name $storageAccountName --account-key $storageAccountKey

# Clone the GitHub repository and navigate to sample-data
git clone $githubRepoUrl
cd hack-deng/sample-data

# Upload data to the new "data" container
az storage blob upload-batch --destination $dataContainerName --source . --account-name $storageAccountName --account-key $storageAccountKey

# Navigate back to the original directory
cd ..

# Synapse Analytics Workspace requires a linked ADLS Gen2 storage
az synapse workspace create --name $synapseWorkspaceName \
    --resource-group $resourceGroupName \
    --storage-account $storageAccountName \
    --file-system $fileSystemName \
    --sql-admin-login-user $synapseSqlAdminUser \
    --sql-admin-login-password $synapseSqlAdminPassword \
    --location $location

# Enable public network access for Synapse Workspace
az synapse workspace update --name $synapseWorkspaceName --resource-group $resourceGroupName --public-network-access Enabled

# Assign necessary roles for the current user
az synapse role assignment create --workspace-name $synapseWorkspaceName --role "Synapse Administrator" --assignee $USER_OBJECT_ID
az synapse role assignment create --workspace-name $synapseWorkspaceName --role "Synapse SQL Administrator" --assignee $USER_OBJECT_ID

# Assign Storage Blob Data Contributor role to the user for the storage account
az role assignment create --assignee $USER_OBJECT_ID --role "Storage Blob Data Contributor" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName"

# Add the current IP address to the firewall rules for Storage Account
az storage account network-rule add --resource-group $resourceGroupName --account-name $storageAccountName --ip-address $CURRENT_IP

# Add the current IP address to the firewall rules for Synapse Workspace
az synapse workspace firewall-rule create --workspace-name $synapseWorkspaceName --name "AllowMyIP" --start-ip-address $CURRENT_IP --end-ip-address $CURRENT_IP

# Output
echo "Data Lake Storage Gen2 and Synapse Analytics resources have been provisioned successfully."
echo "Firewall rules and permissions have been updated, and Synapse Studio should now be accessible."
