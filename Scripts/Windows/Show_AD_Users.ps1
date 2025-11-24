Get-ADUser -Filter * -Property DisplayName, LastLogonDate | 
Select-Object DisplayName, LastLogonDate | Export-Csv "C:\Users\Public\ADUsers.csv" -NoTypeInformation
