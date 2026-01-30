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
  btop neofetch fastfetch bat duf eza fzf tldr ncdu \
  vnstat unzip curl wget build-essential libpcre3-dev \
  libsqlite3-dev libncursesw5-dev libreadline-dev libbz2-dev zlib1g-dev \
  libunistring-dev libcurl4-openssl-dev pkg-config

# =========================================================
# Instalar lnav desde fuente (para ARM64 / ARMHF)
# =========================================================
echo "📜 Instalando lnav..."
TMP_DIR=$(mktemp -d)
cd $TMP_DIR

# Descargar fuente
curl -LO https://github.com/tstack/lnav/releases/download/v0.13.2/lnav-0.13.2.tar.gz
tar xvf lnav-0.13.2.tar.gz
cd lnav-0.13.2

# Compilar e instalar
./configure
make
make install

cd ~
rm -rf $TMP_DIR

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
alias cat='bat'
alias fcd='cd $(find . -type d | fzf)'
alias fedit='nano $(fzf)'
EOF

chown $SUDO_USER:$SUDO_USER $BASHRC

# =========================================================
# Inicializar vnstat para histórico de red
# =========================================================
echo "🌐 Inicializando vnstat..."
systemctl enable vnstat
systemctl start vnstat

echo "✅ Bootstrap completado! Reinicia la terminal para ver cambios."
