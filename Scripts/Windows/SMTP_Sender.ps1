$SMTPServer = "smtp.office365.com or your smtp server"
$SMTPPort = 587
$Username = "user@domain.com"
$Password = "YourPassOrAppPass"

$SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential($Username, $SecurePassword)

Send-MailMessage -From $Username -To "destination@domain.com" -Subject "Test SMTP" -Body "This is a SMTP test mail" -SmtpServer $SMTPServer -Port $SMTPPort -UseSsl -Credential $Cred
