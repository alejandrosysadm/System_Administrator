# Parámetros de la App Registrada
$SiteUrl     = "https://m365x12900168.sharepoint.com"  # URL completa del sitio
$TenantId    = "015f244e-f2c5-4eaa-9b65-6b018b2fc56c"              # ID del tenant (GUID)
$ClientId    = "01e03bdc-3d06-4b87-ab94-b5898e7234c2"              # ID de la app registrada
$ClientSecret = "~Sg8Q~_j2bGNFLcr3RNDOMdNgyC8GHRgJqPJHbYz"         # Secreto de la app


# Conexión correcta usando ClientId + Secret + TenantId
Connect-PnPOnline -Url $SiteUrl -ClientId $ClientId -ClientSecret $ClientSecret
# Verificar la conexión mostrando el título del sitio
Get-PnPWeb | Select-Object Title



Connect-PnPOnline m365x12900168.sharepoint.com -ClientId 01e03bdc-3d06-4b87-ab94-b5898e7234c2 -Tenant m365x12900168.onmicrosoft.com -Thumbprint 1CE9E7871F038CC5B4AE4F7A48B6B85864A30C05

 