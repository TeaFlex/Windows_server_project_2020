$computer_name = Get-WMIObject Win32_ComputerSystem | Select-Object -ExpandProperty name

if (!$args[0] -eq "") {
    Rename-Computer -ComputerName $computer_name -NewName $args[0] -LocalCredential -Restart
}

