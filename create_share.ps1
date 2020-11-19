Function Add-FolderPermission($GroupSID, $DirPath, $PermissionType, $PermissionValue) {
    $Acl = Get-Acl $DirPath
    $Perm = $GroupSID, $PermissionType, "ContainerInherit,ObjectInherit", "None", $PermissionValue
    $Rule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $Perm
    $Acl.SetAccessRule($Rule)
    $Acl | Set-Acl -Path $DirPath
}

$GroupPrefix = (Get-ADDomain).NetBIOSName

New-Item -Path "C:\" -Name "Share" -ItemType "Directory"
New-Item -Path "C:\Share" -Name "Commun" -ItemType "Directory"

$DomainPath = (Get-ADDomain).DistinguishedName

Get-ADOrganizationalUnit -Filter 'Name -NotLike "(Domain Controllers)|(Groupes)"' -SearchBase $DomainPath -SearchScope 1 | ForEach-Object {
    $Name = $_.Name
    New-Item -Path "C:\Share" -Name $Name -ItemType "Directory"
    $DirPath = "C:\Share\$Name"

    Add-FolderPermission (Get-ADGroup -Filter "Name -Eq `"GL_$Name`_R`"").SID $DirPath "Read" "Allow"
    Add-FolderPermission (Get-ADGroup -Filter "Name -Eq `"GL_$Name`_R`"").SID "C:\Share\Commun" "Read" "Allow"
    Add-FolderPermission (Get-ADGroup -Filter "Name -Eq `"GL_$Name`_Responsable_RW`"").SID $DirPath "Read,Modify" "Allow"
    Add-FolderPermission (Get-ADGroup -Filter "Name -Eq `"GL_$Name`_Responsable_RW`"").SID "C:\Share\Commun" "Read,Modify" "Allow"

    $InnerOUs = Get-ADOrganizationalUnit -Filter * -SearchBase "OU=$Name,$DomainPath"  -SearchScope 1

    $InnerOUs | ForEach-Object {
        $InnerName = $_.Name

        New-Item -Path $DirPath -Name $InnerName -ItemType "Directory"
        Add-FolderPermission (Get-ADGroup -Filter "Name -Eq `"GL_$InnerName`_RW`"").SID "$DirPath\$Name" "Read,Modify" "Allow"
        
    }

}
