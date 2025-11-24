Get-EventLog -LogName System -EntryType Error, Warning -Newest 50 | Export-Csv "C:\Users\Public\Eventos.csv" -NoTypeInformation
