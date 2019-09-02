 $appName="Sentia"
 $Subscription="9ce087a0-8e0e-47bd-a423-2a96d5a4a317"
 $addressPrefix="10.10.10.0/24"
 $ResourceGroupLocation="centralus"
 $templatePath = "D:\Scripting\Sentia\Templates\"

 . .\VNet\deployVnet.ps1
 . .\StorageAcc\deployStorageAccount.ps1

 # sign in
$context = Get-AzContext
If (!$context){
    Write-Host "Session not logged in. Loggin in...."
    Connect-AzAccount; 
    }
Else {
    Write-Host "Session is already logged in...."
    }
 
 #deploying vnet
 
 Deploy-Vnet $appName $Subscription $addressPrefix $ResourceGroupLocation $($templatePath+"vNet.json")


 #add service endpoints to vnet

 $vnetToModify = Get-AzVirtualNetwork

 $rgName = $vnetToModify.ResourceGroupName
 $vnName = $vnetToModify.Name
 $subnetName = $vnetToModify.Subnets.Name
 $subnetPrefix = $vnetToModify.Subnets.AddressPrefix

 Get-AzVirtualNetwork `
    -ResourceGroupName $rgName `
    -Name $vnName | Set-AzVirtualNetworkSubnetConfig `
    -Name $subnetName `
    -AddressPrefix $subnetPrefix `
    -ServiceEndpoint "Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.Web" | Set-AzVirtualNetwork

#deploing data lake
    
Deploy-DataLake $appName $Subscription $rgName $ResourceGroupLocation $($templatePath+"storageAcc.json")

#create service principal 

$password = Read-Host -Prompt "Imput ServicePrincipal Password" -AsSecureString
$credentials = New-Object Microsoft.Azure.Commands.ActiveDirectory.PSADPasswordCredential -Property @{ StartDate=Get-Date; EndDate=Get-Date -Year 2024; Password=$password}
$sp = New-AzAdServicePrincipal -DisplayName $($appName+"WebApp") -PasswordCredential $credentials