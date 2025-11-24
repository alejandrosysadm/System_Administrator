Get-PSDrive -PSProvider FileSystem | Select-Object Name, Used, Free | Export-Csv "C:\Users\Public\Discos.csv" -NoTypeInformation
