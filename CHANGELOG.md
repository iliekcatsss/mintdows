# Changelog (WIP)

Todos los cambios notables en este proyecto serán documentados en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com)
y este proyecto se adhiere a [Semantic Versioning](https://semver.org).

## [Unreleased]

## [1.1.0] - 2026-08-23
### Añadido
- Colores en la salida de terminal (verde, rojo, amarillo, celeste, morado) en `install.sh`, `update.sh` y `uninstall.sh` para diferenciar mensajes de éxito, advertencia, error e información.
- Manejo de errores con reintentar/saltar/abortar (`ejecutar_paso()`) en operaciones críticas de `apt` y `flatpak`, en lugar de continuar silenciosamente ante un fallo.
- Vista previa de la sección correspondiente del `CHANGELOG.md` antes de aplicar una actualización en `update.sh`.
- Sistema de logs por corrida en `~/.mintdows/logs/` (`install_<fecha>.log` / `update_<fecha>.log` / `uninstall_<fecha>.log`), con symlink `latest-*.log` y limpieza automática que conserva los últimos 15 registros por script.
- Confirmación para reiniciar el sistema al finalizar la instalación (`install.sh`).
- **`uninstall.sh`**: script de desinstalación que revierte con precisión lo que `install.sh` cambió — reinstala Firefox si fue purgado, quita solo las apps Flatpak/temas/iconos/applets/extensiones que Mintdows instaló, resetea Cinnamon a su configuración de fábrica (`dconf reset -f /org/cinnamon/`), restaura o quita el `menu.json` según corresponda, y quita el lanzador de escritorio. Ofrece limpiar `~/.mintdows` y el propio repositorio al final. Si no encuentra el manifest de instalación (por ejemplo, tras actualizar desde una versión anterior a 1.1.0), opera en modo limitado con aviso explícito en vez de fallar.
- Manifest de instalación (`~/.mintdows/state.env`) generado por `install.sh`, con registro de todo lo que se instaló o modificó realmente (para que `uninstall.sh` pueda revertir con precisión en vez de adivinar).
- Soporte para empaquetar y distribuir applets y extensiones de Cinnamon propios: `install.sh` copia las carpetas en `applets/<uuid>/` y `extensions/<uuid>/` del repo a las rutas de usuario correspondientes y las habilita automáticamente en dconf (`enabled-applets`, `enabled-extensions`), calculando zona/orden/instance-id sin pisar el panel existente. Soporta zona configurable por applet vía `applets/panel-zones.conf`.

### Cambiado
- `install.sh` ahora detecta aplicaciones Flatpak ya instaladas y solo instala las que faltan, en vez de reinstalar todo el listado cada vez.
- La copia de temas e iconos ya no sobrescribe en automático: si detecta una instalación previa, pregunta antes de reinstalar/reparar.
- El `menu.json` ya no se sobrescribe incondicionalmente: si el usuario ya tenía una configuración de menú, se respalda en `~/.mintdows/backup/` antes de reemplazarla, y `uninstall.sh` puede restaurarla.

## [1.0.4] - 2026-08-XX
### Añadido
- Selector de navegador en `install.sh`: mantener Firefox, cambiar a Brave (recomendado) o cambiar a Google Chrome, usando un arreglo `FLATPAK_APPS` para evitar problemas de argumentos vacíos en `flatpak install`.

### Corregido
- Fallo de seguridad en `git stash`/`stash pop` de `update.sh`, ahora usando un stash nombrado con timestamp y lógica condicional de pop por referencia para no afectar stashes ajenos.
- Enlace de clonado roto en el README de la rama `main`.
- Finales de línea CRLF en `README.md` (corregido con `sed -i 's/\r$//'`).
- Badge `[Commit Rate]` en el README de `main` que apuntaba incorrectamente a `stable`.
- Stubs de enlaces de referencia rotos en `CHANGELOG.md`.

## [1.0.3] - 2026-07-13
### Añadido
- Nueva rama `stable` dedicada exclusivamente a lanzamientos de producción seguros.
- Mensaje de advertencia en `install.sh` si se ejecuta el script desde una rama inestable o de desarrollo (`-dev` o `-unstable`).
- Soporte en `update.sh` para detectar automáticamente la rama del usuario (`stable` o `main`) mediante `git branch --show-current`.

### Cambiado
- Se optimizó el proceso de actualización en `update.sh` para descargar el archivo `VERSION` desde GitHub de forma dinámica según la rama del usuario.
- El comando `git pull` en el actualizador ahora respeta la rama activa en lugar de forzar la sincronización con `main`.
- Se añadió protección con `git stash` en el actualizador para evitar fallos por conflictos si se modifican archivos locales.

### Eliminado
- Eliminada la dependencia de URLs estáticas vinculadas estrictamente a la rama `main` para las comprobaciones de versión remota.

[Unreleased]: https://github.com/iliekcatsss/mintdows/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/iliekcatsss/mintdows/compare/v1.0.4...v1.1.0
[1.0.4]: https://github.com/iliekcatsss/mintdows/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/iliekcatsss/mintdows/compare/v1.0.2...v1.0.3