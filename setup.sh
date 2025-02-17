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

# Output
echo "Data Lake Storage Gen2 and Synapse Analytics resources have been provisioned successfully."
