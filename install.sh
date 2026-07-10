#!/bin/bash

REPO_DIR="$( cd "$( dirname "${BASH_SOURCE}" )" &> /dev/null && pwd )"
cd "$REPO_DIR"

# leer version local (si no existe asume v0.0.0)
VERSION_LOCAL="0.0.0"
if [ -f "VERSION" ]; then
    VERSION_LOCAL=$(cat VERSION | tr -d '\r' | xargs)
fi

echo "==========================================="
echo "            Mintdows v$VERSION_LOCAL"
echo "             Por ILikeCats                 "
echo "==========================================="

echo "==========================================="
echo "    Iniciando instalación de Mintdows...   "
echo "==========================================="

# actualizar el sistema base
echo "[1/5] Actualizando repositorios..."
sudo apt update && sudo apt upgrade -y

# instalar herramientas
echo "[2/5] Instalando herramientas del sistema..."
sudo apt install -y git flatpak curl wget

# configurar flathub
echo "[3/5] Configurando repositorios de aplicaciones..."
flatpak remote-add --if-not-exists flathub https://flathub.org

# instalar utilidades del sistema
echo "[4/5] Instalando aplicaciones desde FlatHub..."

sudo apt purge -y firefox firefox-locale-*
sudo apt autoremove -y

flatpak install flathub \
    org.localsend.localsend_app \
    org.onlyoffice.desktopeditors \
    com.github.jeromerobert.pdfarranger \
    org.videolan.VLC \
    com.tomjwatson.Emote \
    com.github.hluk.copyq \
    com.google.Chrome -y

# aplicar o actualizar la personalizacion visual
echo "[5/5] Sincronizando temas y configuraciones visuales..."
mkdir -p ~/.themes ~/.icons

cp -ru ./themes/* ~/.themes/
cp -ru ./icons/* ~/.icons/

if [ -f ./configs/cinnamon.dconf ]; then
    sed "s|MINTDOWS_HOME|$REPO_DIR|g" ./configs/cinnamon.dconf > ./configs/cinnamon_runtime.dconf
    dconf load /org/cinnamon/ < ./configs/cinnamon_runtime.dconf
    rm ./configs/cinnamon_runtime.dconf
fi

MENU_DEST_DIR="$HOME/.config/cinnamon/spices/menu@cinnamon.org"
if [ -f ./configs/menu.json ]; then
    echo "Inyectando configuración del menú..."
    mkdir -p "$MENU_DEST_DIR"
    
    sed "s|MINTDOWS_HOME|$REPO_DIR|g" ./configs/menu.json > "$MENU_DEST_DIR/0.json"
fi

chmod +x ./install.sh
if [ -f "./update.sh" ]; then
    chmod +x ./update.sh
fi

DESKTOP_DIR=$(xdg-user-dir DESKTOP)

echo "Creando lanzador en Escritorio ($DESKTOP_DIR)..."

cat <<EOF > "$DESKTOP_DIR/Actualizar-Sistema.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Terminal=true
Name=Actualizar Sistema
Comment=Mantiene tus programas y la PC al día.
Exec=bash "$REPO_DIR/update.sh"
Icon=update
Categories=System;Settings;
EOF

chmod +x "$DESKTOP_DIR/Actualizar-Sistema.desktop"

echo "==========================================="
echo "    ¡Mintdows se instaló correctamente!    "
echo "==========================================="
echo " Presiona Enter para cerrar esta ventana..."
echo "==========================================="
read -p ""
kill -9 $PPID

