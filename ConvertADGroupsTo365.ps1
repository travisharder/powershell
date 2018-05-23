######################################################################################################
#                                                                                                    #
# Name:        ConvertADGroupsto365.ps1                                                              #
#                                                                                                    #
# Version:     1.0                                                                                   #
#                                                                                                    #
# Description: Creates on cloud version of all distribution groups in an Active Directory OU, moves  #
#              AD distribution lists to a specified OU that is not directory synced, forces an       #
#              AD Sync, then renames the newly created in-cloud distribution lists to match the name #
#              and email address of the old distribution list.                                       #
#              The final result will be a cloud managed distribution list that matches the original  #
#              Active Directory managed group. This is useful for an Exchange to Office 365          #
#              migration where directory sync will remain, but no hybrid or on-premise management    #
#              will exist                                                                            #
#                                                                                                    #
# Requires:    Azure AD Sync Module, Office 365 Credentials                                          #
#                                                                                                    #
# Author:      Travis Harder                                                                         #
#                                                                                                    #
# Usage:       Additional information pending                                                        #
#                                                                                                    #
# Disclaimer:  This script is provided AS IS without any support. Please test in a lab environment   #
#              prior to production use. The use case for this script is NOT officially supported     #
#              by Microsoft.                                                                         #
#                                                                                                    #
######################################################################################################

<#
    .PARAMETER GroupOU
        OU holding the groups to be migrated
    
    .PARAMETER DisabledOU
        OU to move the groups to after migration
#>

Param
(
    [Parameter(Mandatory=$True)]
        [string]$GroupOU,
    [Parameter(Mandatory=$True)]
        [string]$DisabledOU
)

$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['*:ErrorAction']='Stop'

# Attempts to load ADSync module and breaks script if it fails
Try
{
    Import-Module ADSync -ErrorAction Stop
}
Catch
{
    Write-Host "Error: Unable to load Azure ADSync Module" -ForegroundColor Red
    Break
}

# Tests for the OU paths given by user and terminates script if test fails
if (![adsi]::Exists("LDAP://$GroupOU"))
{
    Write-Host "Error: Unable to find Distribution Group OU" -ForegroundColor Red
    Break
}

if (![adsi]::Exists("LDAP://$DisabledOU"))
{
    Write-Host "Error: Unable to find the Disabled Groups OU" -ForegroundColor Red
    Break
}

# Get Office 365 credentials and connect to Exchagne Online PowerShell session
Write-Host "Please Enter the Office 365 Credentials"
$365Cred = Get-Credential
Write-Host "Connecting to Office 365 Exchange Online PS Session"
$365Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $365Cred -Authentication Basic -AllowRedirection
Import-PSSession $365Session

$OnPremGroups = Get-ADGroup -Filter * -SearchBase $GroupOU
$ExportDirectory = ".\Logs\"
If(!(Test-Path -Path $ExportDirectory ))
{
    Write-Host "  Creating Directory: $ExportDirectory"
    New-Item -ItemType directory -Path $ExportDirectory | Out-Null
}
"Name" > $ExportDirectory\Groups.csv

