#!/bin/bash

# === CONFIGURE VARIABLES ===
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

# Variables for Access Fix
USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)  # Get current user ID
CURRENT_IP=$(curl -s ifconfig.me)  # Get public IP
SUBSCRIPTION_ID=$(az account show --query id -o tsv)  # Auto-fetch subscription ID

# Login to Azure
az login

# === CREATE RESOURCE GROUP ===
echo "🔹 Creating resource group..."
az group create --name $resourceGroupName --location $location

# === CREATE STORAGE ACCOUNT ===
echo "🔹 Creating Storage Account with Hierarchical Namespace enabled..."
az storage account create --name $storageAccountName --resource-group $resourceGroupName --location $location --sku Standard_LRS --kind StorageV2 --hns true

# Get Storage Account Key
storageAccountKey=$(az storage account keys list --resource-group $resourceGroupName --account-name $storageAccountName --query '[0].value' --output tsv)

# === CREATE STORAGE CONTAINERS ===
echo "🔹 Creating Synapse file system container..."
az storage container create --name $fileSystemName --account-name $storageAccountName --account-key $storageAccountKey

echo "🔹 Creating Data container for uploads..."
az storage container create --name $dataContainerName --account-name $storageAccountName --account-key $storageAccountKey

# === CLONE GITHUB REPO AND UPLOAD DATA ===
if [ ! -d "hack-deng" ]; then
    echo "🔹 Cloning GitHub repository..."
    git clone $githubRepoUrl
fi

cd hack-deng/sample-data

# Upload data to the new "data" container
echo "🔹 Uploading data to the data container..."
az storage blob upload-batch --destination $dataContainerName --source . --account-name $storageAccountName --account-key $storageAccountKey

cd ..  # Return to original directory

# === CREATE SYNAPSE ANALYTICS WORKSPACE ===
echo "🔹 Creating Synapse Analytics workspace..."
az synapse workspace create --name $synapseWorkspaceName \
    --resource-group $resourceGroupName \
    --storage-account $storageAccountName \
    --file-system $fileSystemName \
    --sql-admin-login-user $synapseSqlAdminUser \
    --sql-admin-login-password $synapseSqlAdminPassword \
    --location $location

# === ASSIGN ROLES FOR ACCESS ===
echo "🔹 Assigning necessary roles for access..."

# Assign Storage Blob Data Contributor Role to User
az role assignment create --assignee $USER_OBJECT_ID --role "Storage Blob Data Contributor" --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName"

# Assign Synapse Administrator Role to User
az synapse role assignment create --workspace-name $synapseWorkspaceName --role "Synapse Administrator" --assignee $USER_OBJECT_ID
az synapse role assignment create --workspace-name $synapseWorkspaceName --role "Synapse SQL Administrator" --assignee $USER_OBJECT_ID

# === ENABLE PUBLIC ACCESS ===
echo "🔹 Enabling public network access for Storage..."
az storage account update --name $storageAccountName --resource-group $resourceGroupName --allow-blob-public-access true --public-network-access Enabled

echo "🔹 Enabling public network access for Synapse..."
az synapse workspace update --name $synapseWorkspaceName --resource-group $resourceGroupName --public-network-access Enabled

# === ADD FIREWALL RULES TO ALLOW CURRENT IP ===
echo "🔹 Allowing current IP ($CURRENT_IP) in Storage firewall..."
az storage account network-rule add --resource-group $resourceGroupName --account-name $storageAccountName --ip-address $CURRENT_IP

echo "🔹 Allowing current IP ($CURRENT_IP) in Synapse firewall..."
az synapse workspace firewall-rule create --workspace-name $synapseWorkspaceName --name "AllowMyIP" --start-ip-address $CURRENT_IP --end-ip-address $CURRENT_IP

# === OUTPUT SUCCESS MESSAGE ===
echo "✅ Data Lake Storage Gen2 and Synapse Analytics resources have been provisioned successfully."
echo "✅ Access settings have been updated to fix 403 errors. Try accessing Synapse Studio and Storage now."
