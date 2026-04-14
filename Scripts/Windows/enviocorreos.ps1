# Configuracion
$cuentaRemitente = "remitente@correo.com"
$destinatario = "destinatario@correo.com"

# Lista de clientes
$clientes = @(
    "Cliente1", "Cliente2"
)

# Cuerpo del mensaje en HTML (Sin acentos)
$cuerpo = @"
<html>
<body style='font-family: Calibri, sans-serif;'>
<p>Cuerpo del mensaje</p>
</body>
</html>
"@

# Inicializar Outlook
$outlook = New-Object -ComObject Outlook.Application
$namespace = $outlook.GetNamespace("MAPI")

# Buscar la cuenta especifica
$account = $outlook.Session.Accounts | Where-Object { $_.SmtpAddress -eq $cuentaRemitente }

if ($null -eq $account) {
    Write-Error "No se encontro la cuenta $cuentaRemitente configurada en Outlook."
    return
}

foreach ($cliente in $clientes) {
    $mail = $outlook.CreateItem(0)
    $mail.SendUsingAccount = $account  # Forzar el uso de la cuenta especifica
    $mail.To = $destinatario
    $mail.Subject = "Asunto | $cliente"
    $mail.HTMLBody = $cuerpo
    
    # IMPORTANTE: Cambia entre .Display() por .Send() para enviar los correos y visualizarlos como borradores
    $mail.Send() 
    
    Write-Host "Procesado: $cliente con la cuenta $($account.SmtpAddress)"
}