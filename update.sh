#!/bin/bash

# guardar ruta actual
REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$REPO_DIR"

# --- Colores ---
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[0;33m'
CIAN='\033[0;36m'
MORADO='\033[0;35m'
NC='\033[0m' # Sin color

# --- Manejo de errores: reintentar / saltar / abortar ---
ejecutar_paso() {
    local descripcion="$1"
    shift
    while true; do
        "$@"
        local resultado=$?
        if [ $resultado -eq 0 ]; then
            return 0
        fi
        echo -e "${ROJO}[✘] Error en: $descripcion${NC}"
        read -p "¿Reintentar / Saltar / Abortar? (r/s/a) [r]: " OPCION
        OPCION=${OPCION:-r}
        case "$OPCION" in
            s|S)
                echo -e "${AMARILLO}[!] Paso omitido: $descripcion${NC}"
                return 1
                ;;
            a|A)
                echo -e "${ROJO}[✘] Actualización abortada por el usuario.${NC}"
                exit 1
                ;;
            *)
                echo -e "${CIAN}[i] Reintentando: $descripcion...${NC}"
                ;;
        esac
    done
}

# --- Logging: guarda cada corrida con fecha/hora + un "latest" de conveniencia ---
LOG_DIR="$HOME/.mintdows/logs"
mkdir -p "$LOG_DIR"
FECHA_LOG=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="$LOG_DIR/update_${FECHA_LOG}.log"

# a partir de aquí, todo lo que se imprima en pantalla también se guarda en el log
exec > >(tee -a "$LOG_FILE") 2>&1

# apuntar "latest" al log de esta corrida (symlink relativo, no copia)
ln -sf "$(basename "$LOG_FILE")" "$LOG_DIR/latest-update.log"

# conservar solo los últimos 15 logs de actualización para no acumular basura
ls -t "$LOG_DIR"/update_*.log 2>/dev/null | tail -n +16 | xargs -r rm --

echo -e "${CIAN}[i] Log de esta corrida: $LOG_FILE${NC}"
echo ""

# --- Muestra la sección del CHANGELOG correspondiente a una versión ---
mostrar_changelog() {
    local version_num="$1"   # sin la "v", ej: 1.0.4
    local rama="$2"
    local url="https://raw.githubusercontent.com/iliekcatsss/mintdows/${rama}/CHANGELOG.md"
    local contenido
    contenido=$(curl -fsSL "$url" 2>/dev/null)

    if [ -z "$contenido" ]; then
        return 1
    fi

    local seccion
    seccion=$(echo "$contenido" | awk -v ver="## [$version_num]" '
        index($0, ver) == 1 { flag=1; next }
        /^## \[/ && flag { exit }
        flag && NF { print }
    ')

    if [ -n "$seccion" ]; then
        echo -e "${MORADO}--- Novedades en v$version_num ---${NC}"
        echo "$seccion"
        echo -e "${MORADO}-----------------------------------${NC}"
        return 0
    fi
    return 1
}

echo -e "${MORADO}==========================================="
echo "      Comprobando actualizaciones...       "
echo -e "===========================================${NC}"

# detectar rama
RAMA_ACTUAL=$(git branch --show-current)
if [ -z "$RAMA_ACTUAL" ]; then RAMA_ACTUAL="stable"; fi

# obtener version local
VERSION_LOCAL=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")

# traer ultimos cambios y tags
echo -e "${CIAN}[i] Sincronizando datos con GitHub...${NC}"
git fetch --tags origin &> /dev/null
CONEXION_GIT=$?

# mostrar estado actual de la rama
if [ "$RAMA_ACTUAL" = "main" ]; then
    echo -e "${AMARILLO}[i] Rama actual: $RAMA_ACTUAL (Desarrollo)${NC}"
    VERSION_LOCAL_TXT="${VERSION_LOCAL}-unstable"
else
    echo -e "${CIAN}[i] Rama actual: $RAMA_ACTUAL (Estable)${NC}"
    VERSION_LOCAL_TXT="$VERSION_LOCAL"
fi
echo "[i] Versión instalada: $VERSION_LOCAL_TXT"

# validar si hubo conexion con git
if [ $CONEXION_GIT -ne 0 ]; then
    echo -e "${ROJO}[!] No se pudo conectar con el servidor de GitHub.${NC}"
    echo -e "${ROJO}[!] Se saltará la actualización del repositorio.${NC}"
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
        echo -e "${VERDE}[✔] Mintdows ya está en su última versión.${NC}"
    else
        echo -e "${CIAN}[i] ¡Hay una nueva actualización disponible de Mintdows!${NC}"

        # mostrar changelog de la nueva version antes de preguntar
        mostrar_changelog "${VERSION_REMOTA#v}" "$RAMA_ACTUAL"
        echo ""

        read -p "¿Deseas actualizar Mintdows a la versión $VERSION_REMOTA_TXT? (s/n): " RESPUESTA
        echo ""

        if [[ "$RESPUESTA" =~ ^[Ss]$ ]]; then
            echo -e "${MORADO}==========================================="
            echo "     Sincronizando Mintdows con GitHub...  "
            echo -e "===========================================${NC}"

            STASH_MARCA="mintdows-auto-update-$(date +%s)"
            git stash push -u -m "$STASH_MARCA" &> /dev/null
            STASH_CREADO=$?

            if git pull origin "$RAMA_ACTUAL"; then
                echo -e "${VERDE}[✔] Repositorio actualizado con éxito.${NC}"
                chmod +x ./install.sh ./update.sh &> /dev/null

                VERSION_LOCAL=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
            else
                echo -e "${ROJO}[!] Error al sincronizar. Se usarán los archivos locales actuales.${NC}"
            fi

            if [ $STASH_CREADO -eq 0 ] && git stash list | grep -q "$STASH_MARCA"; then
                STASH_REF=$(git stash list | grep "$STASH_MARCA" | head -n1 | cut -d: -f1)
                git stash pop "$STASH_REF" &> /dev/null
            fi
        else
            echo -e "${CIAN}[i] Actualización de Mintdows omitida por el usuario.${NC}"
        fi
    fi
fi

echo ""
echo -e "${MORADO}==========================================="
echo "     Iniciando Actualización del Sistema   "
echo -e "===========================================${NC}"
echo ""

echo "[1/3] Actualizando parches de seguridad del sistema..."
paso_actualizar_sistema() {
    sudo apt update && sudo apt upgrade -y
}
ejecutar_paso "Actualización de parches del sistema" paso_actualizar_sistema
echo ""

echo "[2/3] Actualizando aplicaciones..."
paso_actualizar_flatpaks() {
    flatpak update -y
}
ejecutar_paso "Actualización de aplicaciones Flatpak" paso_actualizar_flatpaks
echo ""

echo "[3/3] Limpiando residuos y optimizando espacio..."
paso_limpiar_residuos() {
    flatpak uninstall --unused -y
    sudo apt autoremove -y
}
ejecutar_paso "Limpieza de residuos del sistema" paso_limpiar_residuos
echo ""

echo -e "${VERDE}==========================================="
echo "      ¡Todo listo! Tu PC está al día.      "
echo -e "===========================================${NC}"
read -p "Presiona Enter para cerrar esta ventana..."
