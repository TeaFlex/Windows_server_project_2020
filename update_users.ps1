$Suffix = (Get-ADDomain).Forest

Get-ADUser -Filter * | ForEach-Object {
    If (-Not [string]::IsNullOrEmpty($_.UserPrincipalName)) { 
        $NewUPN = "$($_.GivenName).$($_.Surname)".ToLower() -replace "[ -]", ""

        Set-ADUser -Identity $_.UserPrincipalName `
            -UserPrincipalName "$NewUPN@$Suffix" `
            -ChangePasswordAtLogon $False `
            -DisplayName "$($_.GivenName) $($_.Surname)"
    }

    Rename-ADObject -Identity $_.DistinguishedName -NewName "$($_.GivenName) $($_.Surname)"
}

