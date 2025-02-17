# Variables
resourceGroupName="dp-203-rg"
location="EastUS"
storageAccountName="ehradlsgen2"
containerName="Data"
synapseWorkspaceName="ehrsynapsews"
synapseSqlAdminUser="ehrSqlAdmin"
synapseSqlAdminPassword="!QAZ@WSX3edc4rfv"
githubRepoUrl="https://github.com/agahgnango/hack-deng/tree/main/sample-data"

# Login to Azure
az login

# Create Resource Group
az group create --name $resourceGroupName --location $location

# Create Storage Account with Hierarchical Namespace enabled
az storage account create --name $storageAccountName --resource-group $resourceGroupName --location $location --sku Standard_LRS --kind StorageV2 --hns true

# Get Storage Account Key
storageAccountKey=$(az storage account keys list --resource-group $resourceGroupName --account-name $storageAccountName --query '.value' --output tsv)

# Create Container
az storage container create --name $containerName --account-name $storageAccountName --account-key $storageAccountKey

# Upload Data from GitHub repository to the container
az storage blob upload-batch --destination $containerName --source $githubRepoUrl --account-name $storageAccountName --account-key $storageAccountKey

# Create Synapse Analytics Workspace
az synapse workspace create --name $synapseWorkspaceName --resource-group $resourceGroupName --location $location --sql-admin-login-user $synapseSqlAdminUser --sql-admin-login-password $synapseSqlAdminPassword

# Output
echo "Data Lake Storage Gen2 and Synapse Analytics resources have been provisioned successfully."
