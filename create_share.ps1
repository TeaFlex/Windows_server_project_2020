Function Add-FolderPermission($GroupSID, $DirPath, $PermissionType, $PermissionValue) {
    $Acl = Get-Acl $DirPath
    $Perm = $GroupSID, $PermissionType, "ContainerInherit,ObjectInherit", "None", $PermissionValue
    $Rule = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $Perm
    $Acl.SetAccessRule($Rule)
    $Acl | Set-Acl -Path $DirPath
}

$GroupPrefix = (Get-ADDomain).NetBIOSName

New-Item -Path "C:\" -Name "Share" -ItemType "Directory"
#Add-ShareDirectory (Get-ADDomain).DistinguishedName "C:\Share"

$DomainPath = (Get-ADDomain).DistinguishedName

Get-ADOrganizationalUnit -Filter 'Name -NotLike "(Domain Controllers)|(Groupes)' -SearchBase $DomainPath -SearchScope 1 | ForEach-Object {
    $Name = $_.Name
    New-Item -Path "C:\Share" -Name $Name -ItemType "Directory"
    $DirPath = "C:\Share\$Name"

    $GroupSID = (Get-ADGroup -Filter "Name -Eq `"GL_$Name`_R`"").SID
    Add-FolderPermission $GroupSID $DirPath "Read" "Allow"
    
    $InnerOUs = Get-ADOrganizationalUnit -Filter * -SearchBase "OU=$($_.Name),$DomainPath"  -SearchScope 1

    $InnerOUs | ForEach-Object {
        New-Item -Path $DirPath -Name $_.Name -ItemType "Directory"

        
    }

}


