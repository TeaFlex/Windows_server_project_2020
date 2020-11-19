<#
Function Add-ShareDirectory($OUPath, $DirectoryPath) {
    Get-ADOrganizationalUnit -Filter 'Name -NotLike "Domain Controllers"' -SearchBase $Path -SearchScope 1 | ForEach-Object {
        $Name = $_.Name
        New-Item -Path $DirectoryPath -Name $Name -ItemType "Directory"
        Add-ShareDirectory("OU=$Name,$OUPath", "$DirectoryPath\$Name")
    }
}
#>


New-Item -Path "C:\" -Name "Share" -ItemType "Directory"
#Add-ShareDirectory (Get-ADDomain).DistinguishedName "C:\Share"

$DomainPath = (Get-ADDomain).DistinguishedName

Get-ADOrganizationalUnit -Filter 'Name -NotLike "(Domain Controllers)|(Groupes)' -SearchBase $DomainPath -SearchScope 1 | ForEach-Object {
    $Name = $_.Name
    New-Item -Path "C:\Share" -Name $Name -ItemType "Directory"
    $DirPath = "C:\Share\$Name"

    #$Rule = New-Object System.Security.AccessControl.FileSystemAccessRule()
    $InnerOUs = Get-ADOrganizationalUnit -Filter * -SearchBase "OU=$($_.Name),$DomainPath"  -SearchScope 1

    $InnerOUs | ForEach-Object {
        New-Item -Path $DirPath -Name $_.Name -ItemType "Directory"

        
    }

}


