# Script: Listar-VMs-Azure.ps1
# Descripción: Lista todas las VMs de Azure y exporta un CSV
# Autor: Alejandro Ferrándiz

# Instalar módulo Az si no está presente
if (-not (Get-Module -ListAvailable -Name Az)) {
    Write-Host "Instalando módulo Az..."
    Install-Module -Name Az -AllowClobber -Scope CurrentUser -Force
}

# Importar módulo
Import-Module Az

# Conectarse a Azure
Connect-AzAccount

# Obtener VMs
$vms = Get-AzVM | Select-Object Name, ResourceGroupName, Location, ProvisioningState

# Mostrar en pantalla
$vms | Format-Table -AutoSize

# Exportar a CSV
$csvPath = "$env:USERPROFILE\Desktop\AzureVMs.csv"
$vms | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

Write-Host "CSV generado en: $csvPath"
