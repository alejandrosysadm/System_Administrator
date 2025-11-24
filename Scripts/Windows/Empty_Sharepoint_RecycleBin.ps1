# Parámetros de la App Registrada
$SiteUrl     = ""  # URL completa del sitio
$TenantId    = ""              # ID del tenant (GUID)
$ClientId    = ""              # ID de la app registrada
$ClientSecret = ""         # Secreto de la app


# Conexión correcta usando ClientId + Secret + TenantId
Connect-PnPOnline -Url $SiteUrl -ClientId $ClientId -ClientSecret $ClientSecret
# Verificar la conexión mostrando el título del sitio
Get-PnPWeb | Select-Object Title



Connect-PnPOnline {} -ClientId {} -Tenant {} -Thumbprint {}

 
