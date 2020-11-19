#Ecrit des fichiers de log
function Write-LogFile($Content,$Type){
    if ($Type -eq "Daily"){
        Write-Output "$(Get-Date -Format "HH:mm:ss")`t$Content" | Tee-Object -Append "log_$(Get-Date -Format "ddMMyy").log"
    }
    Write-Output "$(Get-Date -Format "HH:mm:ss")`t$Content" >> "log_CreateShare.log"
}
Function Add-FolderPermission($GroupSID, $DirPath, $PermissionType, $PermissionValue) {
    $Acl = Get-Acl $DirPath
    $Perm = $GroupSID, $PermissionType, "ContainerInherit,ObjectInherit", "None", $PermissionValue
    $Rule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $Perm
    $Acl.SetAccessRule($Rule)
    $Acl | Set-Acl -Path $DirPath
}

#Ecrit dans le fichier de log journalier le début de l'exécution du script
Write-LogFile "Debut de l'execution du script $($MyInvocation.MyCommand.Name)" "Daily"

$GroupPrefix = (Get-ADDomain).NetBIOSName

New-Item -Path "C:\" -Name "Share" -ItemType "Directory"
New-Item -Path "C:\Share" -Name "Commun" -ItemType "Directory"

$DomainPath = (Get-ADDomain).DistinguishedName

Get-ADOrganizationalUnit -Filter '(Name -Ne "Domain Controllers") -And (Name -Ne "Groupes")' -SearchBase $DomainPath -SearchScope 1 | ForEach-Object {
    $Name = $_.Name
    New-Item -Path "C:\Share" -Name $Name -ItemType "Directory"
    Write-LogFile "Creation du dossier $Name"
    $DirPath = "C:\Share\$Name"

    Add-FolderPermission (Get-ADGroup -Filter "Name -Eq `"GL_$Name`_R`"").SID $DirPath "Read" "Allow"
    Add-FolderPermission (Get-ADGroup -Filter "Name -Eq `"GL_$Name`_R`"").SID "C:\Share\Commun" "Read" "Allow"
    Add-FolderPermission (Get-ADGroup -Filter "Name -Eq `"GL_$Name`_Responsable_RW`"").SID $DirPath "Read,Modify" "Allow"
    Add-FolderPermission (Get-ADGroup -Filter "Name -Eq `"GL_$Name`_Responsable_RW`"").SID "C:\Share\Commun" "Read,Modify" "Allow"

    $InnerOUs = Get-ADOrganizationalUnit -Filter * -SearchBase "OU=$Name,$DomainPath"  -SearchScope 1

    $InnerOUs | ForEach-Object {
        $InnerName = $_.Name

        New-Item -Path $DirPath -Name $InnerName -ItemType "Directory"
        Write-LogFile "Creation du dossier $Name/$InnerName"
        Add-FolderPermission (Get-ADGroup -Filter "Name -Eq `"GL_$InnerName`_RW`"").SID "$DirPath\$InnerName" "Read,Modify" "Allow"
        
    }
}

#Ecrit dans le fichier de log journalier la fin de l'exécution du script
Write-LogFile "Fin de l'execution du script $($MyInvocation.MyCommand.Name)" "Daily"