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

# =========================================================
# Mostrar info del sistema y mini-manual de comandos
# =========================================================
if [ -t 1 ]; then
    fastfetch
    echo ""
    echo -e "\e[1;32m🚀 Comandos instalados y su uso rápido:\e[0m"
    echo -e "\e[1;36mbtop\e[0m       → Monitor de CPU, RAM, red y discos."
    echo -e "\e[1;36mneofetch\e[0m   → Información del sistema."
    echo -e "\e[1;36mfastfetch\e[0m  → Neofetch rápido y moderno."
    echo -e "\e[1;36mbat\e[0m        → Cat con colores y resaltado de sinta>
    echo -e "\e[1;36mduf\e[0m        → Visualización bonita de discos."
    echo -e "\e[1;36meza\e[0m        → Listado de archivos con colores y ár>
    echo -e "\e[1;36mfzf\e[0m        → Selector interactivo de archivos."
    echo -e "\e[1;36mtldr\e[0m       → Versiones resumidas de comandos."
    echo -e "\e[1;36mncdu\e[0m       → Analizador de uso de disco."
    echo -e "\e[1;36mvnstat\e[0m     → Estadísticas de red."
    echo -e "\e[1;36mlnav\e[0m       → Visualización de logs en tiempo real>
    echo ""
    echo -e "\e[1;33m💡 Aliases útiles:\e[0m"
    echo -e "ll    → eza -lah --icons"
    echo -e "lt    → eza --tree --level=2"
    echo -e "df    → duf"
    echo -e "cat   → bat"
    echo -e "fcd   → cd $(find . -type d | fzf)"
    echo -e "fedit → nano $(fzf)"
    echo ""
    echo -e "\e[1;32m✅ Listo! Usa estos comandos y aliases para aprovechar>
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
