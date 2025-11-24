# Copiar carpetas importantes a una ruta de backup
$source = "C:\Datos"
$destination = "D:\Backups\$(Get-Date -Format yyyy-MM-dd)"
Copy-Item $source -Destination $destination -Recurse -Force