# Create new distribution group for every group in the specified OU
foreach($OPG in $OnPremGroups)
{
    $OPD = Get-DistributionGroup -Identity $OPG.Name
    $OldName = [string]$OPD.Name
    $OldDisplayName = [string]$OPD.DisplayName
    $OldPrimarySmtpAddress = [string]$OPD.PrimarySmtpAddress
    $OldAlias = [string]$OPD.Alias
    $OldMembers = (Get-DistributionGroupMember $OPD.Name).Name

    $OPD.Name >> $ExportDirectory\Groups.csv

    Write-Host "Creating Group: Cloud-$OldDisplayName"

    New-DistributionGroup `
        -Name "Cloud-$OldName" `
        -Alias "Cloud-$OldAlias" `
        -DisplayName "Cloud-$OldDisplayName" `
        -ManagedBy $OPD.ManagedBy `
        -Members $OldMembers `
        -PrimarySmtpAddress "Cloud-$OldPrimarySmtpAddress" | Out-Null

    Sleep -Seconds 3

    Write-Host "Setting Attributes for Group: Cloud-$OldDisplayName"

    Set-DistributionGroup `
        -Identity "Cloud-$OldName" `
        -AcceptMessagesOnlyFromSendersOrMembers $OPD.AcceptMessagesOnlyFromSendersOrMembers `
        -RejectMessagesFromSendersOrMembers $OPD.RejectMessagesFromSendersOrMembers

    Set-DistributionGroup `
        -Identity "Cloud-$OldName" `
        -AcceptMessagesOnlyFrom $OPD.AcceptMessagesOnlyFrom `
        -AcceptMessagesOnlyFromDLMembers $OPD.AcceptMessagesOnlyFromDLMembers `
        -BypassModerationFromSendersOrMembers $OPD.BypassModerationFromSendersOrMembers `
        -BypassNestedModerationEnabled $OPD.BypassNestedModerationEnabled `
        -CustomAttribute1 $OPD.CustomAttribute1 `
        -CustomAttribute2 $OPD.CustomAttribute2 `
        -CustomAttribute3 $OPD.CustomAttribute3 `
        -CustomAttribute4 $OPD.CustomAttribute4 `
        -CustomAttribute5 $OPD.CustomAttribute5 `
        -CustomAttribute6 $OPD.CustomAttribute6 `
        -CustomAttribute7 $OPD.CustomAttribute7 `
        -CustomAttribute8 $OPD.CustomAttribute8 `
        -CustomAttribute9 $OPD.CustomAttribute9 `
        -CustomAttribute10 $OPD.CustomAttribute10 `
        -CustomAttribute11 $OPD.CustomAttribute11 `
        -CustomAttribute12 $OPD.CustomAttribute12 `
        -CustomAttribute13 $OPD.CustomAttribute13 `
        -CustomAttribute14 $OPD.CustomAttribute14 `
        -CustomAttribute15 $OPD.CustomAttribute15 `
        -ExtensionCustomAttribute1 $OPD.ExtensionCustomAttribute1 `
        -ExtensionCustomAttribute2 $OPD.ExtensionCustomAttribute2 `
        -ExtensionCustomAttribute3 $OPD.ExtensionCustomAttribute3 `
        -ExtensionCustomAttribute4 $OPD.ExtensionCustomAttribute4 `
        -ExtensionCustomAttribute5 $OPD.ExtensionCustomAttribute5 `
        -GrantSendOnBehalfTo $OPD.GrantSendOnBehalfTo `
        -HiddenFromAddressListsEnabled $True `
        -MailTip $OPD.MailTip `
        -MailTipTranslations $OPD.MailTipTranslations `
        -MemberDepartRestriction $OPD.MemberDepartRestriction `
        -MemberJoinRestriction $OPD.MemberJoinRestriction `
        -ModeratedBy $OPD.ModeratedBy `
        -ModerationEnabled $OPD.ModerationEnabled `
        -RejectMessagesFrom $OPD.RejectMessagesFrom `
        -RejectMessagesFromDLMembers $OPD.RejectMessagesFromDLMembers `
        -ReportToManagerEnabled $OPD.ReportToManagerEnabled `
        -ReportToOriginatorEnabled $OPD.ReportToOriginatorEnabled `
        -RequireSenderAuthenticationEnabled $OPD.RequireSenderAuthenticationEnabled `
        -SendModerationNotifications $OPD.SendModerationNotifications `
        -SendOofMessageToOriginatorEnabled $OPD.SendOofMessageToOriginatorEnabled `
        -BypassSecurityGroupManagerCheck

    # Move Group to "Disabled Groups" OU
    $GroupDN = $OPG.distinguishedName
    Move-ADObject -Identity $GroupDN -TargetPath $DisabledOU
}

Write-Host "Creation of Cloud Groups complete. Starting AD sync, window will freeze for approximately 15 minutes to allow the sync to take effect"
Write-Host "Please do not abort the script"

Start-ADSyncSyncCycle -PolicyType Delta

# Pauses script for 5 minutes to allow AD sync to take effect
Start-Sleep -s 300

$CloudGroups = Get-DistributionGroup -Filter {Name -like 'Cloud-*'}

foreach ($ICG in $CloudGroups)
{
    $TempPrimarySmtpAddress = $ICG.PrimarySmtpAddress
    $NewDGName = $ICG.Name.Substring(6)
    $NewDGDisplayName = $ICG.DisplayName.Substring(6)
    $NewDGAlias = $ICG.Alias.Substring(6)
    $NewPrimarySmtpAddress = $ICG.PrimarySmtpAddress.Substring(6)

    Set-DistributionGroup `
        -Identity $ICG.Name `
        -Name $NewDGName `
        -Alias $NewDGAlias `
        -DisplayName $NewDGDisplayName `
        -PrimarySmtpAddress $NewPrimarySmtpAddress `
        -HiddenFromAddressListsEnabled $False `
        -BypassSecurityGroupManagerCheck

    Set-DistributionGroup `
        -Identity $NewDGName `
        -EmailAddresses @{Remove=$TempPrimarySmtpAddress} `
        -BypassSecurityGroupManagerCheck
}
