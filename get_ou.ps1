param (
    [Parameter(Mandatory=$True)][string]$OU
)

#Ecrit des fichiers de log
function Write-LogFile($Content,$Type){
    if ($Type -eq "Daily"){
        Write-Output "$(Get-Date -Format "HH:mm:ss")`t$Content" | Tee-Object -Append "log_$(Get-Date -Format "ddMMyy").log"
    }
    Write-Output "$(Get-Date -Format "HH:mm:ss")`t$Content" >> "log_GetOU.log"
}
$Target = Get-ADOrganizationalUnit -Filter "Name -eq '$OU'"
if (-not $Target) {
    Write-Host ("L'Unite d'Organisation $OU n'existe pas")
    Exit
}
Write-LogFile "Debut de l'execution du script $($MyInvocation.MyCommand.Name)" "Daily"

#Récupère tous les utilisateurs de cette UO
Write-LogFile "Recherche des utilisateurs de l'Unite d'organisation $OU"
$Result=Get-ADUser -Filter * -SearchBase ($Target)

#Crée le fichier de listing de l'UO et affiche dans une fenêtre
$Result | Export-Csv -Delimiter ";" -Path "userlist_$($OU -replace ' ','').csv"
$Result | Out-GridView

Write-LogFile "Fin de l'execution du script $($MyInvocation.MyCommand.Name)" "Daily"