Import-Csv -Delimiter ';' -Path c:\data_employees\employees.csv | ForEach-Object {
    Write-Host($_)
    #add adding-AD-user command here after creating AD
}