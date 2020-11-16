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


#Ajoute un utilisateur à l'AD
function Add-User($LastName, $FirstName, $Description, $Department, $Phone, $Office) {
    $OU = $Department.Split("/")
    #Mot de passe de 15 caractères si dans la Direction, ou 7 sinon
    $Password = Get-Password($(If ($OU[0] -eq "Direction") {15} Else {7}))

    #Génération du Path
    $Path = "";
    $OU[$OU.Length..0] | ForEach-Object {
        $Path += "OU=$_,"
    }
    $Path += "DC=Belgique,DC=lan"
    $Path
    
    #New-ADUser -Name $LastName -GivenName $FirstName -Description $Description -AccountPassword $Password -Path $Path
}

function Add-OU($name){
    $ou_name = $name
    #Crée le path selon le nom de l'UO et le dinstinguished name du serveur
    $path = $ou_name+(Get-ADDomain).DistinguishedName
    #Vérifie l'absence de l'UO et la crée
    if ([adsi]::Exists("LDAP://$path")){
        New-ADOrganizationalUnit -Name $ou_name -Path $path
    }
}

Add-User "nom" "prenom" "description" "Direction" "phone" "office"
Add-User "nom" "prenom" "description" "Techniciens/Technique" "phone" "office"

<#
Import-Csv -Delimiter ';' -Path c:\data_employees\employees.csv | ForEach-Object {
    Write-Host($_)
    #add adding-AD-user command here after creating AD

}
#>