#Vérifie l'enregistrement de la source de log
if (-not [system.diagnostics.eventlog]::SourceExists("CreateShare")){
    [system.diagnostics.EventLog]::CreateEventSource("CreateShare", "Application")
}
function Write-Log($Content){
    Write-Output "$(Get-Date -Format "HH:mm:ss")`t$Content"
    Write-EventLog -LogName Application -Source "CreateShare" -Message $Content -EventId 666
}

#Ajoute une permission pour un groupe à un dossier
Function Add-FolderPermission($GroupSID, $DirPath, $PermissionType, $PermissionValue) {
    $Acl = Get-Acl $DirPath
    $Perm = $GroupSID, $PermissionType, "ContainerInherit,ObjectInherit", "None", $PermissionValue
    $Rule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $Perm
    $Acl.SetAccessRule($Rule)
    $Acl | Set-Acl -Path $DirPath
}

#Ecrit dans le fichier de log journalier le début de l'exécution du script
Write-Log "Debut de l'execution du script $($MyInvocation.MyCommand.Name)"

New-Item -Path "C:\" -Name "Share" -ItemType "Directory"
New-Item -Path "C:\Share" -Name "Commun" -ItemType "Directory"

$DomainPath = (Get-ADDomain).DistinguishedName
$DirectionRWSID = (Get-ADGroup -Filter "Name -Eq `"GL_Direction_RW`"").SID

#On itère sur les OU des départements
Get-ADOrganizationalUnit -Filter '(Name -Ne "Domain Controllers") -And (Name -Ne "Groupes")' -SearchBase $DomainPath -SearchScope 1 | ForEach-Object {
    $Name = $_.Name
    New-Item -Path "C:\Share" -Name $Name -ItemType "Directory"
    Write-Log "Creation du dossier $Name"
    $DirPath = "C:\Share\$Name"

    #Permissions membres de l'OU
    Add-FolderPermission (Get-ADGroup -Filter "Name -Eq `"GL_$Name`_R`"").SID $DirPath "Read" "Allow"
    Add-FolderPermission (Get-ADGroup -Filter "Name -Eq `"GL_$Name`_R`"").SID "C:\Share\Commun" "Read" "Allow"
    #Permissions responsables de l'OU
    Add-FolderPermission (Get-ADGroup -Filter "Name -Eq `"GL_$Name`_Responsable_RW`"").SID $DirPath "Read,Modify" "Allow"
    Add-FolderPermission (Get-ADGroup -Filter "Name -Eq `"GL_$Name`_Responsable_RW`"").SID "C:\Share\Commun" "Read,Modify" "Allow"
    #Permissions RW Direction
    Add-FolderPermission $DirectionRWSID $DirPath "Read,Modify" "Allow"

    $InnerOUs = Get-ADOrganizationalUnit -Filter * -SearchBase "OU=$Name,$DomainPath"  -SearchScope 1

    #On itère sur les OU des sous-départements
    $InnerOUs | ForEach-Object {
        $InnerName = $_.Name

        New-Item -Path $DirPath -Name $InnerName -ItemType "Directory"
        Write-Log "Creation du dossier $Name/$InnerName"
        Add-FolderPermission (Get-ADGroup -Filter "Name -Eq `"GL_$InnerName`_RW`"").SID "$DirPath\$InnerName" "Read,Modify" "Allow"
    }
}

Add-FolderPermission $DirectionRWSID "C:\Share\Commun" "Read,Modify" "Allow"

#Ecrit dans le fichier de log journalier la fin de l'exécution du script
Write-Log "Fin de l'execution du script $($MyInvocation.MyCommand.Name)"