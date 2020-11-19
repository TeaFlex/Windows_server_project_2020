#Ecrit des fichiers de log
$LogsDirectory="C:\AdministrationLogs\"
if(!(Test-Path -Path $LogsDirectory )){
    New-Item -ItemType directory -Path $LogsDirectory
}
function Write-LogFile($Content,$Type){
    if ($Type -eq "Daily"){
        Write-Output "$(Get-Date -Format "HH:mm:ss")`t$Content" | Tee-Object -Append $LogsDirectory"daily_$(Get-Date -Format "ddMMyy").log"
    }
    Write-Output "$(Get-Date -Format "HH:mm:ss")`t$Content" >> $LogsDirectory"script_CreateShare.log"
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
Write-LogFile "Debut de l'execution du script $($MyInvocation.MyCommand.Name)" "Daily"

New-Item -Path "C:\" -Name "Share" -ItemType "Directory"
New-Item -Path "C:\Share" -Name "Commun" -ItemType "Directory"

$DomainPath = (Get-ADDomain).DistinguishedName
$DirectionRWSID = (Get-ADGroup -Filter "Name -Eq `"GL_Direction_RW`"").SID

#On itère sur les OU des départements
Get-ADOrganizationalUnit -Filter '(Name -Ne "Domain Controllers") -And (Name -Ne "Groupes")' -SearchBase $DomainPath -SearchScope 1 | ForEach-Object {
    $Name = $_.Name
    New-Item -Path "C:\Share" -Name $Name -ItemType "Directory"
    Write-LogFile "Creation du dossier $Name"
    $DirPath = "C:\Share\$Name"

    #Permissions membres de l'OU
    Add-FolderPermission (Get-ADGroup -Filter "Name -Eq `"GL_$Name`_R`"").SID $DirPath "Read" "Allow"
    Add-FolderPermission (Get-ADGroup -Filter "Name -Eq `"GL_$Name`_R`"").SID "C:\Share\Commun" "Read" "Allow"
    #Permissions responsables de l'OU
    Add-FolderPermission (Get-ADGroup -Filter "Name -Eq `"GL_$Name`_Responsable_RW`"").SID $DirPath "Read,Modify" "Allow"
    Add-FolderPermission (Get-ADGroup -Filter "Name -Eq `"GL_$Name`_Responsable_RW`"").SID "C:\Share\Commun" "Read,Modify" "Allow"
    #Permissions RW Direction
    Add-FolderPermission $DirectionRWSID $DirPath "Read,Modify" "Allow"


    $Responsables = Get-ADGroup -Filter "Name -Eq `"GG_$Name`_Responsable`"" | Get-ADGroupMember | Get-ADUser | ForEach-Object { "$($_.GivenName) $($_.Surname)" } -join ", "
    
    $Action80 = New-FsrmAction -Type "Event" -EventType "Information" -Body "Stockage du département $Name rempli à 80%." -RunLimitInterval 180
    $Treshold80 = New-FsrmQuotaTreshold -Percentage 80 -Action $Action80
    $Action90 = New-FsrmAction -Type "Event" -EventType "Information" -Body "Stockage du département $Name rempli à 90%. Contacter les responsables : $Responsables." -RunLimitInterval 180
    $Treshold90 = New-FsrmQuotaTreshold -Percentage 90 -Action $Action90
    $Action100 = New-FsrmAction -Type "Event" -EventType "Information" -Body "Stockage du département $Name rempli à 100%. Contacter les responsables : $Responsables." -RunLimitInterval 180
    $Treshold100 = New-FsrmQuotaTreshold -Percentage 100 -Action $Action100
    $Tresholds = $Treshold80, $Treshold90, $Treshold100
    New-FsrmQuotaTemplate "Quota $Name" 500MB -Treshold $Tresholds
    New-FsrmQuota -Path $DirPath -Template "Quota $Name" 


    $InnerOUs = Get-ADOrganizationalUnit -Filter * -SearchBase "OU=$Name,$DomainPath"  -SearchScope 1

    #On itère sur les OU des sous-départements
    $InnerOUs | ForEach-Object {
        $InnerName = $_.Name

        New-Item -Path $DirPath -Name $InnerName -ItemType "Directory"
        Write-LogFile "Creation du dossier $Name/$InnerName"
        Add-FolderPermission (Get-ADGroup -Filter "Name -Eq `"GL_$InnerName`_RW`"").SID "$DirPath\$InnerName" "Read,Modify" "Allow"


            $InnerAction80 = New-FsrmAction -Type "Event" -EventType "Information" -Body "Stockage du département $InnerName rempli à 80%." -RunLimitInterval 180
            $InnerTreshold80 = New-FsrmQuotaTreshold -Percentage 80 -Action $InnerAction80
            $InnerAction90 = New-FsrmAction -Type "Event" -EventType "Information" -Body "Stockage du département $InnerName rempli à 90%. Contacter les responsables : $Responsables." -RunLimitInterval 180
            $InnerTreshold90 = New-FsrmQuotaTreshold -Percentage 90 -Action $InnerAction90
            $InnerAction100 = New-FsrmAction -Type "Event" -EventType "Information" -Body "Stockage du département $Name rempli à 100%. Contacter les responsables : $Responsables." -RunLimitInterval 180
            $InnerTreshold100 = New-FsrmQuotaTreshold -Percentage 100 -Action $InnerAction100
            $InnerTresholds = $InnerTreshold80, $InnerTreshold90, $InnerTreshold100
            New-FsrmQuotaTemplate "Quota $InnerName" 100MB -Treshold $InnerTresholds
            New-FsrmQuota -Path "$DirPath\$InnerName" -Template "Quota $InnerName" 
    }
}

Add-FolderPermission $DirectionRWSID "C:\Share\Commun" "Read,Modify" "Allow"

#Ecrit dans le fichier de log journalier la fin de l'exécution du script
Write-LogFile "Fin de l'execution du script $($MyInvocation.MyCommand.Name)" "Daily"