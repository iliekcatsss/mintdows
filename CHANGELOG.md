# Changelog

Todos los cambios notables en este proyecto serán documentados en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com)
y este proyecto se adhiere a [Semantic Versioning](https://semver.org).

## [Unreleased]

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

[Unreleased]: https://github.com/iliekcatsss/mintdows/compare/v1.0.3...HEAD
: https://github.com
: https://github.com
: https://github.com
