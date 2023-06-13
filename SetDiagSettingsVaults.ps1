#Login to Azure
#Connect-AzAccount

#List subscription accessible
Get-Azsubscription | ft
#Set Subscription context
$sub=$(Write-host "Subscription Name? (You can find it in the list above): " -ForegroundColor Green -NoNewline;Read-host)   
[void](Set-Azcontext -Subscription $sub)
Write-host "Configure Subscription Context to $sub"

#WARNING
Write-host "[IMPORTANT] Make sure to review Azure's customer convention name before creating resources" -ForegroundColor RED
Start-sleep -seconds 3

#Variables
#Region
$location=$(Write-host "Type the Region of the resources required." -ForegroundColor Cyan -NoNewline) + $(Write-host " EX: northeurope or westus: " -ForegroundColor Green -NoNewline;Read-host)
#Resources Group Name
$rgname=$(Write-host "Type the Resource Group Name." -ForegroundColor Cyan -NoNewline) + $(Write-host " EX: IAA-MGMT-BackupReport-01: " -ForegroundColor Green -NoNewline;Read-host)
#Log Analytic Workspace Name
$workspaceName=$(Write-host "Type Log Analytic Workspace name." -ForegroundColor Cyan -NoNewline) + $(Write-host " EX: AZIAANE-BackupReportWorkspace: " -ForegroundColor Green -NoNewline;Read-host)

#Create RG>
[void] (New-AzResourceGroup -Name $rgname -Location $location)
Write-host "Created Resources Group $rgname"
#Create Workspace
[void] (New-AzOperationalInsightsWorkspace -Location $location -Name $workspaceName -Sku pergb2018 -ResourceGroupName $rgname)
Write-host "Created Log Analytic Workspace $workspacename"
    
#BACKUP VAULT DIAG SETTINGS
$SubHomeTenantId=Get-AzSubscription -SubscriptionName $sub | select hometenantid
$Subscriptions=Get-AzSubscription | ? {$_.HomeTenantId -match $SubHomeTenantId.HomeTenantId }

Foreach($subscription in $Subscriptions)
{
    #Resources variables
    $Vaults = Get-AzRecoveryServicesVault
    $workspace=(Get-AzOperationalInsightsWorkspace | ? {$_.Name -match $workspacename}).ResourceId

    #Settings to enable
    $AzureBackupReport=New-AzDiagnosticDetailSetting -Category AzureBackupReport -Log -Enabled
    $CoreAzureBackup=New-AzDiagnosticDetailSetting -Category CoreAzureBackup -Log -Enabled
    $AddonAzureBackupJobs=New-AzDiagnosticDetailSetting -Category AddonAzureBackupJobs -Log -Enabled
    $AddonAzureBackupAlerts=New-AzDiagnosticDetailSetting -Category AddonAzureBackupAlerts -Log -Enabled
    $AddonAzureBackupPolicy=New-AzDiagnosticDetailSetting -Category AddonAzureBackupPolicy -Log -Enabled
    $AddonAzureBackupStorage=New-AzDiagnosticDetailSetting -Category AddonAzureBackupStorage -Log -Enabled
    $AddonAzureBackupProtectedInstance=New-AzDiagnosticDetailSetting -Category AddonAzureBackupProtectedInstance -Log -Enabled

    $WarningPreference='silentlycontinue'

    #Enable diag settings on all vault sending to the Log Analytic Workspace & with the settings above
    foreach($vault in $vaults)
    {
    $input=new-AzDiagnosticSetting -Name BackupReport -ResourceId $vault.ID -WorkspaceId $workspace -Setting $AzureBackupReport,$CoreAzureBackup,$AddonAzureBackupJobs,$AddonAzureBackupAlerts,$AddonAzureBackupPolicy,$AddonAzureBackupStorage,$AddonAzureBackupProtectedInstance -DedicatedLogAnalyticsDestinationType
    [void] (Set-AzDiagnosticSetting -InputObject $input)
    Write-Host "Configure the Diagnostic Settings of $vault.name to send Backup Data to $workspacename"
    }

}

#Resources created 
Get-AzResourceGroup $rgname | ft 
Get-azresource -ResourceGroupName $rgname | ft

write-host "The resources created are listed above. The First Backup report will be available within 24 hrs - You can configure Email report from the Recovery Service Vault." -ForegroundColor Yellow
Write-host "NOTE: DO NOT FORGET TO APPROVE PERMISSIONS ON THE LOGIC APPS THE MAIL REPORT WILL CREATE" -ForegroundColor Yellow
