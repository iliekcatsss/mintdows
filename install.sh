#!/bin/bash

# detener si hay error (?)
set -e

echo "==========================================="
echo "     Iniciando instalación de Mintdows     "
echo "==========================================="

# actualizar el sistema base
echo "[1/4] Actualizando repositorios..."
sudo apt update && sudo apt upgrade -y

# instalar dependencias
echo "[2/4] Instalando herramientas del sistema..."
sudo apt install -y git flatpak curl wget

# configurar flathub
echo "[3/4] Configurando repositorios de aplicaciones..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# instalar kit de apps
echo "[4/4] Instalando aplicaciones (LocalSend, OnlyOffice, PDF Arranger, VLC)..."
flatpak install flathub org.localsend.localsend_app org.onlyoffice.desktopeditors com.github.jeromerobert.pdfarranger org.videolan.VLC -y

echo "==========================================="
echo "     Fase 1 completada. Base instalada.    "
echo "==========================================="