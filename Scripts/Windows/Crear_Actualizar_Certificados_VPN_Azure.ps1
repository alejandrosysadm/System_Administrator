#Requires -Version 5.1
<#
.SYNOPSIS
    Gestor de Certificados VPN P2S de Azure - Lãberit.
.DESCRIPTION
    - Modo 1: Crea un certificado Raiz NUEVO y genera los usuarios indicados.
    - Modo 2: Carga un .pfx existente desde disco (sin instalarlo) y firma nuevos usuarios.
    - Sin Excel: define cuantos usuarios crear y sus nombres directamente en la GUI.
    - Generacion automatica de contrasena segura.
    - Seccion Azure: exporta Excel resumen con fecha de expiracion de todas las suscripciones.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#region Funciones Certificados Locales

function New-PasswordSegura {
    $chars = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%&'
    $pass  = -join ((1..16) | ForEach-Object { $chars[(Get-Random -Minimum 0 -Maximum $chars.Length)] })
    return $pass
}

function Cargar-PfxEnMemoria {
    param(
        [string]$RutaPfx,
        [string]$PasswordPfx
    )
    # PersistKeySet es necesario para que New-SelfSignedCertificate -Signer
    # pueda acceder a la clave privada. Lo eliminamos del almacen justo despues.
    $flags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet `
           -bor [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable `
           -bor [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::UserKeySet
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
        $RutaPfx, $PasswordPfx, $flags)
    if (-not $cert.HasPrivateKey) {
        throw "El archivo .pfx no contiene clave privada o la contrasena es incorrecta."
    }
    return $cert
}

