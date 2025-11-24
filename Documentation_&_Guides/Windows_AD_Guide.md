Windows Active Directory Guide
Overview:
Practical guide for managing users, groups, and permissions in Active Directory using PowerShell.

User Management:
•	- Create a new user:
New-ADUser -Name "John Doe" -SamAccountName "jdoe" -UserPrincipalName "jdoe@domain.com" -AccountPassword (ConvertTo-SecureString "Password123!" -AsPlainText -Force) -Enabled $true
•	- Modify a user:
Set-ADUser -Identity "jdoe" -Title "IT Administrator"
•	- Disable or delete a user:
Disable-ADAccount -Identity "jdoe"
Remove-ADUser -Identity "jdoe"

Group Management:
•	- Create a new group:
New-ADGroup -Name "IT-Admins" -GroupScope Global -PassThru
•	- Add users to a group:
Add-ADGroupMember -Identity "IT-Admins" -Members "jdoe"
•	- Remove users from a group:
Remove-ADGroupMember -Identity "IT-Admins" -Members "jdoe" -Confirm:$false
