#!/bin/bash
set -e

# =========================================================
# Bootstrap Sysadmin Ninja - Raspberry / Debian / Ubuntu
# Instala utilidades esenciales en segundos
# =========================================================

if [ "$EUID" -ne 0 ]; then
  echo "🚨 Ejecuta este script como root"
  exit 1
fi

echo "🚀 Actualizando repositorios..."
apt update -y
apt upgrade -y

echo "📦 Instalando herramientas esenciales..."
apt install -y \
  btop neofetch fastfetch bat duf eza tldr ncdu \
  vnstat unzip curl wget

# =========================================================
# Configuración de bashrc para el usuario que ejecuta sudo
# =========================================================
USER_HOME=$(eval echo "~$SUDO_USER")
BASHRC="$USER_HOME/.bashrc"

echo "🔧 Configurando aliases y neofetch en bashrc..."
cat << 'EOF' >> $BASHRC

# Mostrar info del sistema al abrir terminal
if [ -t 1 ]; then
    fastfetch
fi

# Aliases útiles
alias ll='eza -lah --icons'
alias lt='eza --tree --level=2'
alias df='duf'
alias cat='batcat'
alias find='rg'
EOF

chown $SUDO_USER:$SUDO_USER $BASHRC

# =========================================================
# Inicializar vnstat para histórico de red
# =========================================================
echo "🌐 Inicializando vnstat..."
systemctl enable vnstat
systemctl start vnstat

echo "✅ Bootstrap completado! Reinicia la terminal para ver cambios."
