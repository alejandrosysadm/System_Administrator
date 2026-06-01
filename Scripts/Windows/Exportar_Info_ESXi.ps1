#Install-Module -Name VMware.PowerCLI -Scope CurrentUser
#Import-Module VMware.PowerCLI

# Aceptar certificados autofirmados
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null

# Conexión al servidor ESXi
Connect-VIServer -Server "192.168.1.14" -User "root" -Password "R34lturF-Esx"

# Obtener información de las VMs
$vms = Get-VM | Select-Object `
    Name,
    @{Name="OS"; Expression = { $_.Guest.OSFullName } },
    @{Name="Host"; Expression = { $_.VMHost.Name } },
    @{Name="CPU"; Expression = { $_.NumCpu } },
    @{Name="RAM (MB)"; Expression = { $_.MemoryMB } },
    @{Name="IP"; Expression = { ($_.Guest.IPAddress -join ', ') } }

# Exportar a CSV
$vms | Export-Csv -Path "C:\VMs_Info_ESXi.csv" -NoTypeInformation -Encoding UTF8

# Desconectar del servidor
Disconnect-VIServer -Confirm:$false
