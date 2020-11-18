$Global:ProblematicUsers = @()

$Suffix = (Get-ADDomain).Forest

#Génère l'UPN de l'utilisateur sur base de son nom et prénom
function Get-UserPrincipalName($FirstName, $LastName) {
    $FirstName = ($FirstName -replace "[ -]", "").ToLower()
    $LastName = ($LastName -replace "[ -]", "").ToLower()

    #Si prénom.nom fait moins de 20 caractères, on prend ça
    If ($FirstName.Length + $LastName.Length -Lt 20) {
        Return "$FirstName.$LastName"
    }
    #Sinon, si [première lettre du prénom].nom fait moins de 20 caractères, on prend ça
    If ($LastName.Length -Lt 19) {
        Return "$($FirstName[0]).$LastName"
    }
    #Sinon, explosion
    $Global:ProblematicUsers += [PSCustomObject]@{
        Nom = $LastName
        Prenom = $FirstName
        Raison = "Nom trop long"
    }
}

Get-ADUser -Filter * | ForEach-Object {
    If (-Not [string]::IsNullOrEmpty($_.UserPrincipalName)) { 
        $NewUPN = Get-UserPrincipalName $_.GivenName $_.Surname

        If ([bool] (Get-ADUser -Filter 'Name -Eq "$($_.UserPrincipalName)"')) {
            $Global:ProblematicUsers += [PSCustomObject]@{
                Nom = $LastName
                Prenom = $FirstName
                Raison = "UPN Existe déjà"
            }
            Return
        }

        Set-ADUser -Identity $_.UserPrincipalName `
            -UserPrincipalName "$NewUPN@$Suffix" `
            -SamAccountName $NewUPN `
            -ChangePasswordAtLogon $False `
            -DisplayName "$($_.GivenName) $($_.Surname)"

        Rename-ADObject -Identity $_.DistinguishedName -NewName "$($_.GivenName) $($_.Surname)"
    }
}

$Global:ProblematicUsers | Export-Csv -Delimiter ";" -Path "problematic_users_update.csv"