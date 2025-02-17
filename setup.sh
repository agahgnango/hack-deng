#!/bin/bash

# Variables
resourceGroupName="demo-dp-203-rg"
location="EastUS"
storageAccountName="lhehradlsgen2"
synapseWorkspaceName="lhehrsynapsews"
synapseSqlAdminUser="SqlDbAdmin"
synapseSqlAdminPassword="!QAZ@WSX3edc4rfv"
fileSystemName="synapse"
dataContainerName="data"
githubRepoUrl="https://github.com/agahgnango/hack-deng.git"
localDataPath="./sample-data"

# Get current user's object ID from Azure AD
echo "Getting current user's Azure AD Object ID..."
USER_OBJECT_ID=$(az ad signed-in-user show --query objectId --output tsv)
echo "User Object ID: $USER_OBJECT_ID"

# Get the current public IP address
echo "Getting current public IP address..."
CURRENT_IP=$(curl -s https://api.ipify.org)
echo "Current IP Address: $CURRENT_IP"

# Get the current Azure Subscription ID
echo "Getting Azure Subscription ID..."
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
echo "Subscription ID: $SUBSCRIPTION_ID"

# Login to Azure
echo "Logging into Azure..."
az login

# Create Resource Group
echo "Creating Resource Group '$resourceGroupName' in location '$location'..."
az group create --name $resourceGroupName --location $location

# Create Storage Account with Hierarchical Namespace enabled
echo "Creating Storage Account '$storageAccountName' with Hierarchical Namespace enabled..."
az storage account create --name $storageAccountName --resource-group $resourceGroupName --location $location --sku Standard_LRS --kind StorageV2 --hns true

# Get Storage Account Key
echo "Retrieving Storage Account Key for '$storageAccountName'..."
storageAccountKey=$(az storage account keys list --resource-group $resourceGroupName --account-name $storageAccountName --query '[0].value' --output tsv)

# Create Synapse file system container
echo "Creating Synapse file system container '$fileSystemName'..."
az storage container create --name $fileSystemName --account-name $storageAccountName --account-key $storageAccountKey

# Create Data container for uploads
echo "Creating Data container '$dataContainerName'..."
az storage container create --name $dataContainerName --account-name $storageAccountName --account-key $storageAccountKey

# Clone the GitHub repository and navigate to sample-data
echo "Cloning the GitHub repository and uploading data..."
git clone $githubRepoUrl
cd hack-deng/sample-data

# Upload data to the new "data" container
echo "Uploading data to the 'data' container..."
az storage blob upload-batch --destination $dataContainerName --source . --account-name $storageAccountName --account-key $storageAccountKey

# Navigate back to the original directory
cd ..

# Synapse Analytics Workspace requires a linked ADLS Gen2 storage
echo "Creating Synapse Analytics Workspace '$synapseWorkspaceName'..."
az synapse workspace create --name $synapseWorkspaceName \
    --resource-group $resourceGroupName \
    --storage-account $storageAccountName \
    --file-system $fileSystemName \
    --sql-admin-login-user $synapseSqlAdminUser \
    --sql-admin-login-password $synapseSqlAdminPassword \
    --location $location

# Assign necessary roles for the current user
echo "Assigning Synapse Administrator role to user..."
az synapse role assignment create --workspace-name $synapseWorkspaceName --role "Synapse Administrator" --assignee $USER_OBJECT_ID

echo "Assigning Synapse SQL Administrator role to user..."
az synapse role assignment create --workspace-name $synapseWorkspaceName --role "Synapse SQL Administrator" --assignee $USER_OBJECT_ID

# Assign Storage Blob Data Contributor role to the user for the storage account
echo "Assigning Storage Blob Data Contributor role to user for Storage Account '$storageAccountName'..."
az role assignment create --assignee $USER_OBJECT_ID --role "Storage Blob Data Contributor" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName"

# Add the current IP address to the firewall rules for Storage Account
echo "Adding current IP '$CURRENT_IP' to firewall rules for Storage Account '$storageAccountName'..."
az storage account network-rule add --resource-group $resourceGroupName --account-name $storageAccountName --ip-address $CURRENT_IP

# Add the current IP address to the firewall rules for Synapse Workspace
echo "Adding current IP '$CURRENT_IP' to firewall rules for Synapse Workspace '$synapseWorkspaceName'..."
az synapse workspace firewall-rule create --name "AllowMyIP" --workspace-name $synapseWorkspaceName --resource-group $resourceGroupName --start-ip-address $CURRENT_IP --end-ip-address $CURRENT_IP

# Output
echo "Data Lake Storage Gen2 and Synapse Analytics resources have been provisioned successfully."
echo "Firewall rules and permissions have been updated, and Synapse Studio should now be accessible."
