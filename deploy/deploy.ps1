
# Params
param (
    [string]$Subscription,
    [string]$CosmosadminUsername,
    [string]$CosmosadminPassword   
)

# Variables
$resourceGroupName = "rg-vectorsearch-demo"
$resourceGroupLocation = "southcentralus"
$templateFile = "main.bicep"


az account clear
az config set core.enable_broker_on_windows=false
az config set core.login_experience_v2=off

# Login to Azure
az login 

az account set --subscription $Subscription


# Start the deployment
$deploymentName = "vectorsearchdemodeployment"


# Deploy the Bicep file
$deploymentOutput = az deployment sub create `
  --name $deploymentName `
  --location $resourceGroupLocation `
  --template-file $templateFile `
  --parameters subscription=$Subscription resourceGroupName=$resourceGroupName resourceGroupLocation=$resourceGroupLocation cosmosadminUsername=$CosmosadminUsername cosmosadminPassword=$CosmosadminPassword `
  --query "properties.outputs" `
  #--no-wait



Start-Sleep -Seconds 80

# Parse the deployment output to get the web app name and resource group
$deploymentOutputJson = $deploymentOutput | ConvertFrom-Json
$apiAppName = $deploymentOutputJson.apiAppName.value
$webAppName = $deploymentOutputJson.webAppName.value
$resourceGroupName = $deploymentOutputJson.resourceGroupName.value
$functionAppName = $deploymentOutputJson.functionAppName.value
$appServiceURL = $deploymentOutputJson.appServiceURL.value


Set-Location -Path .\scripts

Write-Output "*****************************************"
Write-Output "Deploy Function Application from scripts"
Write-Output "Rerun on Timeout"
Write-Output ".\deploy_functionapp.ps1 -functionAppName $functionAppName -resourceGroupName $resourceGroupName"
& .\deploy_functionapp.ps1 -functionAppName $functionAppName -resourceGroupName $resourceGroupName

Write-Output "*****************************************"
Write-Output "Deploy Web Application from scripts"
Write-Output "Rerun on Timeout"
Write-Output ".\deploy_web.ps1 -webAppName $webAppName -resourceGroupName $resourceGroupName -apiURL $appServiceURL"
& .\deploy_web.ps1 -webAppName $webAppName -resourceGroupName $resourceGroupName -apiURL $appServiceURL

Write-Output "*****************************************"
Write-Output "Deploy Python FastAPI from scripts"
Write-Output "Rerun on Timeout"
Write-Output ".\deploy_api.ps1 -apiAppName $apiAppName -resourceGroupName $resourceGroupName"
& .\deploy_api.ps1 -apiAppName $apiAppName -resourceGroupName $resourceGroupName


Set-Location -Path ..

Write-Output "Deployment Complete"