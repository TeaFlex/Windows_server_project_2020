param (
    [Parameter(Mandatory=$True)][string]$CSVPath
)

#Ecrit dans le fichier de log journalier le début de l'exécution du script
Write-Output "$(Get-Date -Format "hh:mm:ss")`tDebut de l'execution du script $($MyInvocation.MyCommand.Name)" >> "$(Get-Date -Format "ddMMyy").log"

$Symbols = "!#$%&'()*+,-./:;<=>?@[\]^_`{|}~"

$Global:Passwords = @()

#Remplace les diacritiques par des caractères ASCII
function Remove-NonLatinCharacters($String) {
    return $String.Normalize("FormD") -replace '\p{M}', ''
}

#Génère un mot de passe aléatoire
function Get-Password($Length) {
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

function Get-SamAccountName($FirstName, $LastName) {
    return ($FirstName.Substring(0, 3) + ($LastName -replace " ", "").Substring(0, 3)).ToLower()
}

function Get-OUPath($OU) {

    $Path = (Get-ADDomain).DistinguishedName

    #Pour chaque niveau d'OU, on le crée s'il n'existe pas encore
    $OU[$OU.Length..0] | ForEach-Object {
        if (-Not [adsi]::Exists("LDAP://OU=$_,$Path")) {
            New-ADOrganizationalUnit -Name $_ -Path $Path >> C:\Logs\create_users.log
        }
        $Path = "OU=$_,$Path"
    }

    return $Path
}

#Ajoute un utilisateur à l'AD
function Add-User($LastName, $FirstName, $Description, $Department, $OfficePhone, $Office) {
    $OU = $Department.Split("/")
    #Mot de passe de 15 caractères si dans la Direction, ou 7 sinon
    $Password = Get-Password($(If ($OU[0] -eq "Direction") {15} Else {7}))
    
    $LastName = $LastName.ToUpper()

    $Global:Passwords += [PSCustomObject]@{
        Nom = $LastName
        Prenom = $FirstName
        MDP = $Password
    }

    $Password = ConvertTo-SecureString $Password -AsPlainText -Force

    $SamAccountName = Get-SamAccountName $FirstName $LastName

    #Génération du Path
    $Path = Get-OUPath $OU
    
    New-ADUser -AccountPassword $Password `
        -ChangePasswordAtLogon $True `
        -Enabled $True `
        -SamAccountName $SamAccountName `
        -Name $LastName `
        -GivenName $FirstName `
        -Description $Description `
        -Department $Department `
        -OfficePhone $OfficePhone `
        -Path $Path
    >> C:\Logs\create_users.log
}

$Users = Import-Csv -Delimiter ";" -Path $CSVPath -Encoding "UTF8"


$Users | ForEach-Object {
    $_.PSObject.Properties | ForEach-Object {
        #On enlève les diacritiques pour chaque champ
        $_.Value = Remove-NonLatinCharacters $_.Value
    }
    
    Add-User $_."Nom" $_."Prénom" $_."Description" $_."Département" $_."N° Interne" $_"Bureau"
}

$Global:Passwords | Export-Csv -Delimiter ";" -Path "passwords.csv"
$Global:Passwords | Out-GridView

#Ecrit dans le fichier de log journalier le début de l'exécution du script
Write-Output "$(Get-Date -Format "hh:mm:ss")`tFin de l'execution du script $($MyInvocation.MyCommand.Name)" >> "$(Get-Date -Format "ddMMyy").log"
