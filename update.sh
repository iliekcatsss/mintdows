#!/bin/bash

# guardar ruta actual
REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$REPO_DIR"

echo "==========================================="
echo "      Comprobando actualizaciones...       "
echo "==========================================="

# detectar rama
RAMA_ACTUAL=$(git branch --show-current)
if [ -z "$RAMA_ACTUAL" ]; then RAMA_ACTUAL="stable"; fi

# obtener version local
VERSION_LOCAL=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")

# traer ultimos cambios y tags
echo "[i] Sincronizando datos con GitHub..."
git fetch --tags origin &> /dev/null
CONEXION_GIT=$?

# mostrar estado actual de la rama
if [ "$RAMA_ACTUAL" = "main" ]; then
    echo "[i] Rama actual: $RAMA_ACTUAL (Desarrollo)"
    VERSION_LOCAL_TXT="${VERSION_LOCAL}-unstable"
else
    echo "[i] Rama actual: $RAMA_ACTUAL (Estable)"
    VERSION_LOCAL_TXT="$VERSION_LOCAL"
fi
echo "[i] Versión instalada: $VERSION_LOCAL_TXT"

# validar si hubo conexion con git
if [ $CONEXION_GIT -ne 0 ]; then
    echo "[!] No se pudo conectar con el servidor de GitHub."
    echo "[!] Se saltará la actualización del repositorio."
    echo ""
else
    VERSION_REMOTA=$(git tag -l | sort -V | tail -n1)
    
    if [ -z "$VERSION_REMOTA" ]; then
        VERSION_REMOTA="v0.0.0"
    fi

    if [ "$RAMA_ACTUAL" = "main" ]; then
        VERSION_REMOTA_TXT="${VERSION_REMOTA}-unstable"
    else
        VERSION_REMOTA_TXT="$VERSION_REMOTA"
    fi

    echo "[i] Versión disponible en GitHub: $VERSION_REMOTA_TXT"
    echo ""

    CAMBIOS_PENDIENTES=$(git rev-list HEAD..origin/"$RAMA_ACTUAL" --count 2>/dev/null)

    if [ "$CAMBIOS_PENDIENTES" = "0" ] || [ -z "$CAMBIOS_PENDIENTES" ]; then
        echo "[✔] Mintdows ya está en su última versión."
    else
        echo "[i] ¡Hay una nueva actualización disponible de Mintdows!"
        read -p "¿Deseas actualizar Mintdows a la versión $VERSION_REMOTA_TXT? (s/n): " RESPUESTA
        echo ""

        if [[ "$RESPUESTA" =~ ^[Ss]$ ]]; then
            echo "==========================================="
            echo "     Sincronizando Mintdows con GitHub...  "
            echo "==========================================="
            
            STASH_MARCA="mintdows-auto-update-$(date +%s)"
            git stash push -u -m "$STASH_MARCA" &> /dev/null
            STASH_CREADO=$?

            if git pull origin "$RAMA_ACTUAL"; then
                echo "[✔] Repositorio actualizado con éxito."
                chmod +x ./install.sh ./update.sh &> /dev/null
                
                VERSION_LOCAL=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
            else
                echo "[!] Error al sincronizar. Se usarán los archivos locales actuales."
            fi
            
            if [ $STASH_CREADO -eq 0 ] && git stash list | grep -q "$STASH_MARCA"; then
                STASH_REF=$(git stash list | grep "$STASH_MARCA" | head -n1 | cut -d: -f1)
                git stash pop "$STASH_REF" &> /dev/null
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
