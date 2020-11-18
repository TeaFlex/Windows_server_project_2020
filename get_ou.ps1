param (
    [Parameter(Mandatory=$True)][string]$OU
)

#Ecrit des fichiers de log
function Write-LogFile($Content,$Type){
    if ($Type -eq "Daily"){
        Write-Output "$(Get-Date -Format "hh:mm:ss")`t$Content" | Tee-Object -Append "$(Get-Date -Format "ddMMyy").log"
    }
    Write-Output "$(Get-Date -Format "hh:mm:ss")`t$Content" >> "log_GetOU.log"
}
$Test = Get-ADOrganizationalUnit -Filter "Name -eq '$OU'"
if (-not $Test) {
    Write-Host ("L'Unite d'Organisation $OU n'existe pas")
    Exit
}
Write-LogFile "Debut de l'execution du script $($MyInvocation.MyCommand.Name)" "Daily"

#Récupère tous les utilisateurs de cette UO
Write-LogFile "Recherche des utilisateurs de l'Unite d'organisation $OU"
Get-ADUser -Filter * -SearchBase ($Test) #| Export-Csv -Delimiter ";" -Path "RH_Users.csv"

Write-LogFile "Fin de l'execution du script $($MyInvocation.MyCommand.Name)" "Daily"