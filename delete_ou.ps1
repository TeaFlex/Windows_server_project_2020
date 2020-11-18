Get-ADOrganizationalUnit -Filter 'Name -NotLike "Domain Controllers"' | ForEach-Object {
    Remove-ADOrganizationalUnit -Identity $_.DistinguishedName -Recursive -Confirm:$False
}

Get-ADGroup -Filter '(Name -Like "GG_*") -Or (Name -Like "GL_*")' | ForEach-Object {
    Remove-ADGroup -Identity $_.DistinguishedName -Confirm:$False
}