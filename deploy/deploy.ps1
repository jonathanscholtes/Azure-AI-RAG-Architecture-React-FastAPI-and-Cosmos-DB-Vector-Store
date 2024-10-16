# Params
param (
    [string]$Subscription,
    [string]$ResourceGroupLocation = "southcentralus",
    [string]$CosmosadminUsername,
    [string]$CosmosadminPassword   
)

# Variables
$resourceGroupName = "rg-vectorsearch-demo"
$templateFile = "main.bicep"
$deploymentName = "vectorsearchdemodeployment"

# Clear account context and configure Azure CLI settings
az account clear
az config set core.enable_broker_on_windows=false
az config set core.login_experience_v2=off

# Login to Azure
az login 
az account set --subscription $Subscription

# Start the deployment
$deploymentOutput = az deployment sub create `
    --name $deploymentName `
    --location $ResourceGroupLocation `
    --template-file $templateFile `
    --parameters `
        subscription=$Subscription `
        resourceGroupName=$resourceGroupName `
        resourceGroupLocation=$ResourceGroupLocation `
        cosmosadminUsername=$CosmosadminUsername `
        cosmosadminPassword=$CosmosadminPassword `
    --query "properties.outputs"

Start-Sleep -Seconds 80

# Parse the deployment output to get app names and resource group
$deploymentOutputJson = $deploymentOutput | ConvertFrom-Json
$apiAppName = $deploymentOutputJson.apiAppName.value
$webAppName = $deploymentOutputJson.webAppName.value
$resourceGroupName = $deploymentOutputJson.resourceGroupName.value
$functionAppName = $deploymentOutputJson.functionAppName.value
$appServiceURL = $deploymentOutputJson.appServiceURL.value

Set-Location -Path .\scripts

# Deploy Function Application
Write-Output "*****************************************"
Write-Output "Deploying Function Application from scripts"
Write-Output "If timeout occurs, rerun the following command from scripts:"
Write-Output ".\deploy_functionapp.ps1 -functionAppName $functionAppName -resourceGroupName $resourceGroupName"
& .\deploy_functionapp.ps1 -functionAppName $functionAppName -resourceGroupName $resourceGroupName

# Deploy Web Application
Write-Output "*****************************************"
Write-Output "Deploying Web Application from scripts"
Write-Output "If timeout occurs, rerun the following command from scripts:"
Write-Output ".\deploy_web.ps1 -webAppName $webAppName -resourceGroupName $resourceGroupName -apiURL $appServiceURL"
& .\deploy_web.ps1 -webAppName $webAppName -resourceGroupName $resourceGroupName -apiURL $appServiceURL

# Deploy Python FastAPI
Write-Output "*****************************************"
Write-Output "Deploying Python FastAPI from scripts"
Write-Output "If timeout occurs, rerun the following command from scripts:"
Write-Output ".\deploy_api.ps1 -apiAppName $apiAppName -resourceGroupName $resourceGroupName"
& .\deploy_api.ps1 -apiAppName $apiAppName -resourceGroupName $resourceGroupName

Set-Location -Path ..

Write-Output "Deployment Complete"
