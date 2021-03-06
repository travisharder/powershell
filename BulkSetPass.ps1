﻿<#
    Get all users in OU and reset password based on a seed and four random numbers after. Good for creating the initial passwords in a new domain, before having the end user create their own password. Not the most efficient, but does the trick
    Author: Travis Harder
    Last Updated: May 8, 2017
#>

# Define OU
$users = Get-ADUser -Filter * -Searchbase "OU=Users,OU=ORG,DC=ad,DC=CONTOSO,DC=COM"
# Password suffix character set
$Nums = [Char[]]"1234567890"

# Get all users in OU and set password on each
foreach ($user in $users)
{
# Gets the four characters that make up the suffic of the password
$Suffix = ($Nums | Get-Random -Count 4) -join ""
# Define complete password (seed plus four char suffix) and the convert to a secure string
$UnSecPass = "Root" + $Suffix
$SecPass = ConvertTo-SecureString -String $UnSecPass -AsPlainText -Force
#Set user password and write to fuke confirmation
Set-ADAccountPassword -Reset -Identity $user.SAMAccountName  -NewPassword $SecPass
$UserConf = "User: " + $user.SAMAccountName
Add-Content pass.txt $UserConf
$PassConf = "Password: " + $UnSecPass
Add-Content pass.txt $PassConf
Set-ADUser -Identity $user.SAMAccountName -Enabled $true
Add-Content pass.txt "User Enabled"
Add-Content pass.txt "------------"
}