function Crear-CertificadosDesdeRaiz {
    param(
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$CertRaiz,
        [string[]]$ListaUsuarios,
        [string]$Empresa,
        [int]$Anios,
        [string]$DestinoCerts,
        [System.Security.SecureString]$PasswordSecure
    )
    $creados = 0
    foreach ($usuario in $ListaUsuarios) {
        $usuario = $usuario.Trim()
        if ([string]::IsNullOrWhiteSpace($usuario)) { continue }
        $nombreUsuario = "$Empresa-$usuario"
        $certUsuario = New-SelfSignedCertificate `
            -Type            Custom `
            -DnsName         P2SChildCert `
            -KeySpec         Signature `
            -Subject         "CN=$nombreUsuario" `
            -KeyExportPolicy Exportable `
            -HashAlgorithm   sha256 `
            -KeyLength       2048 `
            -CertStoreLocation "Cert:\CurrentUser\My" `
            -Signer          $CertRaiz `
            -TextExtension   @("2.5.29.37={text}1.3.6.1.5.5.7.3.2") `
            -NotAfter        (Get-Date).AddYears($Anios)

        $nombreArchivo = $nombreUsuario -replace '[\\/:*?"<>|]', "_"
        $rutaPFX = Join-Path $DestinoCerts "$nombreArchivo.pfx"
        Export-PfxCertificate -Cert $certUsuario -FilePath $rutaPFX -Password $PasswordSecure | Out-Null

        # Eliminar del almacen temporal (lo generamos solo para exportar)
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("My","CurrentUser")
        $store.Open("ReadWrite")
        $store.Remove($certUsuario)
        $store.Close()

        $creados++
    }
    return $creados
}

function Ejecutar-ModoNuevo {
    param(
        [string]$Empresa,
        [int]$Anios,
        [string]$PasswordTexto,
        [string[]]$ListaUsuarios
    )
    $FechaExpira   = (Get-Date).AddYears($Anios).ToString("yyyy-MM-dd")
    $NombreCarpeta = "Certificados_${Empresa}_VPN_AZURE_${FechaExpira}"
    $DestinoCerts  = Join-Path $PSScriptRoot $NombreCarpeta
    New-Item -Path $DestinoCerts -ItemType Directory -Force | Out-Null

    $nombreRaiz = "$Empresa-Root_$FechaExpira"
    $certRaiz = New-SelfSignedCertificate `
        -Type            Custom `
        -KeySpec         Signature `
        -Subject         "CN=$nombreRaiz" `
        -KeyExportPolicy Exportable `
        -HashAlgorithm   sha256 `
        -KeyLength       2048 `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -KeyUsageProperty  Sign `
        -KeyUsage          CertSign `
        -NotAfter         (Get-Date).AddYears($Anios) `
        -FriendlyName     $nombreRaiz

    $PasswordSecure = ConvertTo-SecureString $PasswordTexto -AsPlainText -Force
    $creados = Crear-CertificadosDesdeRaiz -CertRaiz $certRaiz -ListaUsuarios $ListaUsuarios `
                -Empresa $Empresa -Anios $Anios -DestinoCerts $DestinoCerts -PasswordSecure $PasswordSecure

    # Exportar raiz .CER y .PFX backup
    $rutaCER = Join-Path $DestinoCerts "${Empresa}_Root.cer"
    Export-Certificate -Cert $certRaiz -FilePath $rutaCER -Type CERT | Out-Null
    $rutaRaizPFX = Join-Path $DestinoCerts "${Empresa}_Root_Backup.pfx"
    Export-PfxCertificate -Cert $certRaiz -FilePath $rutaRaizPFX -Password $PasswordSecure | Out-Null

    # Eliminar raiz del almacen (ya la tenemos exportada)
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("My","CurrentUser")
    $store.Open("ReadWrite")
    $store.Remove($certRaiz)
    $store.Close()

    $PasswordTexto | Out-File -FilePath (Join-Path $DestinoCerts "Password_Certificados.txt") -Encoding UTF8 -Force

    $certBase64 = [System.Convert]::ToBase64String($certRaiz.RawData)
    $certBase64 | Out-File -FilePath (Join-Path $DestinoCerts "${Empresa}_Base64_Azure.txt") -Encoding UTF8 -Force

    Invoke-Item $DestinoCerts
    return @{ Base64 = $certBase64; Ruta = $DestinoCerts; Creados = $creados; NombreRaiz = $nombreRaiz }
}

function Ejecutar-ModoPfx {
    param(
        [string]$Empresa,
        [int]$Anios,
        [string]$PasswordPfxTexto,
        [string]$PasswordSalidaTexto,
        [string]$RutaPfx,
        [string[]]$ListaUsuarios
    )

    # Cargar PFX en memoria sin instalarlo de forma permanente
    $certRaiz = Cargar-PfxEnMemoria -RutaPfx $RutaPfx -PasswordPfx $PasswordPfxTexto
    if ($null -eq $certRaiz) {
        throw "No se pudo cargar la clave privada del .pfx.`nVerifica que la contrasena sea correcta y que el archivo sea un certificado raiz valido."
    }

    # New-SelfSignedCertificate necesita que el signer este en el almacen.
    # Lo instalamos temporalmente, lo usamos y lo borramos al final.
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("My","CurrentUser")
    $store.Open("ReadWrite")
    $store.Add($certRaiz)
    $store.Close()

    $FechaExpira   = (Get-Date).AddYears($Anios).ToString("yyyy-MM-dd")
    $NombreCarpeta = "NuevosUsuarios_${Empresa}_${FechaExpira}"
    $DestinoCerts  = Join-Path $PSScriptRoot $NombreCarpeta
    New-Item -Path $DestinoCerts -ItemType Directory -Force | Out-Null

    try {
        $PasswordSecure = ConvertTo-SecureString $PasswordSalidaTexto -AsPlainText -Force
        $creados = Crear-CertificadosDesdeRaiz -CertRaiz $certRaiz -ListaUsuarios $ListaUsuarios `
                    -Empresa $Empresa -Anios $Anios -DestinoCerts $DestinoCerts -PasswordSecure $PasswordSecure

        $PasswordSalidaTexto | Out-File -FilePath (Join-Path $DestinoCerts "Password_Certificados.txt") -Encoding UTF8 -Force
    }
    finally {
        # Siempre eliminar la raiz del almacen aunque falle algo
        $store2 = New-Object System.Security.Cryptography.X509Certificates.X509Store("My","CurrentUser")
        $store2.Open("ReadWrite")
        $existing = $store2.Certificates | Where-Object { $_.Thumbprint -eq $certRaiz.Thumbprint }
        foreach ($c in $existing) { $store2.Remove($c) }
        $store2.Close()
    }

    Invoke-Item $DestinoCerts
    return @{ Ruta = $DestinoCerts; Creados = $creados; NombreRaiz = $certRaiz.Subject }
}

#endregion

#region Funciones Azure / Excel

function Get-CertExpirationFromBase64 {
    param([string]$Base64Cert)
    try {
        $certBytes = [System.Convert]::FromBase64String($Base64Cert)
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 (,$certBytes)
        return $cert.NotAfter
    }
    catch { return $null }
}

function Get-AllVirtualNetworkGatewaysInSub {
    # Logica identica al script standalone que funciona.
    $gateways = [System.Collections.Generic.List[object]]::new()
    try {
        $resourceGroups = Get-AzResourceGroup -ErrorAction Stop
    }
    catch {
        return $gateways
    }
    foreach ($rg in $resourceGroups) {
        try {
            $rgGws = Get-AzVirtualNetworkGateway -ResourceGroupName $rg.ResourceGroupName -ErrorAction Stop
            if ($rgGws) {
                foreach ($gw in $rgGws) { $gateways.Add($gw) }
            }
        }
        catch {}
    }
    return $gateways
}

function Write-ExcelComObject {
    param(
        [string]$Path,
        [PSCustomObject[]]$Data
    )
    try {
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        $wb = $excel.Workbooks.Add()
        $ws = $wb.Worksheets.Item(1)
        $ws.Name = "Resumen VPN"

        $headers = @("Nombre subscripcion","Nombre VPN","Fecha expiracion")
        for ($c = 0; $c -lt $headers.Count; $c++) {
            $ws.Cells.Item(1, $c+1) = $headers[$c]
            $ws.Cells.Item(1, $c+1).Font.Bold = $true
            $ws.Cells.Item(1, $c+1).Interior.Color = 4611584
            $ws.Cells.Item(1, $c+1).Font.Color     = 16777215
        }

        for ($r = 0; $r -lt $Data.Count; $r++) {
            $row = $r + 2
            $ws.Cells.Item($row, 1) = $Data[$r]."Nombre subscripcion"
            $ws.Cells.Item($row, 2) = $Data[$r]."Nombre VPN"
            $ws.Cells.Item($row, 3) = $Data[$r]."Fecha expiracion"

            $fecha = $Data[$r]."Fecha expiracion"
            if ($fecha -ne "N/A" -and $fecha -ne "No disponible" -and $fecha -notlike "*Sin P2S*") {
                try {
                    $dt   = [datetime]::ParseExact($fecha,"dd/MM/yyyy",$null)
                    $dias = ($dt - (Get-Date)).Days
                    if ($dias -lt 0) {
                        $ws.Cells.Item($row, 3).Interior.Color = 255
                        $ws.Cells.Item($row, 3).Font.Color     = 16777215
                    } elseif ($dias -le 90) {
                        $ws.Cells.Item($row, 3).Interior.Color = 49407
                    } else {
                        $ws.Cells.Item($row, 3).Font.Color = 32768
                    }
                } catch {}
            }
        }

        $ws.Columns.Item(1).AutoFit() | Out-Null
        $ws.Columns.Item(2).AutoFit() | Out-Null
        $ws.Columns.Item(3).AutoFit() | Out-Null

        $xlOpenXMLWorkbook = 51
        if (Test-Path $Path) { Remove-Item $Path -Force }
        $wb.SaveAs($Path, $xlOpenXMLWorkbook)
        $wb.Close($false)
        $excel.Quit()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null
        return $true
    } catch {
        try { $excel.Quit() } catch {}
        throw "COM Excel fallo: $_"
    }
}

function Write-ExcelCsv {
    param(
        [string]$Path,
        [PSCustomObject[]]$Data
    )
    $csvPath = $Path -replace '\.xlsx$','.csv'
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("Nombre subscripcion;Nombre VPN;Fecha expiracion")
    foreach ($row in $Data) {
        $lines.Add("$($row.'Nombre subscripcion');$($row.'Nombre VPN');$($row.'Fecha expiracion')")
    }
    $lines | Out-File -FilePath $csvPath -Encoding UTF8 -Force
    return $csvPath
}

function Exportar-ResumenVPN {
    param(
        [string]$OutputPath,
        [System.Windows.Forms.RichTextBox]$LogBox
    )
    $log = {
        param([string]$msg, [string]$color = "LightGray")
        $LogBox.SelectionColor = [System.Drawing.Color]::FromName($color)
        $LogBox.AppendText("$msg`n")
        $LogBox.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }

    & $log "[*] Comprobando modulos Az..." "Cyan"
    foreach ($mod in @("Az.Accounts","Az.Network")) {
        if (-not (Get-Module -ListAvailable -Name $mod)) {
            & $log "[!] Modulo '$mod' no encontrado. Instalalo con:" "Red"
            & $log "    Install-Module $mod -Scope CurrentUser" "Yellow"
            throw "Modulo $mod no disponible."
        }
    }
    Import-Module Az.Accounts, Az.Network -ErrorAction Stop

    & $log "[*] Verificando sesion Azure..." "Cyan"
    $context = $null
    try { $context = Get-AzContext -ErrorAction SilentlyContinue } catch {}
    if (-not ($context -and $context.Account)) {
        & $log "[*] Sin sesion activa. Abriendo login en el navegador..." "Yellow"
        Connect-AzAccount -SkipContextPopulation -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
        & $log "[+] Login completado." "Green"
    } else {
        & $log "[+] Sesion activa: $($context.Account.Id)" "Green"
    }

    & $log "[*] Obteniendo suscripciones (Lighthouse incluido)..." "Cyan"
    $subs = Get-AzSubscription -WarningAction SilentlyContinue -ErrorAction Stop |
            Where-Object { $_.State -eq "Enabled" }
    & $log "[+] Suscripciones encontradas: $($subs.Count)" "Green"

    $allResults = [System.Collections.Generic.List[PSCustomObject]]::new()
    $idx = 0

    foreach ($sub in $subs) {
        $idx++
        & $log "[$idx/$($subs.Count)] $($sub.Name)" "White"
        try {
            Set-AzContext -SubscriptionId $sub.Id -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
        }
        catch {
            & $log "    [!] Sin acceso: $_" "Gray"
            continue
        }

        $vpnGateways = Get-AllVirtualNetworkGatewaysInSub

        if ($vpnGateways.Count -eq 0) {
            & $log "    Sin VPN Gateways." "Gray"
            continue
        }

        foreach ($gw in $vpnGateways) {
            & $log "    [VPN] $($gw.Name)" "LightGray"
            $vpnCfg = $gw.VpnClientConfiguration
            if ($vpnCfg -and $vpnCfg.VpnClientRootCertificates -and
                $vpnCfg.VpnClientRootCertificates.Count -gt 0) {
                foreach ($rootCert in $vpnCfg.VpnClientRootCertificates) {
                    $fechaStr = "No disponible"
                    if ($rootCert.PublicCertData) {
                        $expDate = Get-CertExpirationFromBase64 -Base64Cert $rootCert.PublicCertData
                        if ($expDate) {
                            $fechaStr = $expDate.ToString("dd/MM/yyyy")
                            $dias = ($expDate - (Get-Date)).Days
                            $col  = if ($dias -lt 0) { "Red" } elseif ($dias -le 90) { "Yellow" } else { "Green" }
                            & $log "        Expira: $fechaStr ($dias dias)" $col
                        }
                    }
                    $allResults.Add([PSCustomObject]@{
                        "Nombre subscripcion" = $sub.Name
                        "Nombre VPN"          = $gw.Name
                        "Fecha expiracion"    = $fechaStr
                    })
                }
            } else {
                & $log "        Sin P2S configurado." "Gray"
                $allResults.Add([PSCustomObject]@{
                    "Nombre subscripcion" = $sub.Name
                    "Nombre VPN"          = $gw.Name
                    "Fecha expiracion"    = "N/A (Sin P2S)"
                })
            }
        }
    }

    if ($allResults.Count -eq 0) {
        & $log "[!] No se encontraron recursos VPN en ninguna suscripcion." "Yellow"
        return $null
    }

    & $log "[*] Generando archivo de salida..." "Cyan"
    $dataArray = $allResults.ToArray() |
        Select-Object "Nombre subscripcion", "Nombre VPN", "Fecha expiracion"

    $archivoFinal = $OutputPath
    $usoCom = $false

    $excelDisponible = ($null -ne (Get-Command "excel.exe" -ErrorAction SilentlyContinue)) -or
                       ($null -ne (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\excel.exe" -ErrorAction SilentlyContinue))

    if ($excelDisponible) {
        try {
            & $log "[*] Usando Excel COM para generar .xlsx..." "Cyan"
            Write-ExcelComObject -Path $OutputPath -Data $dataArray
            $usoCom = $true
            & $log "[+] Excel .xlsx guardado en: $OutputPath" "Green"
        } catch {
            & $log "[!] Excel COM fallo ($_), usando CSV como alternativa." "Yellow"
        }
    }

    if (-not $usoCom) {
        & $log "[*] Generando CSV (abrelo con Excel)..." "Cyan"
        $archivoFinal = Write-ExcelCsv -Path $OutputPath -Data $dataArray
        & $log "[+] CSV guardado en: $archivoFinal" "Green"
    }

    return $archivoFinal
}

#endregion

#region Interfaz Grafica

$Form = New-Object System.Windows.Forms.Form
$Form.Text            = "Gestor de Certificados P2S Azure VPN - Lãberit"
$Form.Size            = New-Object System.Drawing.Size(590, 840)
$Form.StartPosition   = "CenterScreen"
$Form.FormBorderStyle = "FixedDialog"
$Form.MaximizeBox     = $false
$Form.BackColor       = [System.Drawing.Color]::FromArgb(245, 247, 250)

$FontLabel = New-Object System.Drawing.Font("Segoe UI", 9,  [System.Drawing.FontStyle]::Bold)
$FontInput = New-Object System.Drawing.Font("Segoe UI", 10)
$FontBtn   = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

$Tabs = New-Object System.Windows.Forms.TabControl
$Tabs.Location = New-Object System.Drawing.Point(10, 10)
$Tabs.Size     = New-Object System.Drawing.Size(560, 790)
$Tabs.Font     = $FontInput
$Form.Controls.Add($Tabs)

$TabCerts = New-Object System.Windows.Forms.TabPage
$TabCerts.Text    = "  Certificados  "
$TabCerts.Padding = New-Object System.Windows.Forms.Padding(8)

$TabAzure = New-Object System.Windows.Forms.TabPage
$TabAzure.Text    = "  Azure / Excel  "
$TabAzure.Padding = New-Object System.Windows.Forms.Padding(8)

$Tabs.TabPages.Add($TabCerts)
$Tabs.TabPages.Add($TabAzure)

# ===========================================================================
# TAB 1 - CERTIFICADOS
# ===========================================================================

# Modo
$PanelModo = New-Object System.Windows.Forms.GroupBox
$PanelModo.Text     = "  Modo de Operacion  "
$PanelModo.Location = New-Object System.Drawing.Point(8, 8)
$PanelModo.Size     = New-Object System.Drawing.Size(532, 55)
$PanelModo.Font     = $FontLabel
$TabCerts.Controls.Add($PanelModo)

$RadioNuevo = New-Object System.Windows.Forms.RadioButton
$RadioNuevo.Text     = "Crear Raiz NUEVO + Usuarios"
$RadioNuevo.Location = New-Object System.Drawing.Point(10, 20)
$RadioNuevo.Size     = New-Object System.Drawing.Size(235, 22)
$RadioNuevo.Font     = $FontInput
$RadioNuevo.Checked  = $true
$PanelModo.Controls.Add($RadioNuevo)

$RadioPfx = New-Object System.Windows.Forms.RadioButton
$RadioPfx.Text     = "Cargar .pfx existente (sin instalar)"
$RadioPfx.Location = New-Object System.Drawing.Point(255, 20)
$RadioPfx.Size     = New-Object System.Drawing.Size(270, 22)
$RadioPfx.Font     = $FontInput
$PanelModo.Controls.Add($RadioPfx)

# Empresa
$LabelEmpresa = New-Object System.Windows.Forms.Label
$LabelEmpresa.Text     = "Nombre de la Empresa / Cliente:"
$LabelEmpresa.Location = New-Object System.Drawing.Point(8, 73)
$LabelEmpresa.Size     = New-Object System.Drawing.Size(280, 20)
$LabelEmpresa.Font     = $FontLabel
$TabCerts.Controls.Add($LabelEmpresa)

$InputEmpresa = New-Object System.Windows.Forms.TextBox
$InputEmpresa.Location = New-Object System.Drawing.Point(8, 95)
$InputEmpresa.Size     = New-Object System.Drawing.Size(532, 26)
$InputEmpresa.Font     = $FontInput
$TabCerts.Controls.Add($InputEmpresa)

# ---- Panel carga PFX (solo visible en modo PFX) ----------------------------
$PanelPfx = New-Object System.Windows.Forms.GroupBox
$PanelPfx.Text     = "  Certificado Raiz (.pfx)  "
$PanelPfx.Location = New-Object System.Drawing.Point(8, 130)
$PanelPfx.Size     = New-Object System.Drawing.Size(532, 100)
$PanelPfx.Font     = $FontLabel
$PanelPfx.Visible  = $false
$TabCerts.Controls.Add($PanelPfx)

$LabelPfxRuta = New-Object System.Windows.Forms.Label
$LabelPfxRuta.Text     = "Archivo .pfx del certificado raiz:"
$LabelPfxRuta.Location = New-Object System.Drawing.Point(10, 22)
$LabelPfxRuta.Size     = New-Object System.Drawing.Size(250, 18)
$LabelPfxRuta.Font     = $FontLabel
$PanelPfx.Controls.Add($LabelPfxRuta)

$InputPfxRuta = New-Object System.Windows.Forms.TextBox
$InputPfxRuta.Location    = New-Object System.Drawing.Point(10, 42)
$InputPfxRuta.Size        = New-Object System.Drawing.Size(390, 26)
$InputPfxRuta.Font        = $FontInput
$InputPfxRuta.ReadOnly    = $true
$InputPfxRuta.BackColor   = [System.Drawing.Color]::White
$PanelPfx.Controls.Add($InputPfxRuta)

$BtnExplorar = New-Object System.Windows.Forms.Button
$BtnExplorar.Text      = "Examinar..."
$BtnExplorar.Location  = New-Object System.Drawing.Point(408, 41)
$BtnExplorar.Size      = New-Object System.Drawing.Size(112, 28)
$BtnExplorar.Font      = $FontInput
$BtnExplorar.BackColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
$BtnExplorar.ForeColor = [System.Drawing.Color]::White
$BtnExplorar.Cursor    = [System.Windows.Forms.Cursors]::Hand
$PanelPfx.Controls.Add($BtnExplorar)

$LabelPfxPass = New-Object System.Windows.Forms.Label
$LabelPfxPass.Text     = "Contrasena del .pfx raiz:"
$LabelPfxPass.Location = New-Object System.Drawing.Point(10, 74)
$LabelPfxPass.Size     = New-Object System.Drawing.Size(190, 18)
$LabelPfxPass.Font     = $FontLabel
$PanelPfx.Controls.Add($LabelPfxPass)

$InputPfxPass = New-Object System.Windows.Forms.TextBox
$InputPfxPass.Location     = New-Object System.Drawing.Point(205, 71)
$InputPfxPass.Size         = New-Object System.Drawing.Size(315, 26)
$InputPfxPass.Font         = $FontInput
$InputPfxPass.PasswordChar = [char]42
$PanelPfx.Controls.Add($InputPfxPass)

# ---- Duracion (posicion dinamica segun modo) --------------------------------
$LabelDuracion = New-Object System.Windows.Forms.Label
$LabelDuracion.Text     = "Duracion en Anios (1 a 10):"
$LabelDuracion.Location = New-Object System.Drawing.Point(8, 148)
$LabelDuracion.Size     = New-Object System.Drawing.Size(210, 20)
$LabelDuracion.Font     = $FontLabel
$TabCerts.Controls.Add($LabelDuracion)

$InputDuracion = New-Object System.Windows.Forms.NumericUpDown
$InputDuracion.Location = New-Object System.Drawing.Point(8, 170)
$InputDuracion.Size     = New-Object System.Drawing.Size(100, 26)
$InputDuracion.Font     = $FontInput
$InputDuracion.Minimum  = 1
$InputDuracion.Maximum  = 10
$InputDuracion.Value    = 2
$TabCerts.Controls.Add($InputDuracion)

# ---- Contrasena salida ------------------------------------------------------
$LabelPassword = New-Object System.Windows.Forms.Label
$LabelPassword.Text     = "Contrasena para los PFX de salida:"
$LabelPassword.Location = New-Object System.Drawing.Point(8, 206)
$LabelPassword.Size     = New-Object System.Drawing.Size(280, 20)
$LabelPassword.Font     = $FontLabel
$TabCerts.Controls.Add($LabelPassword)

$InputPassword = New-Object System.Windows.Forms.TextBox
$InputPassword.Location     = New-Object System.Drawing.Point(8, 228)
$InputPassword.Size         = New-Object System.Drawing.Size(370, 26)
$InputPassword.Font         = $FontInput
$InputPassword.PasswordChar = [char]42
$TabCerts.Controls.Add($InputPassword)

$BtnGenPass = New-Object System.Windows.Forms.Button
$BtnGenPass.Text      = "Auto"
$BtnGenPass.Location  = New-Object System.Drawing.Point(388, 227)
$BtnGenPass.Size      = New-Object System.Drawing.Size(68, 28)
$BtnGenPass.Font      = $FontBtn
$BtnGenPass.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$BtnGenPass.ForeColor = [System.Drawing.Color]::White
$BtnGenPass.Cursor    = [System.Windows.Forms.Cursors]::Hand
$TabCerts.Controls.Add($BtnGenPass)

$BtnMostrarPass = New-Object System.Windows.Forms.Button
$BtnMostrarPass.Text      = "Ver"
$BtnMostrarPass.Location  = New-Object System.Drawing.Point(464, 227)
$BtnMostrarPass.Size      = New-Object System.Drawing.Size(76, 28)
$BtnMostrarPass.Font      = $FontBtn
$BtnMostrarPass.BackColor = [System.Drawing.Color]::FromArgb(108, 117, 125)
$BtnMostrarPass.ForeColor = [System.Drawing.Color]::White
$BtnMostrarPass.Cursor    = [System.Windows.Forms.Cursors]::Hand
$TabCerts.Controls.Add($BtnMostrarPass)

# ---- Usuarios ---------------------------------------------------------------
$PanelUsuarios = New-Object System.Windows.Forms.GroupBox
$PanelUsuarios.Text     = "  Usuarios a Generar  "
$PanelUsuarios.Location = New-Object System.Drawing.Point(8, 265)
$PanelUsuarios.Size     = New-Object System.Drawing.Size(532, 185)
$PanelUsuarios.Font     = $FontLabel
$TabCerts.Controls.Add($PanelUsuarios)

$LabelCantidad = New-Object System.Windows.Forms.Label
$LabelCantidad.Text     = "Cantidad:"
$LabelCantidad.Location = New-Object System.Drawing.Point(10, 26)
$LabelCantidad.Size     = New-Object System.Drawing.Size(70, 20)
$LabelCantidad.Font     = $FontLabel
$PanelUsuarios.Controls.Add($LabelCantidad)

$SpinCantidad = New-Object System.Windows.Forms.NumericUpDown
$SpinCantidad.Location = New-Object System.Drawing.Point(85, 24)
$SpinCantidad.Size     = New-Object System.Drawing.Size(65, 26)
$SpinCantidad.Font     = $FontInput
$SpinCantidad.Minimum  = 1
$SpinCantidad.Maximum  = 100
$SpinCantidad.Value    = 3
$PanelUsuarios.Controls.Add($SpinCantidad)

$BtnGenNombres = New-Object System.Windows.Forms.Button
$BtnGenNombres.Text      = "Generar Lineas"
$BtnGenNombres.Location  = New-Object System.Drawing.Point(160, 23)
$BtnGenNombres.Size      = New-Object System.Drawing.Size(125, 28)
$BtnGenNombres.Font      = $FontInput
$BtnGenNombres.BackColor = [System.Drawing.Color]::FromArgb(40, 167, 69)
$BtnGenNombres.ForeColor = [System.Drawing.Color]::White
$BtnGenNombres.Cursor    = [System.Windows.Forms.Cursors]::Hand
$PanelUsuarios.Controls.Add($BtnGenNombres)

$LabelHint = New-Object System.Windows.Forms.Label
$LabelHint.Text      = "Un nombre por linea - sin espacios ni caracteres especiales"
$LabelHint.Location  = New-Object System.Drawing.Point(10, 56)
$LabelHint.Size      = New-Object System.Drawing.Size(505, 17)
$LabelHint.Font      = New-Object System.Drawing.Font("Segoe UI", 8)
$LabelHint.ForeColor = [System.Drawing.Color]::Gray
$PanelUsuarios.Controls.Add($LabelHint)

$TextUsuarios = New-Object System.Windows.Forms.TextBox
$TextUsuarios.Location   = New-Object System.Drawing.Point(10, 75)
$TextUsuarios.Size       = New-Object System.Drawing.Size(505, 100)
$TextUsuarios.Multiline  = $true
$TextUsuarios.ScrollBars = "Vertical"
$TextUsuarios.Font       = New-Object System.Drawing.Font("Consolas", 9)
$TextUsuarios.Text       = "Usuario01`r`nUsuario02`r`nUsuario03"
$PanelUsuarios.Controls.Add($TextUsuarios)

# ---- Boton generar ----------------------------------------------------------
$BtnProcesar = New-Object System.Windows.Forms.Button
$BtnProcesar.Text      = "GENERAR CERTIFICADOS"
$BtnProcesar.Location  = New-Object System.Drawing.Point(8, 462)
$BtnProcesar.Size      = New-Object System.Drawing.Size(532, 46)
$BtnProcesar.Font      = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$BtnProcesar.BackColor = [System.Drawing.Color]::FromArgb(32, 178, 98)
$BtnProcesar.ForeColor = [System.Drawing.Color]::White
$BtnProcesar.Cursor    = [System.Windows.Forms.Cursors]::Hand
$TabCerts.Controls.Add($BtnProcesar)

# ---- Base64 (solo modo nuevo) -----------------------------------------------
$LabelBase64 = New-Object System.Windows.Forms.Label
$LabelBase64.Text     = "Codigo Base64 para Azure VPN Gateway:"
$LabelBase64.Location = New-Object System.Drawing.Point(8, 520)
$LabelBase64.Size     = New-Object System.Drawing.Size(350, 20)
$LabelBase64.Font     = $FontLabel
$TabCerts.Controls.Add($LabelBase64)

$OutputBase64 = New-Object System.Windows.Forms.TextBox
$OutputBase64.Location   = New-Object System.Drawing.Point(8, 542)
$OutputBase64.Size       = New-Object System.Drawing.Size(532, 100)
$OutputBase64.Multiline  = $true
$OutputBase64.ScrollBars = "Vertical"
$OutputBase64.ReadOnly   = $true
$OutputBase64.Font       = New-Object System.Drawing.Font("Consolas", 8)
$OutputBase64.BackColor  = [System.Drawing.Color]::FromArgb(240, 240, 240)
$TabCerts.Controls.Add($OutputBase64)

$BtnCopiar = New-Object System.Windows.Forms.Button
$BtnCopiar.Text      = "Copiar Base64 al Portapapeles"
$BtnCopiar.Location  = New-Object System.Drawing.Point(8, 652)
$BtnCopiar.Size      = New-Object System.Drawing.Size(532, 34)
$BtnCopiar.Font      = $FontInput
$BtnCopiar.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$BtnCopiar.ForeColor = [System.Drawing.Color]::White
$BtnCopiar.Cursor    = [System.Windows.Forms.Cursors]::Hand
$BtnCopiar.Enabled   = $false
$TabCerts.Controls.Add($BtnCopiar)

# ===========================================================================
# TAB 2 - AZURE / EXCEL
# ===========================================================================

$LabelAzInfo = New-Object System.Windows.Forms.Label
$LabelAzInfo.Text      = "Escanea todas las suscripciones de Azure (incluido Lighthouse), localiza las VPN Gateways con certificados P2S y exporta un Excel con 3 columnas: Nombre subscripcion, Nombre VPN, Fecha expiracion."
$LabelAzInfo.Location  = New-Object System.Drawing.Point(8, 12)
$LabelAzInfo.Size      = New-Object System.Drawing.Size(532, 50)
$LabelAzInfo.Font      = New-Object System.Drawing.Font("Segoe UI", 9)
$LabelAzInfo.ForeColor = [System.Drawing.Color]::FromArgb(60, 60, 60)
$TabAzure.Controls.Add($LabelAzInfo)

$LabelReqs = New-Object System.Windows.Forms.Label
$LabelReqs.Text      = "Requiere modulos: Az.Accounts, Az.Network (ImportExcel NO requerido)"
$LabelReqs.Location  = New-Object System.Drawing.Point(8, 65)
$LabelReqs.Size      = New-Object System.Drawing.Size(532, 18)
$LabelReqs.Font      = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Italic)
$LabelReqs.ForeColor = [System.Drawing.Color]::Gray
$TabAzure.Controls.Add($LabelReqs)

$LabelRutaExcel = New-Object System.Windows.Forms.Label
$LabelRutaExcel.Text     = "Ruta del Excel de salida:"
$LabelRutaExcel.Location = New-Object System.Drawing.Point(8, 92)
$LabelRutaExcel.Size     = New-Object System.Drawing.Size(200, 20)
$LabelRutaExcel.Font     = $FontLabel
$TabAzure.Controls.Add($LabelRutaExcel)

$InputRutaExcel = New-Object System.Windows.Forms.TextBox
$InputRutaExcel.Location = New-Object System.Drawing.Point(8, 114)
$InputRutaExcel.Size     = New-Object System.Drawing.Size(420, 26)
$InputRutaExcel.Font     = $FontInput
$InputRutaExcel.Text     = Join-Path $PSScriptRoot "CheckVPN.xlsx"
$TabAzure.Controls.Add($InputRutaExcel)

$BtnExaminarExcel = New-Object System.Windows.Forms.Button
$BtnExaminarExcel.Text      = "..."
$BtnExaminarExcel.Location  = New-Object System.Drawing.Point(436, 113)
$BtnExaminarExcel.Size      = New-Object System.Drawing.Size(94, 28)
$BtnExaminarExcel.Font      = $FontInput
$BtnExaminarExcel.BackColor = [System.Drawing.Color]::FromArgb(200, 200, 200)
$BtnExaminarExcel.Cursor    = [System.Windows.Forms.Cursors]::Hand
$TabAzure.Controls.Add($BtnExaminarExcel)

$BtnExportar = New-Object System.Windows.Forms.Button
$BtnExportar.Text      = "CONECTAR A AZURE Y EXPORTAR EXCEL"
$BtnExportar.Location  = New-Object System.Drawing.Point(8, 152)
$BtnExportar.Size      = New-Object System.Drawing.Size(532, 46)
$BtnExportar.Font      = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$BtnExportar.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$BtnExportar.ForeColor = [System.Drawing.Color]::White
$BtnExportar.Cursor    = [System.Windows.Forms.Cursors]::Hand
$TabAzure.Controls.Add($BtnExportar)

$LabelLog = New-Object System.Windows.Forms.Label
$LabelLog.Text     = "Progreso:"
$LabelLog.Location = New-Object System.Drawing.Point(8, 212)
$LabelLog.Size     = New-Object System.Drawing.Size(100, 20)
$LabelLog.Font     = $FontLabel
$TabAzure.Controls.Add($LabelLog)

$LogBox = New-Object System.Windows.Forms.RichTextBox
$LogBox.Location   = New-Object System.Drawing.Point(8, 234)
$LogBox.Size       = New-Object System.Drawing.Size(532, 450)
$LogBox.Font       = New-Object System.Drawing.Font("Consolas", 8.5)
$LogBox.BackColor  = [System.Drawing.Color]::FromArgb(20, 20, 30)
$LogBox.ForeColor  = [System.Drawing.Color]::LightGray
$LogBox.ReadOnly   = $true
$LogBox.ScrollBars = "Vertical"
$TabAzure.Controls.Add($LogBox)

$BtnAbrirExcel = New-Object System.Windows.Forms.Button
$BtnAbrirExcel.Text      = "Abrir Excel Generado"
$BtnAbrirExcel.Location  = New-Object System.Drawing.Point(8, 694)
$BtnAbrirExcel.Size      = New-Object System.Drawing.Size(532, 34)
$BtnAbrirExcel.Font      = $FontInput
$BtnAbrirExcel.BackColor = [System.Drawing.Color]::FromArgb(40, 167, 69)
$BtnAbrirExcel.ForeColor = [System.Drawing.Color]::White
$BtnAbrirExcel.Cursor    = [System.Windows.Forms.Cursors]::Hand
$BtnAbrirExcel.Enabled   = $false
$TabAzure.Controls.Add($BtnAbrirExcel)

#endregion

#region Eventos

# ---- Cambio de modo ---------------------------------------------------------
$RadioPfx.Add_CheckedChanged({
    if ($RadioPfx.Checked) {
        $PanelPfx.Visible      = $true
        $LabelDuracion.Top     = 240
        $InputDuracion.Top     = 262
        $LabelPassword.Top     = 298
        $InputPassword.Top     = 320
        $BtnGenPass.Top        = 319
        $BtnMostrarPass.Top    = 319
        $PanelUsuarios.Top     = 357
        $BtnProcesar.Top       = 554
        $LabelBase64.Visible   = $false
        $OutputBase64.Visible  = $false
        $BtnCopiar.Visible     = $false
    }
})

$RadioNuevo.Add_CheckedChanged({
    if ($RadioNuevo.Checked) {
        $PanelPfx.Visible      = $false
        $LabelDuracion.Top     = 148
        $InputDuracion.Top     = 170
        $LabelPassword.Top     = 206
        $InputPassword.Top     = 228
        $BtnGenPass.Top        = 227
        $BtnMostrarPass.Top    = 227
        $PanelUsuarios.Top     = 265
        $BtnProcesar.Top       = 462
        $LabelBase64.Visible   = $true
        $OutputBase64.Visible  = $true
        $BtnCopiar.Visible     = $true
    }
})

# ---- Explorador de archivos .pfx --------------------------------------------
$BtnExplorar.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title  = "Seleccionar certificado raiz (.pfx)"
    $dlg.Filter = "Certificado PFX|*.pfx|Todos los archivos|*.*"
    $dlg.InitialDirectory = $PSScriptRoot
    if ($dlg.ShowDialog() -eq "OK") {
        $InputPfxRuta.Text = $dlg.FileName
    }
})

