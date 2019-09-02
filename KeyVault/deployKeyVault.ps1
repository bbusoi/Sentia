<#
 .SYNOPSIS
    Deploys a template to Azure

 .DESCRIPTION
    Deploys an Azure Resource Manager template

 .EXAMPLE
    ./deploy.ps1 -subscription "Azure Subscription" -resourceGroupName myresourcegroup -resourceGroupLocation centralus

 .PARAMETER Subscription
    The subscription name or id where the template will be deployed.

 .PARAMETER ResourceGroupName
    The resource group where the template will be deployed. Can be the name of an existing or a new resource group.

 .PARAMETER ResourceGroupLocation
    Optional, a resource group location. If specified, will try to create a new resource group in this location. If not specified, assumes resource group is existing.

 .PARAMETER TemplateFilePath
    Optional, path to the template file. Defaults to template.json.

 .PARAMETER ParametersFilePath
    Optional, path to the parameters file. Defaults to parameters.json. If file is not found, will prompt for parameter values based on template.
#>

param(
 [Parameter(Mandatory=$True)]
 [string]
 $Subscription,

 [Parameter(Mandatory=$True)]
 [string]
 $ResourceGroupName,

 [string]
 $ResourceGroupLocation,

 [string]
 $TemplateFilePath = 'C:\GitHub\Sentia\Templates\keyvault.json'
)

$AzModuleVersion = "2.0.0"

<#
.SYNOPSIS
    Registers RPs
#>
Function RegisterRP {
    Param(
        [string]$ResourceProviderNamespace
    )

    Write-Host "Registering resource provider '$ResourceProviderNamespace'";
    Register-AzResourceProvider -ProviderNamespace $ResourceProviderNamespace;
}

#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"

# Verify that the Az module is installed 
if (!(Get-InstalledModule -Name Az -MinimumVersion $AzModuleVersion -ErrorAction SilentlyContinue)) {
    Write-Host "This script requires to have Az Module version $AzModuleVersion installed..
It was not found, please install from: https://docs.microsoft.com/en-us/powershell/azure/install-az-ps"
    exit
} 

# sign in
$context = Get-AzContext
If (!$context){
    Write-Host "Session not logged in. Loggin in...."
    Connect-AzAccount; 
    }
Else {
    Write-Host "Session is already logged in...."
    }

# select subscription
Write-Host "Selecting subscription '$Subscription'";
Select-AzSubscription -Subscription $Subscription;

# Register RPs
$resourceProviders = @("microsoft.keyvault");
if($resourceProviders.length) {
    Write-Host "Registering resource providers"
    foreach($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider);
    }
}

#Create or check for existing resource group
$resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if(!$resourceGroup)
{
    if(!$ResourceGroupLocation) {
        Write-Host "Resource group '$ResourceGroupName' does not exist. To create a new resource group, please enter a location.";
        $resourceGroupLocation = Read-Host "ResourceGroupLocation";
    }
    Write-Host "Creating resource group '$ResourceGroupName' in location '$ResourceGroupLocation'";
    New-AzResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation
}
else{
    Write-Host "Using existing resource group '$ResourceGroupName'";
}

# Start the deployment

$vnet = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName
$vnetName = $vnet.Name
$subnetName = $vnet.Subnets.name


$keyVaultName = $appName+"KeyVault03"
$appID=(Get-AzADServicePrincipal -DisplayName $($appName+"ID")).Id
$tenantID=$context.Tenant.Id
$appID = '64c7dccc-753b-47af-b2fb-afbfd4175cde'

$keyVaultParams = @"
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "keyVaultName": {
            "value": "$keyVaultName"
        },
        "location": {
            "value": "$ResourceGroupLocation"
        },
        "sku": {
            "value": "Standard"
        },
        "accessPolicies": {
            "value": [
                {
                    "objectId": "$appID",
                    "tenantId": "$tenantID",
                    "permissions": {
                        "keys": [
                            "Get",
                            "List",
                            "UnwrapKey",
                            "Update",
                            "Create",
                            "Import",
                            "Delete",
                            "Recover",
                            "Backup",
                            "Restore"
                        ],
                        "secrets": [
                            "Get",
                            "List",
                            "Set",
                            "Delete",
                            "Recover",
                            "Backup",
                            "Restore"
                        ],
                        "certificates": [
                            "Get",
                            "List",
                            "Update",
                            "Create",
                            "Import",
                            "Delete",
                            "Recover",
                            "Backup",
                            "Restore",
                            "ManageContacts",
                            "ManageIssuers",
                            "GetIssuers",
                            "ListIssuers",
                            "SetIssuers",
                            "DeleteIssuers"
                        ]
                    },
                    "applicationId": null
                }
            ]
        },
        "tenant": {
            "value": "$tenantID"
        },
        "enabledForDeployment": {
            "value": false
        },
        "enabledForTemplateDeployment": {
            "value": true
        },
        "enabledForDiskEncryption": {
            "value": false
        },
        "networkAcls": {
            "value": {
                "defaultAction": "Deny",
                "bypass": "AzureServices",
                "ipRules": [],
                "virtualNetworkRules": [
                    {
                        "id": "/subscriptions/$Subscription/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/virtualNetworks/$vnetName/subnets/$subnetName"
                    }
                ]
            }
        }
    }
}
"@

$ParameterFile = [System.Io.Path]::GetTempFileName()
Set-Content -Path $ParameterFile -Value $keyVaultParams

Write-Host "Starting deployment...";

    New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateFile $TemplateFilePath -TemplateParameterFile $ParameterFile;
