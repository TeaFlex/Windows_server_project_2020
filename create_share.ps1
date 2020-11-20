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

Function Remove-NTFSInheritance($Path) {
    $Acl = Get-Acl $Path
    $Acl.SetAccessRuleProtection($True, $False)
    $Acl.Access | ForEach-Object {$Acl.RemoveAccessRule($_)}
    $PermAdmin = "BUILTIN\Administrateurs", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
    $RuleAdmin = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $PermAdmin
    $Acl.SetAccessRule($RuleAdmin)
    $Acl | Set-Acl -Path $Path
}

#Ecrit dans le fichier de log journalier le début de l'exécution du script
Write-Log "Début de l'exécution du script $($MyInvocation.MyCommand.Name)"

New-Item -Path "C:\" -Name "Share" -ItemType "Directory"
New-Item -Path "C:\Share" -Name "Commun" -ItemType "Directory"

#On enlève l'héritage NTFS au dossier Share
Remove-NTFSInheritance "C:\Share"
$Acl = Get-Acl "C:\Share"
$PermUser = "BUILTIN\Utilisateurs du domaine", "Read", "None", "None", "Allow"
$RuleUser = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $Permuser
$Acl.SetAccessRule($RuleUser)
$Acl | Set-Acl -Path "C:\Share"

$DomainPath = (Get-ADDomain).DistinguishedName
$DirectionRWSID = (Get-ADGroup -Filter "Name -Eq `"GL_Direction_RW`"").SID

#On itère sur les OU des départements
Get-ADOrganizationalUnit -Filter '(Name -Ne "Domain Controllers") -And (Name -Ne "Groupes")' -SearchBase $DomainPath -SearchScope 1 | ForEach-Object {
    $Name = $_.Name
    New-Item -Path "C:\Share" -Name $Name -ItemType "Directory"
    Write-Log "Création du dossier $Name"
    $DirPath = "C:\Share\$Name"

    Remove-NTFSInheritance $DirPath

    #Permissions membres de l'OU
    Add-FolderPermission (Get-ADGroup -Filter "Name -Eq `"GL_$Name`_R`"").SID $DirPath "Read" "Allow"
    Add-FolderPermission (Get-ADGroup -Filter "Name -Eq `"GL_$Name`_R`"").SID "C:\Share\Commun" "Read" "Allow"
    #Permissions responsables de l'OU
    Add-FolderPermission (Get-ADGroup -Filter "Name -Eq `"GL_$Name`_Responsable_RW`"").SID $DirPath "Read,Modify" "Allow"
    Add-FolderPermission (Get-ADGroup -Filter "Name -Eq `"GL_$Name`_Responsable_RW`"").SID "C:\Share\Commun" "Read,Modify" "Allow"
    #Permissions RW Direction
    Add-FolderPermission $DirectionRWSID $DirPath "Read,Modify" "Allow"


    $Responsables = (Get-ADGroup -Filter "Name -Eq `"GG_$Name`_Responsable`"" | Get-ADGroupMember | Get-ADUser | ForEach-Object { "$($_.GivenName) $($_.Surname)" }) -join ", "
    
    $Action80 = New-FsrmAction -Type "Event" -EventType "Information" -Body "Stockage du département $Name rempli à 80%." -RunLimitInterval 180
    $Threshold80 = New-FsrmQuotaThreshold -Percentage 80 -Action $Action80
    $Action90 = New-FsrmAction -Type "Event" -EventType "Information" -Body "Stockage du département $Name rempli à 90%. Contacter les responsables : $Responsables." -RunLimitInterval 180
    $Threshold90 = New-FsrmQuotaThreshold -Percentage 90 -Action $Action90
    $Action100 = New-FsrmAction -Type "Event" -EventType "Information" -Body "Stockage du département $Name rempli à 100%. Contacter les responsables : $Responsables." -RunLimitInterval 180
    $Threshold100 = New-FsrmQuotaThreshold -Percentage 100 -Action $Action100
    $Thresholds = $Threshold80, $Threshold90, $Threshold100
    New-FsrmQuotaTemplate "Quota $Name" -Size 500MB -Threshold $Thresholds
    New-FsrmQuota -Path $DirPath -Template "Quota $Name" 


    $InnerOUs = Get-ADOrganizationalUnit -Filter * -SearchBase "OU=$Name,$DomainPath"  -SearchScope 1

    #On itère sur les OU des sous-départements
    $InnerOUs | ForEach-Object {
        $InnerName = $_.Name

        New-Item -Path $DirPath -Name $InnerName -ItemType "Directory"
        Write-Log "Création du dossier $Name/$InnerName"
        Add-FolderPermission (Get-ADGroup -Filter "Name -Eq `"GL_$InnerName`_RW`"").SID "$DirPath\$InnerName" "Read,Modify" "Allow"


            $InnerAction80 = New-FsrmAction -Type "Event" -EventType "Information" -Body "Stockage du sous-département $InnerName rempli à 80%." -RunLimitInterval 180
            $InnerThreshold80 = New-FsrmQuotaThreshold -Percentage 80 -Action $InnerAction80
            $InnerAction90 = New-FsrmAction -Type "Event" -EventType "Information" -Body "Stockage du sous-département $InnerName rempli à 90%. Contacter les responsables : $Responsables." -RunLimitInterval 180
            $InnerThreshold90 = New-FsrmQuotaThreshold -Percentage 90 -Action $InnerAction90
            $InnerAction100 = New-FsrmAction -Type "Event" -EventType "Information" -Body "Stockage du sous-département $Name rempli à 100%. Contacter les responsables : $Responsables." -RunLimitInterval 180
            $InnerThreshold100 = New-FsrmQuotaThreshold -Percentage 100 -Action $InnerAction100
            $InnerThresholds = $InnerThreshold80, $InnerThreshold90, $InnerThreshold100
            New-FsrmQuotaTemplate "Quota $InnerName" -Size 100MB -Threshold $InnerThresholds
            New-FsrmQuota -Path "$DirPath\$InnerName" -Template "Quota $InnerName" 
    }
}

Add-FolderPermission $DirectionRWSID "C:\Share\Commun" "Read,Modify" "Allow"

New-FsrmQuotaTemplate "Quota Commun" -Size 500MB
New-FsrmQuota -Path "C:\Share\Commun" -Template "Quota Commun" 

#Ecrit dans le fichier de log journalier la fin de l'exécution du script
Write-Log "Fin de l'exécution du script $($MyInvocation.MyCommand.Name)"