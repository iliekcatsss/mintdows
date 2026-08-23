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
                echo -e "${ROJO}[✘] Instalación abortada por el usuario.${NC}"
                exit 1
                ;;
            *)
                echo -e "${CELESTE}[i] Reintentando: $descripcion...${NC}"
                ;;
        esac
    done
}

# logs
LOG_DIR="$HOME/.mintdows/logs"
mkdir -p "$LOG_DIR"
FECHA_LOG=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="$LOG_DIR/install_${FECHA_LOG}.log"

exec > >(tee -a "$LOG_FILE") 2>&1

ln -sf "$(basename "$LOG_FILE")" "$LOG_DIR/latest-install.log"

# conservar solo los últimos 15 logs de instalación para no acumular basura
ls -t "$LOG_DIR"/install_*.log 2>/dev/null | tail -n +16 | xargs -r rm --

echo -e "${CELESTE}[i] Log: $LOG_FILE${NC}"
echo ""

git fetch --tags &> /dev/null

VERSION_LOCAL=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")

RAMA_ACTUAL=$(git branch --show-current)
if [ -z "$RAMA_ACTUAL" ]; then RAMA_ACTUAL="stable"; fi

if [ "$RAMA_ACTUAL" = "main" ]; then
    VERSION_LOCAL="${VERSION_LOCAL}-unstable"
    echo -e "${AMARILLO}[!] ADVERTENCIA: Estás usando una versión INESTABLE de desarrollo ($VERSION_LOCAL).${NC}"
    echo -e "${AMARILLO}Sujeta a fallos. Usa bajo tu propio riesgo.${NC}"
fi

echo -e "${MORADO}==========================================="
echo "            Mintdows $VERSION_LOCAL"
echo "             Por ILikeCats                 "
echo -e "===========================================${NC}"

echo "==========================================="
echo "    IniCELESTEdo instalación de Mintdows...   "
echo "==========================================="

# actualizar el sistema base
echo "[1/5] Actualizando repositorios..."
paso_actualizar_repos() {
    sudo apt update && sudo apt upgrade -y
}
ejecutar_paso "Actualización de repositorios del sistema" paso_actualizar_repos

# instalar herramientas
echo "[2/5] Instalando herramientas del sistema..."
paso_instalar_herramientas() {
    sudo apt install -y git flatpak curl wget
}
ejecutar_paso "Instalación de herramientas del sistema" paso_instalar_herramientas

# configurar flathub
echo "[3/5] Configurando repositorios de aplicaciones..."
paso_configurar_flathub() {
    flatpak remote-add --if-not-exists flathub https://flathub.org
}
ejecutar_paso "Configuración de Flathub" paso_configurar_flathub

# instalar utilidades del sistema
echo "[4/5] Instalando aplicaciones desde FlatHub..."

# preguntar al usuario qué navegador prefiere
echo ""
echo "-------------------------------------------"
echo " Selecciona tu navegador:"
echo "   1) Mantener Firefox"
echo "   2) Cambiar a Brave (recomendado, alternativa privada a Chrome)"
echo "   3) Cambiar a Google Chrome"
echo "-------------------------------------------"
read -p "Elige una opción (1/2/3) [2]: " OPCION_NAVEGADOR
OPCION_NAVEGADOR=${OPCION_NAVEGADOR:-2}

BROWSER_FLATPAK=""
FIREFOX_PURGADO="false"
case "$OPCION_NAVEGADOR" in
    1)
        echo -e "${CELESTE}[i] Se mantendrá Firefox instalado.${NC}"
        ;;
    3)
        echo -e "${CELESTE}[i] Se eliminará Firefox y se instalará Google Chrome.${NC}"
        paso_purgar_firefox() {
            sudo apt purge -y firefox firefox-locale-*
            sudo apt autoremove -y
        }
        if ejecutar_paso "Eliminación de Firefox" paso_purgar_firefox; then
            FIREFOX_PURGADO="true"
        fi
        BROWSER_FLATPAK="com.google.Chrome"
        ;;
    *)
        echo -e "${CELESTE}[i] Se eliminará Firefox y se instalará Brave Browser.${NC}"
        paso_purgar_firefox() {
            sudo apt purge -y firefox firefox-locale-*
            sudo apt autoremove -y
        }
        if ejecutar_paso "Eliminación de Firefox" paso_purgar_firefox; then
            FIREFOX_PURGADO="true"
        fi
        BROWSER_FLATPAK="com.brave.Browser"
        ;;
