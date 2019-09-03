function DownloadFilesFromRepo {
    Param(
        [string]$Owner,
        [string]$Repository,
        [string]$Path,
        [string]$DestinationPath
        )
    
        $baseUri = "https://api.github.com/"
        $args = "repos/$Owner/$Repository/contents/$Path"
        $wr = Invoke-WebRequest -Uri $($baseuri+$args)
        $objects = $wr.Content | ConvertFrom-Json
        $files = $objects | where {$_.type -eq "file"} | Select -exp download_url
        $directories = $objects | where {$_.type -eq "dir"}
        
        $directories | ForEach-Object { 
            DownloadFilesFromRepo -Owner $Owner -Repository $Repository -Path $_.path -DestinationPath $($DestinationPath+$_.name)
        }
    
        
        if (-not (Test-Path $DestinationPath)) {
            # Destination path does not exist, let's create it
            try {
                New-Item -Path $DestinationPath -ItemType Directory -ErrorAction Stop
            } catch {
                throw "Could not create path '$DestinationPath'!"
            }
        }
    
        foreach ($file in $files) {
            $fileDestination = Join-Path $DestinationPath (Split-Path $file -Leaf)
            try {
                Invoke-WebRequest -Uri $file -OutFile $fileDestination -ErrorAction Stop -Verbose
                "Grabbed '$($file)' to '$fileDestination'"
            } catch {
                throw "Unable to download '$($file.path)'"
            }
        }
    
    } 
 
 
 
 
 $appName="Sentia"
 $Subscription="9ce087a0-8e0e-47bd-a423-2a96d5a4a317"
 $addressPrefix="10.10.10.0/24"
 $ResourceGroupLocation="centralus"
 $templatePath = ".\Templates\"

 New-Item -Path c:\bbusoi\sentia -ItemType Directory

 $download = DownloadFilesFromRepo -Owner bbusoi -Repository Sentia -DestinationPath c:\bbusoi\sentia\

 Set-Location "c:\bbusoi\sentia"

 . .\VNet\deployVnet.ps1
 . .\StorageAcc\deployStorageAccount.ps1
 . .\KeyVault\deployKeyVault.ps1
 . .\WebApp\deployWebApp.ps1

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
$sp = New-AzAdServicePrincipal -DisplayName $($appName+"WebApp01") -PasswordCredential $credentials

#deploy KeyVault

Deploy-KeyVault $Subscription $rgName $ResourceGroupLocation $($templatePath+"keyvault.json")

#deploy WebApp

Deploy-WebApp $Subscription $rgName $ResourceGroupLocation $($templatePath+"webApp.json")

#configure WebApp

$webApp = Get-AzWebApp
    Write-Host "Creating App association to VNET"
    $propertiesObject = @{
     "vnetResourceId" = "/subscriptions/$($Subscription)/resourceGroups/$($rgName)/providers/Microsoft.Network/virtualNetworks/$($vnName)"
     }