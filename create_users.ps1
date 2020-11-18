param (
    [Parameter(Mandatory=$True)][string]$CSVPath,
    [switch]$Accept
)

$Symbols = "!#$%&'()*+,-./:;<=>?@[\]^_`{|}~"

$Global:Passwords = @()

#Remplace les diacritiques par des caractères ASCII
function Remove-NonLatinCharacters($String) {
    return $String.Normalize("FormD") -replace '\p{M}', ''
}
#Récupère le nom du fichier de log
function Write-LogFile($Content,$Type){
    if ($Type -eq "Daily"){
        Write-Output "$(Get-Date -Format "hh:mm:ss")`t$Content" | Tee-Object -Append "$(Get-Date -Format "ddMMyy").log"
    }
    else 
    {
        Write-Output "$(Get-Date -Format "hh:mm:ss")`t$Content" >> "create_users.log"
    }
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

function Get-UserPrincipalName($FirstName, $LastName) {
    $FirstName = $FirstName -replace "[ -]", ""
    $LastName = $LastName -replace "[ -]", ""
    return ($FirstName.Substring(0, [math]::Min(3, $FirstName.Length)) + ($LastName -replace " ", "").Substring(0, [math]::Min(3, $LastName.Length))).ToLower()
}

function Get-OUPath($OU) {

    $Path = (Get-ADDomain).DistinguishedName

    #Pour chaque niveau d'OU, on le crée s'il n'existe pas encore

    For ($I = $OU.Length - 1; $I -Ge 0; $I--) {
        $Current = $OU[$I]
        if (-Not [adsi]::Exists("LDAP://OU=$Current,$Path")) {
            New-ADOrganizationalUnit -Name $Current -Path $Path -ProtectedFromAccidentalDeletion $False
            Write-LogFile ("Création de l'Unite d'Organisation $Current")

            New-ADGroup -Name "GG_$Current" -Description "Groupe Global pour l'OU $Current" -GroupCategory "Security" -GroupScope "Global"
            Write-LogFile ("Création du Groupe Global GG_$Current")

            New-ADGroup -Name "GL_$Current`_R" -Description "Groupe Local R pour l'OU $Current" -GroupCategory "Security" -GroupScope "DomainLocal"
            Write-LogFile ("Création du Groupe Local GL_$Current`_R")

            Add-ADGroupMember -Identity "GL_$Current`_R" -Members "GG_$Current"
            New-ADGroup -Name "GL_$Current`_RW" -Description "Groupe Local RW pour l'OU $Current" -GroupCategory "Security" -GroupScope "DomainLocal"
            Write-LogFile ("Création du Groupe Local GL_$Current`_RW")
            Add-ADGroupMember -Identity "GL_$Current`_RW" -Members "GG_$Current"

            Write-LogFile ("GG_$Current est désormais membre de et GL_$Current`_RW et GL_$Current`_RW")

            #Si l'OU est dans une autre OU, on met son GG dans le GG de l'OU parente
            If ($I -Lt $OU.Length - 1) {
                Add-ADGroupMember -Identity "GG_$($OU[$I + 1])" -Members "GG_$Current"
            }
        }
        $Path = "OU=$Current,$Path"
    }

    return $Path
}

#Ajoute un utilisateur à l'AD
function Add-User($LastName, $FirstName, $Description, $Department, $OfficePhone, $Office) {
    $OU = $Department.Split("/")
    #Mot de passe de 15 caractères si dans la Direction, ou 7 sinon
    $Password = Get-Password($(If ($OU[0] -Eq "Direction") {15} Else {7}))
    
    $LastName = $LastName.ToUpper()
    $UserPrincipalName = Get-UserPrincipalName $FirstName $LastName

    $Global:Passwords += [PSCustomObject]@{
        Nom = $LastName
        Prenom = $FirstName
        Login = $UserPrincipalName
        MDP = $Password
    }

    $Password = ConvertTo-SecureString $Password -AsPlainText -Force

    #Génération du Path
    $Path = Get-OUPath $OU
    
    New-ADUser -AccountPassword $Password `
        -ChangePasswordAtLogon $True `
        -Enabled $True `
        -Name $UserPrincipalName `
        -UserPrincipalName $UserPrincipalName `
        -Surname $LastName `
        -GivenName $FirstName `
        -Description $Description `
        -Department $Department `
        -OfficePhone $OfficePhone `
        -Office $Office `
        -Path $Path
    Write-LogFile ("Ajout de l'utilisateur $UserPrincipalName du departement $Department")

    #On ajoute l'utilisateur au GG de son OU
    Add-ADGroupMember -Identity "GG_$($OU[0])" -Members "CN=$UserPrincipalName,$Path"
}

$Users = Import-Csv -Delimiter ";" -Path $CSVPath -Encoding "UTF8"

#Demande de confirmation avant d'ajouter les utilisateurs via une MessageBox
If (-Not ($Accept.IsPresent)) {
    Add-Type -AssemblyName PresentationFramework
    $mbres = [System.Windows.MessageBox]::Show("Etes vous certain de vouloir ajouter $($Users.Length) utilisateurs ?", "Confirmation", "YesNo");
    #Si on clique sur Non
    If ($mbres -Eq "No") {
        Write-LogFile ("Annulation de l'importation")
        Exit
    }
}

#Ecrit dans le fichier de log journalier le début de l'exécution du script
Write-LogFile ("Debut de l'execution du script $($MyInvocation.MyCommand.Name)","Daily")

$Users | ForEach-Object {
    $_.PSObject.Properties | ForEach-Object {
        #On enlève les diacritiques pour chaque champ
        $_.Value = Remove-NonLatinCharacters $_.Value
    }
    
    Add-User $_."Nom" $_."Prénom" $_."Description" $_."Département" $_."N° Interne" $_."Bureau"
}

$Global:Passwords | Export-Csv -Delimiter ";" -Path "passwords.csv"
$Global:Passwords | Out-GridView

#Ecrit dans le fichier de log journalier la fin de l'exécution du script
Write-LogFile ("Fin de l'execution du script $($MyInvocation.MyCommand.Name)","Daily")