esac
echo ""

FLATPAK_APPS=(
    org.localsend.localsend_app
    org.onlyoffice.desktopeditors
    com.github.jeromerobert.pdfarranger
    org.videolan.VLC
    com.tomjwatson.Emote
    com.github.hluk.copyq
)
if [ -n "$BROWSER_FLATPAK" ]; then
    FLATPAK_APPS+=("$BROWSER_FLATPAK")
fi

# detectar apps ya instaladas para no reinstalar de más
APPS_INSTALADAS=$(flatpak list --app --columns=application 2>/dev/null)
FLATPAK_APPS_FALTANTES=()
for app in "${FLATPAK_APPS[@]}"; do
    if echo "$APPS_INSTALADAS" | grep -qx "$app"; then
        echo -e "${CELESTE}[i] $app ya está instalado, se omite.${NC}"
    else
        FLATPAK_APPS_FALTANTES+=("$app")
    fi
done

if [ ${#FLATPAK_APPS_FALTANTES[@]} -eq 0 ]; then
    echo -e "${VERDE}[✔] Todas las aplicaciones ya estaban instaladas.${NC}"
else
    paso_instalar_flatpaks() {
        flatpak install flathub "${FLATPAK_APPS_FALTANTES[@]}" -y
    }
    ejecutar_paso "Instalación de aplicaciones Flatpak" paso_instalar_flatpaks
fi

# el navegador flatpak elegido era nuevo, o ya lo tenia el usuario?
BROWSER_FLATPAK_NUEVO=""
if [ -n "$BROWSER_FLATPAK" ]; then
    for app in "${FLATPAK_APPS_FALTANTES[@]}"; do
        if [ "$app" = "$BROWSER_FLATPAK" ]; then
            BROWSER_FLATPAK_NUEVO="$BROWSER_FLATPAK"
            break
        fi
    done
fi

# aplicar o actualizar la personalizacion visual
echo "[5/5] Sincronizando temas y configuraciones visuales..."
mkdir -p ~/.themes ~/.icons

TEMAS_YA_INSTALADOS=false
if [ -n "$(ls -A ~/.themes 2>/dev/null)" ] || [ -n "$(ls -A ~/.icons 2>/dev/null)" ]; then
    TEMAS_YA_INSTALADOS=true
fi

if [ "$TEMAS_YA_INSTALADOS" = true ]; then
    echo -e "${AMARILLO}[!] Ya se detectaron temas/iconos instalados previamente.${NC}"
    read -p "¿Deseas reinstalar/reparar los temas e iconos? (s/n) [n]: " REINSTALAR_TEMAS
    REINSTALAR_TEMAS=${REINSTALAR_TEMAS:-n}
else
    REINSTALAR_TEMAS="s"
fi

MINTDOWS_DIR="$HOME/.mintdows"
mkdir -p "$MINTDOWS_DIR/backup"

TEMAS_COPIADOS=()
ICONOS_COPIADOS=()
if [[ "$REINSTALAR_TEMAS" =~ ^[Ss]$ ]]; then
    # registrar que carpetas se copian realmente, para poder revertirlas en el uninstall
    for d in ./themes/*/; do
        [ -d "$d" ] && TEMAS_COPIADOS+=("$(basename "$d")")
    done
    for d in ./icons/*/; do
        [ -d "$d" ] && ICONOS_COPIADOS+=("$(basename "$d")")
    done

    cp -ru ./themes/* ~/.themes/
    cp -ru ./icons/* ~/.icons/
    echo -e "${VERDE}[✔] Temas e iconos sincronizados.${NC}"
else
    echo -e "${CELESTE}[i] Se omitió la copia de temas e iconos.${NC}"
fi

if [ -f ./configs/cinnamon.dconf ]; then
    sed "s|MINTDOWS_HOME|$REPO_DIR|g" ./configs/cinnamon.dconf > ./configs/cinnamon_runtime.dconf
    dconf load /org/cinnamon/ < ./configs/cinnamon_runtime.dconf
    rm ./configs/cinnamon_runtime.dconf
fi

# applets
dconf_append_strings() {
    local key="$1"
    shift
    local nuevos=("$@")
    [ ${#nuevos[@]} -eq 0 ] && return 0

    local actual items=()
    actual=$(dconf read "$key" 2>/dev/null)
    if [ -n "$actual" ] && [ "$actual" != "@as []" ] && [ "$actual" != "[]" ]; then
        local contenido="${actual#\[}"
        contenido="${contenido%\]}"
        IFS=',' read -ra partes <<< "$contenido"
        for p in "${partes[@]}"; do
            p="${p# }"; p="${p%\'}"; p="${p#\'}"
            [ -n "$p" ] && items+=("$p")
        done
    fi

    for n in "${nuevos[@]}"; do
        local ya=false
        for existente in "${items[@]}"; do
            [ "$existente" = "$n" ] && ya=true && break
        done
        [ "$ya" = false ] && items+=("$n")
    done

    local salida="[" primero=true
    for it in "${items[@]}"; do
        if [ "$primero" = true ]; then salida+="'$it'"; primero=false; else salida+=", '$it'"; fi
    done
    salida+="]"
    dconf write "$key" "$salida"
}

APPLETS_COPIADOS=()
EXTENSIONS_COPIADAS=()
APPLETS_ENTRADAS_HABILITADAS=()

if [ -d ./applets ] || [ -d ./extensions ]; then
    echo "Instalando applets y extensiones de Cinnamon..."
    mkdir -p ~/.local/share/cinnamon/applets ~/.local/share/cinnamon/extensions

    if [ -d ./applets ]; then
        for d in ./applets/*/; do
            [ -d "$d" ] || continue
            uuid="$(basename "$d")"
            cp -ru "$d" ~/.local/share/cinnamon/applets/
            APPLETS_COPIADOS+=("$uuid")
        done
    fi

    if [ -d ./extensions ]; then
        for d in ./extensions/*/; do
            [ -d "$d" ] || continue
            uuid="$(basename "$d")"
            cp -ru "$d" ~/.local/share/cinnamon/extensions/
            EXTENSIONS_COPIADAS+=("$uuid")
        done
    fi

    if [ ${#APPLETS_COPIADOS[@]} -gt 0 ]; then
        ACTUAL_APPLETS=$(dconf read /org/cinnamon/enabled-applets 2>/dev/null)
        MAX_ID=0
        declare -A ORDEN_POR_ZONA
        if [ -n "$ACTUAL_APPLETS" ] && [ "$ACTUAL_APPLETS" != "@as []" ] && [ "$ACTUAL_APPLETS" != "[]" ]; then
            CONTENIDO="${ACTUAL_APPLETS#\[}"; CONTENIDO="${CONTENIDO%\]}"
            IFS=',' read -ra ENTRADAS <<< "$CONTENIDO"
            for e in "${ENTRADAS[@]}"; do
                e="${e# }"; e="${e%\'}"; e="${e#\'}"
                [ -z "$e" ] && continue
                IFS=':' read -r _panel zona orden _uuid iid <<< "$e"
                if [[ "$iid" =~ ^[0-9]+$ ]] && [ "$iid" -gt "$MAX_ID" ]; then
                    MAX_ID=$iid
                fi
                if [[ "$orden" =~ ^[0-9]+$ ]]; then
                    actual_cuenta=${ORDEN_POR_ZONA[$zona]:-0}
                    if [ "$orden" -ge "$actual_cuenta" ]; then
                        ORDEN_POR_ZONA[$zona]=$((orden + 1))
                    fi
                fi
            done
        fi

        for uuid in "${APPLETS_COPIADOS[@]}"; do
            ZONA="right"
            if [ -f ./applets/panel-zones.conf ]; then
                ZONA_CONF=$(grep "^$uuid=" ./applets/panel-zones.conf | cut -d= -f2)
                [ -n "$ZONA_CONF" ] && ZONA="$ZONA_CONF"
            fi
            ORDEN=${ORDEN_POR_ZONA[$ZONA]:-0}
            ORDEN_POR_ZONA[$ZONA]=$((ORDEN + 1))
            MAX_ID=$((MAX_ID + 1))
            APPLETS_ENTRADAS_HABILITADAS+=("panel1:$ZONA:$ORDEN:$uuid:$MAX_ID")
        done

        dconf_append_strings "/org/cinnamon/enabled-applets" "${APPLETS_ENTRADAS_HABILITADAS[@]}"
        echo -e "${VERDE}[✔] Applets habilitados: ${APPLETS_COPIADOS[*]}${NC}"
    fi

    if [ ${#EXTENSIONS_COPIADAS[@]} -gt 0 ]; then
        dconf_append_strings "/org/cinnamon/enabled-extensions" "${EXTENSIONS_COPIADAS[@]}"
        echo -e "${VERDE}[✔] Extensiones habilitadas: ${EXTENSIONS_COPIADAS[*]}${NC}"
    fi
fi

MENU_DEST_DIR="$HOME/.config/cinnamon/spices/menu@cinnamon.org"
MENU_JSON_HABIA_PREVIO="false"
if [ -f ./configs/menu.json ]; then
    echo "Inyectando configuración del menú..."
    mkdir -p "$MENU_DEST_DIR"

    if [ -f "$MENU_DEST_DIR/0.json" ]; then
        MENU_JSON_HABIA_PREVIO="true"
        cp "$MENU_DEST_DIR/0.json" "$MINTDOWS_DIR/backup/menu_0.json.orig"
    fi

    sed "s|MINTDOWS_HOME|$REPO_DIR|g" ./configs/menu.json > "$MENU_DEST_DIR/0.json"
fi

chmod +x ./install.sh
if [ -f "./update.sh" ]; then
    chmod +x ./update.sh
fi
if [ -f "./uninstall.sh" ]; then
    chmod +x ./uninstall.sh
fi

# manifest
STATE_FILE="$MINTDOWS_DIR/state.env"
cat > "$STATE_FILE" <<EOF
# Generado automáticamente por install.sh — no editar a mano
INSTALL_DATE="$(date +"%Y-%m-%d_%H-%M-%S")"
RAMA_INSTALADA="$RAMA_ACTUAL"
REPO_DIR="$REPO_DIR"
FIREFOX_PURGADO="$FIREFOX_PURGADO"
BROWSER_FLATPAK_NUEVO="$BROWSER_FLATPAK_NUEVO"
MENU_JSON_HABIA_PREVIO="$MENU_JSON_HABIA_PREVIO"
FLATPAK_APPS_INSTALADAS=(${FLATPAK_APPS_FALTANTES[@]@Q})
TEMAS_COPIADOS=(${TEMAS_COPIADOS[@]@Q})
ICONOS_COPIADOS=(${ICONOS_COPIADOS[@]@Q})
APPLETS_COPIADOS=(${APPLETS_COPIADOS[@]@Q})
EXTENSIONS_COPIADAS=(${EXTENSIONS_COPIADAS[@]@Q})
APPLETS_ENTRADAS_HABILITADAS=(${APPLETS_ENTRADAS_HABILITADAS[@]@Q})
EOF

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

echo -e "${VERDE}==========================================="
echo "    ¡Mintdows se instaló correctamente!    "
echo -e "===========================================${NC}"
echo ""
echo -e "${AMARILLO}           [i] NOTA IMPORTANTE:${NC}"
echo "   Se recomienda REINICIAR LA PC para aplicar"
echo "         por completo los cambios al sistema."
echo "==========================================="
echo ""
read -p "¿Deseas reiniciar ahora? (s/n) [s]: " REINICIAR_AHORA
REINICIAR_AHORA=${REINICIAR_AHORA:-s}

if [[ "$REINICIAR_AHORA" =~ ^[Ss]$ ]]; then
    echo -e "${CELESTE}[i] ReiniCELESTEdo el sistema...${NC}"
    sudo reboot
else
    echo -e "${CELESTE}[i] Recuerda reiniciar más tarde para aplicar todos los cambios.${NC}"
    read -p "Presiona Enter para cerrar esta ventana..."
fi

kill -9 $PPID