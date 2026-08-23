#!/bin/bash

REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$REPO_DIR"

# colores
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[0;33m'
CELESTE='\033[0;36m'
MORADO='\033[0;35m'
NC='\033[0m' # Sin color

# errores
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
                echo -e "${ROJO}[✘] Desinstalación abortada por el usuario.${NC}"
                exit 1
                ;;
            *)
                echo -e "${CELESTE}[i] Reintentando: $descripcion...${NC}"
                ;;
        esac
    done
}

MINTDOWS_DIR="$HOME/.mintdows"

# helper
dconf_remove_strings() {
    local key="$1"
    shift
    local a_quitar=("$@")
    [ ${#a_quitar[@]} -eq 0 ] && return 0

    local actual items=()
    actual=$(dconf read "$key" 2>/dev/null)
    if [ -z "$actual" ] || [ "$actual" = "@as []" ] || [ "$actual" = "[]" ]; then
        return 0
    fi

    local contenido="${actual#\[}"
    contenido="${contenido%\]}"
    IFS=',' read -ra partes <<< "$contenido"
    for p in "${partes[@]}"; do
        p="${p# }"; p="${p%\'}"; p="${p#\'}"
        [ -z "$p" ] && continue
        local quitar=false
        for q in "${a_quitar[@]}"; do
            [ "$p" = "$q" ] && quitar=true && break
        done
        [ "$quitar" = false ] && items+=("$p")
    done

    local salida="[" primero=true
    for it in "${items[@]}"; do
        if [ "$primero" = true ]; then salida+="'$it'"; primero=false; else salida+=", '$it'"; fi
    done
    salida+="]"
    dconf write "$key" "$salida"
}

# logs
LOG_DIR="$MINTDOWS_DIR/logs"
mkdir -p "$LOG_DIR"
FECHA_LOG=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="$LOG_DIR/uninstall_${FECHA_LOG}.log"

exec > >(tee -a "$LOG_FILE") 2>&1

ln -sf "$(basename "$LOG_FILE")" "$LOG_DIR/latest-uninstall.log"
ls -t "$LOG_DIR"/uninstall_*.log 2>/dev/null | tail -n +16 | xargs -r rm --

echo -e "${MORADO}==========================================="
echo "         Desinstalando Mintdows...         "
echo -e "===========================================${NC}"
echo -e "${CELESTE}[i] Log de esta corrida: $LOG_FILE${NC}"
echo ""

# cargar manifest
STATE_FILE="$MINTDOWS_DIR/state.env"
if [ -f "$STATE_FILE" ]; then
    source "$STATE_FILE"
    echo -e "${CELESTE}[i] Se encontró el registro de instalación del $INSTALL_DATE (rama: $RAMA_INSTALADA).${NC}"
else
    echo -e "${AMARILLO}[!] No se encontró $STATE_FILE.${NC}"
    echo -e "${AMARILLO}[!] No hay registro de qué instaló Mintdows exactamente; el uninstall será limitado${NC}"
    echo -e "${AMARILLO}    (solo limpiará el menú, el lanzador de escritorio, y reseteará dconf).${NC}"
    FIREFOX_PURGADO="false"
    BROWSER_FLATPAK_NUEVO=""
    MENU_JSON_HABIA_PREVIO="false"
    FLATPAK_APPS_INSTALADAS=()
    TEMAS_COPIADOS=()
    ICONOS_COPIADOS=()
    APPLETS_COPIADOS=()
    EXTENSIONS_COPIADAS=()
    APPLETS_ENTRADAS_HABILITADAS=()
fi
echo ""

echo -e "${AMARILLO}Esto va a revertir los cambios que Mintdows hizo en tu sistema.${NC}"
read -p "¿Deseas continuar con la desinstalación? (s/n) [n]: " CONFIRMAR
CONFIRMAR=${CONFIRMAR:-n}
if [[ ! "$CONFIRMAR" =~ ^[Ss]$ ]]; then
    echo -e "${CELESTE}[i] Desinstalación cancelada.${NC}"
    exit 0
fi
echo ""

# restaurar firefox
echo "[1/7] Restaurando navegador original..."
if [ "$FIREFOX_PURGADO" = "true" ]; then
    paso_reinstalar_firefox() {
        sudo apt install -y firefox
    }
    ejecutar_paso "Reinstalación de Firefox" paso_reinstalar_firefox
else
    echo -e "${CELESTE}[i] Firefox no fue purgado por Mintdows, no hay nada que restaurar.${NC}"
fi

# quitar navegador
if [ -n "$BROWSER_FLATPAK_NUEVO" ]; then
    read -p "¿Deseas desinstalar $BROWSER_FLATPAK_NUEVO y borrar sus datos? (s/n) [s]: " QUITAR_BROWSER
    QUITAR_BROWSER=${QUITAR_BROWSER:-s}
    if [[ "$QUITAR_BROWSER" =~ ^[Ss]$ ]]; then
        paso_quitar_browser() {
            flatpak uninstall --delete-data -y "$BROWSER_FLATPAK_NUEVO"
        }
        ejecutar_paso "Desinstalación de $BROWSER_FLATPAK_NUEVO" paso_quitar_browser
    fi
fi
echo ""

# quitar apps flatpak
echo "[2/7] Quitando aplicaciones Flatpak instaladas por Mintdows..."
if [ ${#FLATPAK_APPS_INSTALADAS[@]} -eq 0 ]; then
    echo -e "${CELESTE}[i] No hay aplicaciones registradas para quitar.${NC}"
else
    echo "Se quitarán:"
    for app in "${FLATPAK_APPS_INSTALADAS[@]}"; do
        echo "  - $app"
    done
    read -p "¿Confirmas? (s/n) [s]: " QUITAR_APPS
    QUITAR_APPS=${QUITAR_APPS:-s}
    if [[ "$QUITAR_APPS" =~ ^[Ss]$ ]]; then
        paso_quitar_apps() {
            flatpak uninstall --delete-data -y "${FLATPAK_APPS_INSTALADAS[@]}"
        }
        ejecutar_paso "Desinstalación de aplicaciones Flatpak" paso_quitar_apps
    fi
fi
echo ""

# quitar temas
echo "[3/7] Quitando temas e iconos instalados por Mintdows..."
if [ ${#TEMAS_COPIADOS[@]} -eq 0 ] && [ ${#ICONOS_COPIADOS[@]} -eq 0 ]; then
    echo -e "${CELESTE}[i] No hay temas/iconos registrados para quitar.${NC}"
else
    for tema in "${TEMAS_COPIADOS[@]}"; do
        if [ -d "$HOME/.themes/$tema" ]; then
            rm -rf "$HOME/.themes/$tema"
            echo -e "${CELESTE}[i] Quitado tema: $tema${NC}"
        fi
    done
    for icono in "${ICONOS_COPIADOS[@]}"; do
        if [ -d "$HOME/.icons/$icono" ]; then
            rm -rf "$HOME/.icons/$icono"
            echo -e "${CELESTE}[i] Quitado paquete de iconos: $icono${NC}"
        fi
    done
    echo -e "${VERDE}[✔] Temas e iconos de Mintdows removidos.${NC}"
fi
echo ""

# quitar applets
echo "[4/7] Quitando applets y extensiones de Mintdows..."
if [ ${#APPLETS_COPIADOS[@]} -eq 0 ] && [ ${#EXTENSIONS_COPIADAS[@]} -eq 0 ]; then
    echo -e "${CELESTE}[i] No hay applets/extensiones registrados para quitar.${NC}"
else
    if [ ${#APPLETS_ENTRADAS_HABILITADAS[@]} -gt 0 ]; then
        dconf_remove_strings "/org/cinnamon/enabled-applets" "${APPLETS_ENTRADAS_HABILITADAS[@]}"
    fi
    if [ ${#EXTENSIONS_COPIADAS[@]} -gt 0 ]; then
        dconf_remove_strings "/org/cinnamon/enabled-extensions" "${EXTENSIONS_COPIADAS[@]}"
    fi
    for uuid in "${APPLETS_COPIADOS[@]}"; do
        if [ -d "$HOME/.local/share/cinnamon/applets/$uuid" ]; then
            rm -rf "$HOME/.local/share/cinnamon/applets/$uuid"
            echo -e "${CELESTE}[i] Quitado applet: $uuid${NC}"
        fi
    done
    for uuid in "${EXTENSIONS_COPIADAS[@]}"; do
        if [ -d "$HOME/.local/share/cinnamon/extensions/$uuid" ]; then
            rm -rf "$HOME/.local/share/cinnamon/extensions/$uuid"
            echo -e "${CELESTE}[i] Quitada extensión: $uuid${NC}"
        fi
    done
    echo -e "${VERDE}[✔] Applets y extensiones de Mintdows removidos y deshabilitados.${NC}"
fi
echo ""

# resetear cinnamon
echo "[5/7] Reseteando Cinnamon a su configuración por defecto..."
read -p "Esto restablecerá tema, applets, panel, etc. a los valores de fábrica de Cinnamon. ¿Continuar? (s/n) [s]: " RESET_CINNAMON
RESET_CINNAMON=${RESET_CINNAMON:-s}
if [[ "$RESET_CINNAMON" =~ ^[Ss]$ ]]; then
    paso_reset_dconf() {
        dconf reset -f /org/cinnamon/
    }
    ejecutar_paso "Reseteo de configuración de Cinnamon" paso_reset_dconf
    echo -e "${VERDE}[✔] Cinnamon reseteado. Puede que necesites cerrar sesión o reiniciar para verlo reflejado.${NC}"
else
    echo -e "${CELESTE}[i] Se omitió el reseteo de Cinnamon.${NC}"
fi
echo ""

# restaurar menu.json
echo "[6/7] Restaurando menú de Cinnamon..."
MENU_DEST_DIR="$HOME/.config/cinnamon/spices/menu@cinnamon.org"
if [ -f "$MENU_DEST_DIR/0.json" ]; then
    if [ "$MENU_JSON_HABIA_PREVIO" = "true" ] && [ -f "$MINTDOWS_DIR/backup/menu_0.json.orig" ]; then
        cp "$MINTDOWS_DIR/backup/menu_0.json.orig" "$MENU_DEST_DIR/0.json"
        echo -e "${VERDE}[✔] Configuración de menú anterior restaurada.${NC}"
    else
        rm -f "$MENU_DEST_DIR/0.json"
        echo -e "${CELESTE}[i] Configuración de menú de Mintdows removida (no había una previa que restaurar).${NC}"
    fi
else
    echo -e "${CELESTE}[i] No hay configuración de menú que revertir.${NC}"
fi
echo ""

# quitar update
echo "[7/7] Quitando lanzador de escritorio..."
DESKTOP_DIR=$(xdg-user-dir DESKTOP 2>/dev/null)
if [ -n "$DESKTOP_DIR" ] && [ -f "$DESKTOP_DIR/Actualizar-Sistema.desktop" ]; then
    rm -f "$DESKTOP_DIR/Actualizar-Sistema.desktop"
    echo -e "${VERDE}[✔] Lanzador de escritorio removido.${NC}"
else
    echo -e "${CELESTE}[i] No se encontró el lanzador de escritorio.${NC}"
fi
echo ""

echo -e "${VERDE}==========================================="
echo "     Mintdows fue desinstalado del sistema  "
echo -e "===========================================${NC}"
echo ""

echo -e "${MORADO}--- Limpieza de archivos de Mintdows ---${NC}"

read -p "¿Deseas borrar los logs de Mintdows (~/.mintdows/logs)? (s/n) [n]: " BORRAR_LOGS
BORRAR_LOGS=${BORRAR_LOGS:-n}
if [[ "$BORRAR_LOGS" =~ ^[Ss]$ ]]; then
    find "$LOG_DIR" -type f ! -name "$(basename "$LOG_FILE")" -delete 2>/dev/null
    find "$LOG_DIR" -type l -delete 2>/dev/null
    echo -e "${CELESTE}[i] Logs anteriores eliminados (este log se conserva hasta que cierres la sesión).${NC}"
fi

read -p "¿Deseas borrar toda la carpeta ~/.mintdows (backups y registro de instalación)? (s/n) [n]: " BORRAR_MINTDOWS_DIR
BORRAR_MINTDOWS_DIR=${BORRAR_MINTDOWS_DIR:-n}
if [[ "$BORRAR_MINTDOWS_DIR" =~ ^[Ss]$ ]]; then
    echo -e "${AMARILLO}[!] Esto también borrará el log que acabas de generar.${NC}"
    rm -rf "${MINTDOWS_DIR:?}/backup" "${MINTDOWS_DIR:?}/state.env"
    echo -e "${CELESTE}[i] Backups y registro de instalación eliminados. Los logs se borrarán al reiniciar sesión.${NC}"
fi

read -p "¿Deseas borrar la carpeta del repositorio de Mintdows ($REPO_DIR)? (s/n) [n]: " BORRAR_REPO
BORRAR_REPO=${BORRAR_REPO:-n}
if [[ "$BORRAR_REPO" =~ ^[Ss]$ ]]; then
    echo -e "${CELESTE}[i] Borrando $REPO_DIR...${NC}"
    cd "$HOME"
    rm -rf "${REPO_DIR:?}"
    echo -e "${VERDE}[✔] Repositorio eliminado.${NC}"
fi

echo ""
echo -e "${VERDE}Listo. Gracias por probar Mintdows.${NC}"
read -p "Presiona Enter para cerrar esta ventana..."