$OU="Ressources humaines"

#Ecrit des fichiers de log
function Write-LogFile($Content,$Type){
    if ($Type -eq "Daily"){
        Write-Output "$(Get-Date -Format "hh:mm:ss")`t$Content" | Tee-Object -Append "$(Get-Date -Format "ddMMyy").log"
    }
    Write-Output "$(Get-Date -Format "hh:mm:ss")`t$Content" >> "log_GetOU.log"
}

$Path = (Get-ADDomain).DistinguishedName

if (-Not [adsi]::Exists("LDAP://OU=$OU,$Path")) {
    Write-Host ("L'Unité d'Organisation $OU n'existe pas")
    Exit
}
Write-LogFile "Debut de l'execution du script $($MyInvocation.MyCommand.Name)" "Daily"

#Récupère tous les utilisateurs de cette UO
Write-LogFile "Recherche des utilisateurs de l'Unite d'organisation "$OU
Get-ADUser -Filter * -SearchBase "OU=$OU,$Path"

Write-LogFile "Fin de l'execution du script $($MyInvocation.MyCommand.Name)" "Daily"