# ---- Contrasena salida ------------------------------------------------------
$BtnGenPass.Add_Click({
    $pass = New-PasswordSegura
    $InputPassword.PasswordChar = [char]0
    $InputPassword.Text = $pass
    [System.Windows.Forms.MessageBox]::Show(
        "Contrasena generada y visible en el campo.`nSe guardara en Password_Certificados.txt junto a los certificados.",
        "Contrasena Generada",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information)
})

$BtnMostrarPass.Add_Click({
    if ($InputPassword.PasswordChar -eq [char]42) {
        $InputPassword.PasswordChar = [char]0
    } else {
        $InputPassword.PasswordChar = [char]42
    }
})

# ---- Generar lineas de usuario ----------------------------------------------
$BtnGenNombres.Add_Click({
    $n = [int]$SpinCantidad.Value
    $lineas = (1..$n) | ForEach-Object { "Usuario{0:D2}" -f $_ }
    $TextUsuarios.Text = $lineas -join "`r`n"
})

# ---- Boton principal --------------------------------------------------------
$BtnProcesar.Add_Click({
    $empresa  = $InputEmpresa.Text.Trim()
    $password = $InputPassword.Text

    if ([string]::IsNullOrWhiteSpace($empresa)) {
        [System.Windows.Forms.MessageBox]::Show("El campo Empresa no puede estar vacio.", "Campo requerido", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    if ([string]::IsNullOrWhiteSpace($password)) {
        [System.Windows.Forms.MessageBox]::Show("Introduce o genera una contrasena para los PFX de salida.", "Campo requerido", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    $listaUsuarios = $TextUsuarios.Text -split "`r`n|`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($listaUsuarios.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Anade al menos un nombre de usuario.", "Sin usuarios", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    if ($RadioPfx.Checked) {
        if ([string]::IsNullOrWhiteSpace($InputPfxRuta.Text) -or -not (Test-Path $InputPfxRuta.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Selecciona un archivo .pfx valido con el boton Examinar.", "Archivo no seleccionado", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
        if ([string]::IsNullOrWhiteSpace($InputPfxPass.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Introduce la contrasena del .pfx raiz.", "Contrasena requerida", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
    }

    $BtnProcesar.Enabled   = $false
    $BtnProcesar.Text      = "Procesando... Espera..."
    $BtnProcesar.BackColor = [System.Drawing.Color]::DarkGray

    try {
        if ($RadioNuevo.Checked) {
            $resultado = Ejecutar-ModoNuevo `
                -Empresa $empresa -Anios ([int]$InputDuracion.Value) `
                -PasswordTexto $password -ListaUsuarios $listaUsuarios
            $OutputBase64.Text = $resultado.Base64
            $BtnCopiar.Enabled = $true
            [System.Windows.Forms.MessageBox]::Show(
                "Todo listo!`n`nRaiz: $($resultado.NombreRaiz)`nUsuarios generados: $($resultado.Creados)`nCarpeta: $($resultado.Ruta)`n`nEl .pfx de backup de la raiz esta en la misma carpeta.",
                "Exito", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        } else {
            $resultado = Ejecutar-ModoPfx `
                -Empresa           $empresa `
                -Anios             ([int]$InputDuracion.Value) `
                -PasswordPfxTexto  $InputPfxPass.Text `
                -PasswordSalidaTexto $password `
                -RutaPfx           $InputPfxRuta.Text `
                -ListaUsuarios     $listaUsuarios
            [System.Windows.Forms.MessageBox]::Show(
                "Usuarios generados correctamente!`n`nRaiz usada: $($resultado.NombreRaiz)`nUsuarios generados: $($resultado.Creados)`nCarpeta: $($resultado.Ruta)`n`nEl certificado raiz NO ha quedado instalado en este equipo.",
                "Exito", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error:`n$_", "Error Tecnico", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }

    $BtnProcesar.Enabled   = $true
    $BtnProcesar.Text      = "GENERAR CERTIFICADOS"
    $BtnProcesar.BackColor = [System.Drawing.Color]::FromArgb(32, 178, 98)
})

$BtnCopiar.Add_Click({
    if (-not [string]::IsNullOrEmpty($OutputBase64.Text)) {
        [System.Windows.Forms.Clipboard]::SetText($OutputBase64.Text)
        [System.Windows.Forms.MessageBox]::Show("Copiado! Listo para pegar en Azure VPN Gateway.", "Copiado", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
})

# ---- Tab Azure --------------------------------------------------------------
$script:ExcelGenerado = $null

$BtnExaminarExcel.Add_Click({
    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Filter   = "Excel|*.xlsx"
    $dlg.FileName = "CheckVPN.xlsx"
    $dlg.InitialDirectory = $PSScriptRoot
    if ($dlg.ShowDialog() -eq "OK") { $InputRutaExcel.Text = $dlg.FileName }
})

$BtnExportar.Add_Click({
    $rutaExcel = $InputRutaExcel.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($rutaExcel)) {
        [System.Windows.Forms.MessageBox]::Show("Indica la ruta del Excel de salida.", "Ruta requerida", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    $LogBox.Clear()
    $BtnExportar.Enabled   = $false
    $BtnExportar.Text      = "Procesando Azure..."
    $BtnExportar.BackColor = [System.Drawing.Color]::DarkGray
    $BtnAbrirExcel.Enabled = $false
    $script:ExcelGenerado  = $null

    # Cola de mensajes compartida entre el runspace y la UI
    $script:LogQueue    = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
    $script:JobDone     = $false
    $script:JobResult   = $null
    $script:JobError    = $null

    # Capturar funciones necesarias como strings para pasarlas al runspace
    $fnGateway  = ${function:Get-AllVirtualNetworkGatewaysInSub}.ToString()
    $fnCertExp  = ${function:Get-CertExpirationFromBase64}.ToString()
    $fnExcelCom = ${function:Write-ExcelComObject}.ToString()
    $fnExcelCsv = ${function:Write-ExcelCsv}.ToString()

    $rutaParam  = $rutaExcel
    $queueRef   = $script:LogQueue

    # Runspace: ejecuta todo Azure en background sin bloquear la UI
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = "STA"
    $rs.ThreadOptions  = "ReuseThread"
    $rs.Open()

    $ps = [powershell]::Create()
    $ps.Runspace = $rs

    $ps.AddScript({
        param($OutputPath, $Queue, $fnGW, $fnCert, $fnExCom, $fnExCsv)

        function LogQ {
            param([string]$msg, [string]$color = "LightGray")
            $Queue.Enqueue("$color|$msg")
        }

        # Recrear funciones en este runspace
        Invoke-Expression "function Get-AllVirtualNetworkGatewaysInSub { $fnGW }"
        Invoke-Expression "function Get-CertExpirationFromBase64 { $fnCert }"
        Invoke-Expression "function Write-ExcelComObject { $fnExCom }"
        Invoke-Expression "function Write-ExcelCsv { $fnExCsv }"

        try {
            Import-Module Az.Accounts, Az.Network -ErrorAction Stop

            LogQ "[*] Verificando sesion Azure..." "Cyan"
            $context = $null
            try { $context = Get-AzContext -ErrorAction SilentlyContinue } catch {}
            if (-not ($context -and $context.Account)) {
                LogQ "[*] Sin sesion activa. Abriendo login en el navegador..." "Yellow"
                Connect-AzAccount -SkipContextPopulation -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
                LogQ "[+] Login completado." "Green"
            } else {
                LogQ "[+] Sesion activa: $($context.Account.Id)" "Green"
            }

            LogQ "[*] Obteniendo suscripciones (Lighthouse incluido)..." "Cyan"
            $subs = Get-AzSubscription -WarningAction SilentlyContinue -ErrorAction Stop |
                    Where-Object { $_.State -eq "Enabled" }
            LogQ "[+] Suscripciones encontradas: $($subs.Count)" "Green"

            $allResults = [System.Collections.Generic.List[PSCustomObject]]::new()
            $idx = 0

            foreach ($sub in $subs) {
                $idx++
                LogQ "[$idx/$($subs.Count)] $($sub.Name)" "White"
                try {
                    Set-AzContext -SubscriptionId $sub.Id -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
                }
                catch {
                    LogQ "    [!] Sin acceso: $_" "Gray"
                    continue
                }

                $vpnGateways = Get-AllVirtualNetworkGatewaysInSub

                if ($vpnGateways.Count -eq 0) {
                    LogQ "    Sin VPN Gateways." "Gray"
                    continue
                }

                foreach ($gw in $vpnGateways) {
                    LogQ "    [VPN] $($gw.Name)" "LightGray"
                    $vpnCfg = $gw.VpnClientConfiguration
                    if ($vpnCfg -and $vpnCfg.VpnClientRootCertificates -and
                        $vpnCfg.VpnClientRootCertificates.Count -gt 0) {
                        foreach ($rootCert in $vpnCfg.VpnClientRootCertificates) {
                            $fechaStr = "No disponible"
                            if ($rootCert.PublicCertData) {
                                $expDate = Get-CertExpirationFromBase64 -Base64Cert $rootCert.PublicCertData
                                if ($expDate) {
                                    $fechaStr = $expDate.ToString("dd/MM/yyyy")
                                    $dias = ($expDate - (Get-Date)).Days
                                    $col  = if ($dias -lt 0) { "Red" } elseif ($dias -le 90) { "Yellow" } else { "Green" }
                                    LogQ "        Expira: $fechaStr ($dias dias)" $col
                                }
                            }
                            $allResults.Add([PSCustomObject]@{
                                "Nombre subscripcion" = $sub.Name
                                "Nombre VPN"          = $gw.Name
                                "Fecha expiracion"    = $fechaStr
                            })
                        }
                    } else {
                        LogQ "        Sin P2S configurado." "Gray"
                        $allResults.Add([PSCustomObject]@{
                            "Nombre subscripcion" = $sub.Name
                            "Nombre VPN"          = $gw.Name
                            "Fecha expiracion"    = "N/A (Sin P2S)"
                        })
                    }
                }
            }

            if ($allResults.Count -eq 0) {
                LogQ "[!] No se encontraron recursos VPN." "Yellow"
                return $null
            }

            LogQ "[*] Generando archivo de salida..." "Cyan"
            $dataArray = $allResults.ToArray() |
                Select-Object "Nombre subscripcion", "Nombre VPN", "Fecha expiracion"

            $archivoFinal = $OutputPath
            $usoCom = $false

            $excelDisponible = ($null -ne (Get-Command "excel.exe" -ErrorAction SilentlyContinue)) -or
                               ($null -ne (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\excel.exe" -ErrorAction SilentlyContinue))

            if ($excelDisponible) {
                try {
                    LogQ "[*] Usando Excel COM para generar .xlsx..." "Cyan"
                    Write-ExcelComObject -Path $OutputPath -Data $dataArray
                    $usoCom = $true
                    LogQ "[+] Excel .xlsx guardado en: $OutputPath" "Green"
                } catch {
                    LogQ "[!] Excel COM fallo ($_), usando CSV." "Yellow"
                }
            }

            if (-not $usoCom) {
                LogQ "[*] Generando CSV..." "Cyan"
                $archivoFinal = Write-ExcelCsv -Path $OutputPath -Data $dataArray
                LogQ "[+] CSV guardado en: $archivoFinal" "Green"
            }

            return $archivoFinal

        } catch {
            LogQ "[ERROR] $_" "Red"
            return "ERROR:$_"
        }

    }).AddParameters(@{
        OutputPath = $rutaParam
        Queue      = $queueRef
        fnGW       = $fnGateway
        fnCert     = $fnCertExp
        fnExCom    = $fnExcelCom
        fnExCsv    = $fnExcelCsv
    }) | Out-Null

    $script:AsyncHandle = $ps.BeginInvoke()

    # Timer que drena la cola de log y detecta cuando termina el job
    $script:PollTimer = New-Object System.Windows.Forms.Timer
    $script:PollTimer.Interval = 200

    $script:PollTimer.Add_Tick({
        # Volcar mensajes del runspace al RichTextBox
        $msg = $null
        while ($script:LogQueue.TryDequeue([ref]$msg)) {
            $parts = $msg -split '\|', 2
            $color = $parts[0]
            $text  = if ($parts.Count -gt 1) { $parts[1] } else { $msg }
            try {
                $LogBox.SelectionColor = [System.Drawing.Color]::FromName($color)
            } catch {
                $LogBox.SelectionColor = [System.Drawing.Color]::LightGray
            }
            $LogBox.AppendText("$text`n")
            $LogBox.ScrollToCaret()
        }

        # Comprobar si el runspace termino
        if ($script:AsyncHandle.IsCompleted) {
            $script:PollTimer.Stop()
            $script:PollTimer.Dispose()

            # Vaciar cola restante
            $msg2 = $null
            while ($script:LogQueue.TryDequeue([ref]$msg2)) {
                $parts = $msg2 -split '\|', 2
                $color = $parts[0]
                $text  = if ($parts.Count -gt 1) { $parts[1] } else { $msg2 }
                try { $LogBox.SelectionColor = [System.Drawing.Color]::FromName($color) } catch {}
                $LogBox.AppendText("$text`n")
                $LogBox.ScrollToCaret()
            }

            try {
                $resultado = $ps.EndInvoke($script:AsyncHandle)
                $ps.Dispose()
                $rs.Dispose()

                $errores = $ps.Streams.Error
                if ($errores -and $errores.Count -gt 0) {
                    $LogBox.SelectionColor = [System.Drawing.Color]::Red
                    $LogBox.AppendText("[STREAM ERROR] $($errores[0])`n")
                }

                $archivoFinal = $resultado | Select-Object -Last 1

                if ($archivoFinal -and -not $archivoFinal.ToString().StartsWith("ERROR:") -and (Test-Path $archivoFinal)) {
                    $script:ExcelGenerado  = $archivoFinal
                    $BtnAbrirExcel.Enabled = $true
                    [System.Windows.Forms.MessageBox]::Show(
                        "Archivo generado correctamente en:`n$archivoFinal",
                        "Exportacion Completada",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Information)
                } else {
                    [System.Windows.Forms.MessageBox]::Show(
                        "El proceso termino pero no se genero ningun archivo.",
                        "Aviso",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Warning)
                }
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Error al finalizar:`n$_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            }

            $BtnExportar.Enabled   = $true
            $BtnExportar.Text      = "CONECTAR A AZURE Y EXPORTAR EXCEL"
            $BtnExportar.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
        }
    })

    $script:PollTimer.Start()
})

$BtnAbrirExcel.Add_Click({
    if ($script:ExcelGenerado -and (Test-Path $script:ExcelGenerado)) {
        Invoke-Item $script:ExcelGenerado
    }
})

#endregion

$Form.ShowDialog() | Out-Null
