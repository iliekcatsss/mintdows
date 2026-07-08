#!/bin/bash

# detener si hay error (?)
set -e

echo "==========================================="
echo "            Mintdows v1.0.0                "
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
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# instalar utilidades del sistema
echo "[4/5] Instalando aplicaciones desde FlatHub..."

sudo apt purge -y firefox firefox-locale-*
sudo apt autoremove -y

flatpak install flathub \
    org.localsend.localsend_app \
    org.onlyoffice.desktopeditors \
    com.github.jeromerobert.pdfarranger \
    org.videolan.VLC \
    com.tomwatson.Emote \
    com.github.hluk.CopyQ \
    com.google.Chrome -y

# aplicar o actualizar la personalizacion visual
echo "[5/5] Sincronizando temas y configuraciones visuales..."
mkdir -p ~/.themes ~/.icons

cp -ru ./themes/* ~/.themes/
cp -ru ./icons/* ~/.icons/

if [ -f ./configs/cinnamon.dconf ]; then
    dconf load /org/cinnamon/ < ./configs/cinnamon.dconf  
fi

echo "==========================================="
echo "    ¡Mintdows se instaló correctamente     "
echo "  Presiona Enter para cerrar esta ventana. "
echo "==========================================="
read
