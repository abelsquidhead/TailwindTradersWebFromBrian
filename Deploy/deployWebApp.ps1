[CmdletBinding()]
param(
    [Parameter(Mandatory = $True)]
    [string]
    $servicePrincipal,

    [Parameter(Mandatory = $True)]
    [string]
    $servicePrincipalSecret,

    [Parameter(Mandatory = $True)]
    [string]
    $servicePrincipalTenantId,

    [Parameter(Mandatory = $True)]
    [string]
    $azureSubscriptionName,

    [Parameter(Mandatory = $True)]
    [string]
    $resourceGroupName,

    [Parameter(Mandatory = $True)]
    [string]
    $location,
    
    [Parameter(Mandatory = $True)]
    [string]
    $appPlanName,

    [Parameter(Mandatory = $True)]
    [string]
    $stagingAppName,

    [Parameter(Mandatory = $True)]
    [string]
    $productionAppName,

    [Parameter(Mandatory = $True)]
    [string]
    $webAppSku,

    [Parameter(Mandatory = $True)]
    [string]
    $storageAccountName,

    [Parameter(Mandatory = $True)]
    [string]
    $storageAccountSku

)


#region Login
# This logs in a service principal
#
Write-Output "Logging in to Azure with a service principal..."
az login `
    --service-principal `
    --username $servicePrincipal `
    --password $servicePrincipalSecret `
    --tenant $servicePrincipalTenantId
Write-Output "Done"
Write-Output ""

# This sets the subscription to the subscription I need all my apps to
# run in
#
Write-Output "Setting default azure subscription..."
az account set `
    --subscription "$azureSubscriptionName"
Write-Output "Done"
Write-Output ""
#endregion


#region Create resource group
# Create a resource group
#
Write-Output "Creating resource group..."
az group create `
    --name $resourceGroupName `
    --location $location
Write-Output "Done creating resource group"
Write-Output ""
#endregion


#region create app service
# create app service plan
#
Write-Output "creating app service plan..."
try {
    az appservice plan create `
    --name $("$appPlanName") `
    --resource-group $resourceGroupName `
    --sku $webAppSku
}
catch {
    Write-Output "app service already exists."
}
Write-Output "done creating app service plan"
Write-Output ""

Write-Output "creating staging web app..."
try {
    az webapp create `
    --name $stagingAppName `
    --plan $("$appPlanName") `
    --resource-group $resourceGroupName

}

catch {
    Write-Output "staging web app already exists"
}

Write-Output "creating production web app..."
try {
    az webapp create `
    --name $productionAppName `
    --plan $("$appPlanName") `
    --resource-group $resourceGroupName

}

catch {
    Write-Output "production web app already exists"
}

Write-Output "done creating web apps"
Write-Output ""
#endregion


#region Monitor
# this creates an instance of appliction insight for web app
#
Write-Output "creating application insight for the web app..."
$appInsightCreateResponse=$(az resource create `
    --resource-group $resourceGroupName `
    --resource-type "Microsoft.Insights/components" `
    --name $($productionAppName + "AppInsight") `
    --location $location `
    --properties '{\"Application_Type\":\"web\"}') | ConvertFrom-Json
Write-Output "done creating app insight for web app: $appInsightCreateResponse"
Write-Output ""

# this gets the instrumentation key from the create response
#
Write-Output "getting instrumentation key from the create response..."
$instrumentationKey = $appInsightCreateResponse.properties.InstrumentationKey
Write-Output "done getting instrumentation key"
Write-Output ""

# this sets application insight to web app
#
Write-Output "setting and configuring application insight for web app..."
az webapp config appsettings set `
    --resource-group $resourceGroupName `
    --name $productionAppName `
    --slot-settings APPINSIGHTS_INSTRUMENTATIONKEY=$instrumentationKey `
                    ApplicationInsightsAgent_EXTENSION_VERSION=~2 `
                    XDT_MicrosoftApplicationInsights_Mode=recommended `
                    APPINSIGHTS_PROFILERFEATURE_VERSION=1.0.0 `
                    DiagnosticServices_EXTENSION_VERSION=~3 `
                    APPINSIGHTS_SNAPSHOTFEATURE_VERSION=1.0.0 `
                    SnapshotDebugger_EXTENSION_VERSION=~1 `
                    InstrumentationEngine_EXTENSION_VERSION=~1 `
                    XDT_MicrosoftApplicationInsights_BaseExtension=~1
Write-Output "done setting and configuring application insight for production web app"
Write-Output ""
#endregion