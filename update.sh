#!/bin/bash

# guardar ruta actual
REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$REPO_DIR"

echo "==========================================="
echo "    Sincronizando Mintdows con GitHub...   "
echo "==========================================="

# jalar cambios desde git
if git pull origin main; then
    echo "[✔] Repositorio actualizado con éxito."
else
    echo "[!] No se pudo conectar a GitHub. Se usarán los archivos locales actuales."
fi

echo ""
echo "==========================================="
echo "    Iniciando Actualización del Sistema    "
echo "==========================================="
echo ""

echo "[1/3] Actualizando parches de seguridad del sistema..."
sudo apt update && sudo apt upgrade -y

echo ""
echo "[2/3] Actualizando aplicaciones..."
flatpak update -y

echo ""
echo "[3/3] Limpiando residuos y optimizando espacio..."
flatpak uninstall --unused -y
sudo apt autoremove -y

echo ""
echo "==========================================="
echo "    ¡Todo listo! Tu PC está al día.        "
echo "   Presiona Enter para cerrar esta ventana."
echo "==========================================="
read
