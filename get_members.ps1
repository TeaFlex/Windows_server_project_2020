﻿param (
    [Parameter(Mandatory=$True)][string]$OU
)

#Vérifie l'enregistrement de la source de log
if (-not [system.diagnostics.eventlog]::SourceExists("GetMembers")){
    [system.diagnostics.EventLog]::CreateEventSource("GetMembers", "Application")
}
function Write-Log($Content){
    Write-Output "$(Get-Date -Format "HH:mm:ss")`t$Content"
    Write-EventLog -LogName Application -Source "GetMembers" -Message $Content -EventId 666
}

$Target = Get-ADOrganizationalUnit -Filter "Name -eq '$OU'"
if (-not $Target) {
    Write-Host ("L'Unité d'Organisation $OU n'existe pas")
    Exit
}
Write-Log "Début de l'exécution du script $($MyInvocation.MyCommand.Name)"

#Récupère tous les utilisateurs de cette UO
Write-Log "Recherche des utilisateurs de l'Unite d'organisation $OU"
$Result=Get-ADUser -Filter * -SearchBase ($Target)

#Crée le fichier de listing de l'UO et affiche dans une fenêtre
$Result | Export-Csv -Delimiter ";" -Path "userlist_$($OU -replace ' ','').csv"
$Result | Out-GridView

Write-Log "Fin de l'exécution du script $($MyInvocation.MyCommand.Name)"