#!/bin/bash

# guardar ruta actual
REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$REPO_DIR"

echo "==========================================="
echo "      Comprobando actualizaciones...       "
echo "==========================================="

# leer version local (si no existe asume v0.0.0)
VERSION_LOCAL="0.0.0"
if [ -f "VERSION" ]; then
    VERSION_LOCAL=$(cat VERSION | tr -d '\r' | xargs)
fi

# descargar version remota
URL_VERSION="https://raw.githubusercontent.com/iliekcatsss/mintdows/refs/heads/main/VERSION"
VERSION_REMOTA=$(curl -sL --connect-timeout 5 "$URL_VERSION" | tr -d '\r' | xargs)

# mostrar estado de versiones
echo "[i] Versión instalada: v$VERSION_LOCAL"

if [ -z "$VERSION_REMOTA" ] || [[ "$VERSION_REMOTA" == *"404"* ]]; then
    echo "[!] No se pudo conectar a GitHub."
    echo "[!] Se saltará la actualización del repositorio."
    echo ""
else
    echo "[i] Versión disponible: v$VERSION_REMOTA"
    echo ""
    
    # comprobar version
    if [ "$VERSION_LOCAL" = "$VERSION_REMOTA" ] || [ "$(printf '%s\n%s' "$VERSION_REMOTA" "$VERSION_LOCAL" | sort -V | head -n1)" = "$VERSION_REMOTA" ]; then
        echo "[✔] Mintdows ya está en su última versión."
    else
        echo "[i] ¡Hay una nueva actualización disponible de Mintdows!"
        read -p "¿Deseas actualizar Mintdows a versión v$VERSION_REMOTA? (s/n): " RESPUESTA
        echo ""

        if [[ "$RESPUESTA" =~ ^[Ss]$ ]]; then
            echo "==========================================="
            echo "     Sincronizando Mintdows con GitHub...  "
            echo "==========================================="
            if git pull origin main; then
                echo "[✔] Repositorio actualizado con éxito."
            else
                echo "[!] Error al sincronizar. Se usarán los archivos locales actuales."
            fi
        else
            echo "[i] Actualización de Mintdows omitida por el usuario."
        fi
    fi
fi

echo ""
echo "==========================================="
echo "     Iniciando Actualización del Sistema   "
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
echo "      ¡Todo listo! Tu PC está al día.      "
echo "  Presiona Enter para cerrar esta ventana. "
echo "==========================================="
read

