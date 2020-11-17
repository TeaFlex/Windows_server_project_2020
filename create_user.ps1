param (
    [Parameter(Mandatory=$True)][string]$CSVPath
)

$Symbols = "!#$%&'()*+,-./:;<=>?@[\]^_`{|}~"

#Remplace les diacritiques par des caractères ASCII
function Remove-NonLatinCharacters($String) {
    return $String.Normalize("FormD") -replace '\p{M}', ''
}

#Génère un mot de passe aléatoire
function Get-Password($Length) {
    $Length
    #Un chiffre
    $Password = (Get-Random 10).ToString();
    #Une lettre majuscule
    $Password += (65..90) | Get-Random | % {[char]$_}
    #Un symbole
    $Password += $Symbols[(Get-Random -Maximum $Symbols.Length)]
    #Le reste en lettres minuscules
    $Password += -join ((97..122) | Get-Random -Count ($Length - 3) | % {[char]$_})
    #Résultat mélangé
    return -join ($Password -split "" | Sort-Object {Get-Random})
}

function Get-OUPath($OU) {

    $Path = (Get-ADDomain).DistinguishedName

    #Pour chaque niveau d'OU, on le crée s'il n'existe pas encore
    $OU[$OU.Length..0] | ForEach-Object {
        $Path = "OU=$_,$Path"
        if (-Not [adsi]::Exists("LDAP://$Path")) {
            New-ADOrganizationalUnit -Name $_ -Path $Path
        }
    }

    return $Path
}

#Ajoute un utilisateur à l'AD
function Add-User($LastName, $FirstName, $Description, $Department, $Phone, $Office) {
    $OU = $Department.Split("/")
    #Mot de passe de 15 caractères si dans la Direction, ou 7 sinon
    $Password = Get-Password($(If ($OU[0] -eq "Direction") {15} Else {7}))

    #Génération du Path
    $Path = Get-OUPath $OU
    
    New-ADUser -AccountPassword $Password `
        -ChangePasswordAtLogon $True `
        -Enabled $True `
        -Name $LastName `
        -GivenName $FirstName `
        -Description $Description `
        -Path $Path
}

$CSV = Import-Csv -Delimiter ';' -Path $CSVPath -Encoding "UTF8"
Remove-NonLatinCharacters $CSV[25]."Nom"

