Function Add-ShareDirectory($OUPath, $DirectoryPath) {
    Get-ADOrganizationalUnit -Filter 'Name -NotLike "Domain Controllers"' -SearchBase $Path -SearchScope 1 | ForEach-Object {
        $Name = $_.Name
        New-Item -Path $DirectoryPath -Name $Name -ItemType "Directory"
        Add-ShareDirectory("OU=$Name,$OUPath", "$DirectoryPath\$Name")
    }
}


New-Item -Path "C:\" -Name "Share" -ItemType "Directory"
Add-ShareDirectory (Get-ADDomain).DistinguishedName "C:\Share"
