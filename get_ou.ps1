param (
    [Parameter(Mandatory=$True)][string]$OU
)

#Vérifie l'enregistrement de la source de log
if (-not [system.diagnostics.eventlog]::SourceExists("GetOU")){
    [system.diagnostics.EventLog]::CreateEventSource("GetOU", "Application")
}
function Write-Log($Content){
    Write-Output "$(Get-Date -Format "HH:mm:ss")`t$Content"
    Write-EventLog -LogName Application -Source "GetOU" -Message $Content -EventId 666
}

$Target = Get-ADOrganizationalUnit -Filter "Name -eq '$OU'"
if (-not $Target) {
    Write-Host ("L'Unite d'Organisation $OU n'existe pas")
    Exit
}
Write-Log "Debut de l'execution du script $($MyInvocation.MyCommand.Name)" "Daily"

#Récupère tous les utilisateurs de cette UO
Write-Log "Recherche des utilisateurs de l'Unite d'organisation $OU"
$Result=Get-ADUser -Filter * -SearchBase ($Target)

#Crée le fichier de listing de l'UO et affiche dans une fenêtre
$Result | Export-Csv -Delimiter ";" -Path "userlist_$($OU -replace ' ','').csv"
$Result | Out-GridView

Write-Log "Fin de l'execution du script $($MyInvocation.MyCommand.Name)" "Daily"