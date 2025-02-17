# Variables
resourceGroupName="demo-dp-203-rg"
location="EastUS"
storageAccountName="ehradlsgen2"
containerName="data"
synapseWorkspaceName="ehrsynapsews"
synapseSqlAdminUser="ehrSqlAdmin"
synapseSqlAdminPassword="!QAZ@WSX3edc4rfv"
fileSystemName="synapsefs"

# Login to Azure
az login

# Create Resource Group
az group create --name $resourceGroupName --location $location

# Create Storage Account with Hierarchical Namespace enabled
az storage account create --name $storageAccountName --resource-group $resourceGroupName --location $location --sku Standard_LRS --kind StorageV2 --hns true

# Get Storage Account Key
storageAccountKey=$(az storage account keys list --resource-group $resourceGroupName --account-name $storageAccountName --query '[0].value' --output tsv)

# Create Container (also used as File System for Synapse)
az storage container create --name $fileSystemName --account-name $storageAccountName --account-key $storageAccountKey

# Synapse Analytics Workspace requires a linked ADLS Gen2 storage
az synapse workspace create --name $synapseWorkspaceName \
    --resource-group $resourceGroupName \
    --storage-account $storageAccountName \
    --file-system $fileSystemName \
    --sql-admin-login-user $synapseSqlAdminUser \
    --sql-admin-login-password $synapseSqlAdminPassword \
    --location $location

# Output
echo "Data Lake Storage Gen2 and Synapse Analytics resources have been provisioned successfully."
