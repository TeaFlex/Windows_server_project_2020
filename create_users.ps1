param (
    [Parameter(Mandatory=$True)][string]$CSVPath,
    [switch]$Accept
)

#Vérifie l'enregistrement de la source de log
if (-not [system.diagnostics.eventlog]::SourceExists("CreateUsers")){
    [system.diagnostics.EventLog]::CreateEventSource("CreateUsers", "Application")
}
function Write-Log($Content){
    Write-Output "$(Get-Date -Format "HH:mm:ss")`t$Content"
    Write-EventLog -LogName Application -Source "CreateUsers" -Message $Content -EventId 666
}

$Symbols = "!#$%&'()*+,-./:;<=>?@[\]^_`{|}~"

$Global:Passwords = @()
$Global:ProblematicUsers = @()

#Remplace les diacritiques par des caractères ASCII
function Remove-NonLatinCharacters($String) {
    Return $String.Normalize("FormD") -replace '\p{M}', ''
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
    Return -join ($Password -split "" | Sort-Object {Get-Random})
}

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

function Get-OUPath($OU) {

    $Path = (Get-ADDomain).DistinguishedName
    $GroupPath = "OU=Groupes,$Path"

    #Pour chaque niveau d'OU, on le crée s'il n'existe pas encore

    For ($I = $OU.Length - 1; $I -Ge 0; $I--) {
        $Current = $OU[$I]
        if (-Not [adsi]::Exists("LDAP://OU=$Current,$Path")) {
            New-ADOrganizationalUnit -Name $Current -Path $Path -ProtectedFromAccidentalDeletion $False
            Write-Log ("Création de l'Unite d'Organisation $Current")

            New-ADGroup -Name "GG_$Current" -Description "Groupe Global pour l'OU $Current" -GroupCategory "Security" -GroupScope "Global" -Path $GroupPath
            Write-Log ("Création du Groupe Global GG_$Current")

            New-ADGroup -Name "GL_$Current`_R" -Description "Groupe Local R pour l'OU $Current" -GroupCategory "Security" -GroupScope "DomainLocal" -Path $GroupPath
            Write-Log ("Création du Groupe Local GL_$Current`_R")
            Add-ADGroupMember -Identity "GL_$Current`_R" -Members "GG_$Current"

            New-ADGroup -Name "GL_$Current`_RW" -Description "Groupe Local RW pour l'OU $Current" -GroupCategory "Security" -GroupScope "DomainLocal" -Path $GroupPath
            Write-Log ("Création du Groupe Local GL_$Current`_RW")
            Add-ADGroupMember -Identity "GL_$Current`_RW" -Members "GG_$Current"

            Write-Log ("GG_$Current est désormais membre de et GL_$Current`_R et GL_$Current`_RW")

            New-ADGroup -Name "GG_$Current`_Responsable" -Description "Groupe Global pour les responsables de l'OU $Current" -GroupCategory "Security" -GroupScope "Global" -Path $GroupPath
            Write-Log ("Création du Groupe Global GG_$Current`_Responsable")

            New-ADGroup -Name "GL_$Current`_Responsable_R" -Description "Groupe Local R pour les responsables de l'OU $Current" -GroupCategory "Security" -GroupScope "DomainLocal" -Path $GroupPath
            Write-Log ("Création du Groupe Local GL_$Current`_Responsable_R")

            New-ADGroup -Name "GL_$Current`_Responsable_RW" -Description "Groupe Local RW pour les responsables de l'OU $Current" -GroupCategory "Security" -GroupScope "DomainLocal" -Path $GroupPath
            Write-Log ("Création du Groupe Local GL_$Current`_Responsable_RW")

            #Si l'OU est dans une autre OU, on met son GG dans le GG de l'OU parente
            If ($I -Lt $OU.Length - 1) {
                Add-ADGroupMember -Identity "GG_$($OU[$I + 1])" -Members "GG_$Current"
            }
        }
        $Path = "OU=$Current,$Path"
    }

    Return $Path
}

#Ajoute un utilisateur à l'AD
function Add-User($LastName, $FirstName, $Description, $Department, $OfficePhone, $Office) {
    $OU = $Department.Split("/")
    #Mot de passe de 15 caractères si dans la Direction, ou 7 sinon
    $Password = Get-Password($(If ($OU[0] -Eq "Direction") {15} Else {7}))
    
    $LastName = $LastName.ToUpper()
    $UserPrincipalName = Get-UserPrincipalName $FirstName $LastName

    If ([bool] (Get-ADUser -Filter 'Name -Eq "$($_.UserPrincipalName)"')) {
        $Global:ProblematicUsers += [PSCustomObject]@{
            Nom = $LastName
            Prenom = $FirstName
            Raison = "UPN Existe déjà"
        }
        Return
    }

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
        -Enabled $True `
        -Name $UserPrincipalName `
        -DisplayName "$FirstName $LastName" `
        -UserPrincipalName "$UserPrincipalName@$((Get-ADDomain).Forest)" `
        -Surname $LastName `
        -GivenName $FirstName `
        -Description $Description `
        -Department $Department `
        -OfficePhone $OfficePhone `
        -Office $Office `
        -Path $Path
    Write-Log ("Ajout de l'utilisateur $UserPrincipalName du département $Department")

    #On ajoute l'utilisateur au GG de son OU
    Add-ADGroupMember -Identity "GG_$($OU[0])" -Members "CN=$UserPrincipalName,$Path"
}

New-ADOrganizationalUnit -Name "Groupes" -Path (Get-ADDomain).DistinguishedName -ProtectedFromAccidentalDeletion $False

$Users = Import-Csv -Delimiter ";" -Path $CSVPath -Encoding "UTF8"

#Demande de confirmation avant d'ajouter les utilisateurs via une MessageBox
If (-Not ($Accept.IsPresent)) {
    Add-Type -AssemblyName PresentationFramework
    $mbres = [System.Windows.MessageBox]::Show("Etes-vous certain de vouloir ajouter $($Users.Length) utilisateurs ?", "Confirmation", "YesNo");
    #Si on clique sur Non
    If ($mbres -Eq "No") {
        Write-Host ("Annulation de l'importation")
        Exit
    }
}

#Ecrit dans le fichier de log journalier le début de l'exécution du script
Write-Log "Début de l'exécution du script $($MyInvocation.MyCommand.Name)"

$Max = $Users.Length
$Progress = 0

$Users | ForEach-Object {
    $_.PSObject.Properties | ForEach-Object {
        #On enlève les diacritiques pour chaque champ
        $_.Value = Remove-NonLatinCharacters $_.Value
    }
    Try {
        Add-User $_."Nom" $_."Prénom" $_."Description" $_."Département" $_."N° Interne" $_."Bureau"
    }
    Catch {
        Write-Log "Erreur lors de l'exécution du script: $($_.ScriptStackTrace)`n`t$($_)"
    }
    $Progress++
    $Display = [math]::floor(($Progress/$Max)*100)
    Write-Progress -Activity "Exécution du script en cours..." -Status "$Display% Complété: " -PercentComplete $Display; 
}

$Global:Passwords | Export-Csv -Delimiter ";" -Path "passwords.csv"
$Global:Passwords | Out-GridView

$Global:ProblematicUsers | Export-Csv -Delimiter ";" -Path "problematic_users.csv"

#Ecrit dans le fichier de log journalier la fin de l'exécution du script
Write-Log "Fin de l'exécution du script $($MyInvocation.MyCommand.Name)"
