<#$computer_name = Get-WMIObject Win32_ComputerSystem | Select-Object -ExpandProperty name

if (!$args[0] -eq "") {
    Rename-Computer -ComputerName $computer_name -NewName $args[0] -LocalCredential -Restart
}
#>

$all_infos = {
    ip = "Enter the ip address of this server: ";
    mask = "Enter the mask of the network: ";
    gateway = "Enter the ip address of this server: ";
    name = "Enter the ip address of this server: ";
}

$res = New-Object string[] 4

foreach ($info in $all_infos) {
    Read-Host -Prompt $info
}