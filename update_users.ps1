$Suffix = (Get-ADDomain).Forest

Get-ADUser -Filter '-Not [string]::IsNullOrEmpty($_.UserPrincipalName)' | ForEach-Object {
    $NewUPN = "$($_.GivenName).$($_.Surname)".ToLower() -replace "[ -]", ""

    Set-ADUser -Identity $_.UserPrincipalName `
        -UserPrincipalName "$NewUPN@$Suffix" `
        -ChangePasswordAtLogon $False `
        -Name "$($_.GivenName) $($_.Surname)"
}

