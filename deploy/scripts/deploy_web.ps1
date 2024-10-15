param (
    [string]$webAppName,
    [string]$resourceGroupName,
    [string]$apiURL
)

$nodeAppPath = "..\..\web"
$nodeTempDir = "artifacts\web\temp"
$nodeBuildDir = "${nodeAppPath}\build"
$zipFilePath = "artifacts\web\app.zip"


Set-Content -Path "$nodeAppPath\.env" -Value "REACT_APP_API_HOST=$apiURL"

Start-Process "npm" -ArgumentList "install" -WorkingDirectory $nodeAppPath -NoNewWindow -Wait

Start-Process "npm" -ArgumentList "run build" -WorkingDirectory $nodeAppPath -NoNewWindow -Wait


# Construct the argument list
$args = "$nodeBuildDir $zipFilePath $nodeTempDir  --exclude_files .env .gitignore *.md"

# Execute the Python script
Start-Process "python" -ArgumentList "directory_zipper.py $args" -NoNewWindow -Wait

# Deploy the zip file to the Azure Web App
az webapp deploy --resource-group $resourceGroupName --name $webAppName --src-path $zipFilePath --type 'zip' --timeout 60000

# Clean up zip file
#Remove-Item $zipFilePath