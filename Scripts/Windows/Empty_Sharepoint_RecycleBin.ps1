# Parámetros de la App Registrada
$SiteUrl     = ""  # URL completa del sitio
$TenantId    = ""              # ID del tenant (GUID)
$ClientId    = ""              # ID de la app registrada
$ClientSecret = ""         # Secreto de la app


# Conexión correcta usando ClientId + Secret + TenantId
Connect-PnPOnline -Url $SiteUrl -ClientId $ClientId -ClientSecret $ClientSecret
# Verificar la conexión mostrando el título del sitio
Get-PnPWeb | Select-Object Title



Connect-PnPOnline m365x12900168.sharepoint.com -ClientId 01e03bdc-3d06-4b87-ab94-b5898e7234c2 -Tenant m365x12900168.onmicrosoft.com -Thumbprint 1CE9E7871F038CC5B4AE4F7A48B6B85864A30C05

 
