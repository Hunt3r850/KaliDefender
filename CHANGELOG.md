# Changelog

Todos los cambios notables en este proyecto serán documentados en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es/1.0.0/),
y este proyecto adhiere al [Versionado Semántico](https://semver.org/lang/es/).

---

## [5.0.0] - 2025-01-XX

### 🔴 CRÍTICO - Mejoras de Seguridad

#### Corregido
- **Fuga de tráfico en Modo Stealth**: Eliminadas las reglas que permitían tráfico HTTP/HTTPS directo fuera de Tor (líneas 165-166 en v4.2.1). Ahora TODO el tráfico pasa obligatoriamente por Tor.
- **Validación de UID de debian-tor**: Se verifica explícitamente la existencia del usuario `debian-tor` antes de aplicar reglas. El script falla si no existe, previniendo uso de UID incorrecto.
- **Fail2Ban bantime aumentado**: De 1 hora a 24 horas por defecto, configurable vía variable de entorno `KALIDEFENDER_BANTIME`.

### 🟡 IMPORTANTE - Robustez

#### Añadido
- **Sistema de Backup/Restore**: Comandos `backup`, `restore` y `list-backups` para guardar y restaurar configuraciones.
- **Validación de dependencias**: Función `check_system_dependencies()` verifica apt, iptables, ip6tables, systemctl y curl antes de instalar.
- **Manejo robusto de errores en detect_c2_subnet()**: Validación mejorada de JSON para ZeroTier, manejo de respuestas vacías o mal formadas.
- **Variables con comillas**: Todas las variables críticas ahora están correctamente entrecomilladas para manejar rutas con espacios.
- **Output JSON**: Comando `status --json` para parsing programático.

#### Mejorado
- **Detección de C2**: Mejor parsing de subnets ZeroTier con expresiones regulares más robustas.
- **Logging en Python**: Manejo seguro de permisos para archivos de log, fallback a consola si no hay permisos.
- **Timeouts en comandos**: Los comandos en Python ahora tienen timeout de 30 segundos.
- **Help mejorado**: Documentación de variables de entorno y ejemplos de uso.

### 🟢 FUNCIONAL - Nuevas Características

#### Añadido
- **Puertos configurables**: Variables de entorno `KALIDEFENDER_TCP_PORTS` y `KALIDEFENDER_UDP_PORTS`.
- **Configuración de Fail2Ban personalizable**: Variables `KALIDEFENDER_BANTIME` y `KALIDEFENDER_MAXRETRY`.
- **Comando list-backups**: Lista todos los backups disponibles.
- **Acción 'full' en hybrid_net_manager.py**: Estado completo con auditoría de seguridad.
- **Verbose mode**: Opción `-v/--verbose` en hybrid_net_manager.py para debugging.

#### Mejorado
- **Status command**: Información más detallada y formateo mejorado.
- **Python type hints**: Uso de `Dict[str, Any]` y tipos más específicos.
- **Excepciones en Python**: Manejo específico para `TimeoutExpired`, `FileNotFoundError`, `JSONDecodeError`.
- **Documentación inline**: Docstrings mejorados en todas las funciones.

### 📚 DOCUMENTACIÓN

#### Actualizado
- Versión actualizada a 5.0.0 en todos los archivos.
- Ejemplos de uso de nuevas características.
- Matriz de compatibilidad implícita en requisitos.

### 🔄 MIGRACIÓN desde v4.x

#### Cambios Importantes
1. **Tráfico web directo eliminado en modo Stealth**: Si necesitabas acceso directo a HTTP/HTTPS sin Tor, deberás usar modo Attack.
2. **Fail2Ban bantime más largo**: Por defecto ahora es 24h. Para cambiar: `KALIDEFENDER_BANTIME=1h kalidefender.sh install`
3. **Nuevos comandos disponibles**: `backup`, `restore`, `list-backups`, `status --json`

#### Backward Compatibility
- Todos los comandos existentes siguen funcionando.
- Puertos por defecto no han cambiado.
- Configuraciones existentes son compatibles.

---

## [4.2.1] - 2025-12-11

### Añadido
- Sistema dual Stealth/Attack con cambio rápido entre modos.
- Integración completa con Tailscale y ZeroTier para redes C2 seguras.
- Perfiles de AppArmor para aislar Metasploit del sistema host.
- Aleatorización automática de direcciones MAC en conexiones WiFi.
- Configuración de Fail2Ban personalizada para bloquear escaneos.
- Redirección de DNS a Tor en modo Stealth (puerto 5353).
- Comando `status` para verificar el estado de seguridad del sistema.
- Comando `toggle` para alternar rápidamente entre modos.
- Documentación completa: README, INSTALL, GUIDE, UNINSTALL.
- Script de desinstalación limpia que restaura el sistema al estado original.

### Mejorado
- Reglas de firewall optimizadas con políticas DROP por defecto.
- Logging detallado en `/var/log/kalidefender.log`.
- Manejo de errores mejorado con `set -euo pipefail`.
- Servicio systemd para iniciar KaliDefender automáticamente al arranque.

### Seguridad
- Los puertos de ataque solo son accesibles desde la red C2 privada.
- Metasploit no puede acceder a archivos sensibles del sistema (shadow, ssh keys, etc.).
- DNS inmutable en modo Stealth para evitar fugas.

---

## [Unreleased]

### Planificado
- Soporte completo para IPv6 (ip6tables) en ambos modos.
- Integración con Wireguard nativo.
- Dashboard web para gestión visual del sistema.
- Soporte para múltiples interfaces de red simultáneas.
- Integración con sistemas SIEM para monitoreo centralizado.
- Tests automatizados con pytest para el módulo Python.
- Empaquetado DEB para instalación simplificada.

---

[5.0.0]: https://github.com/tu-usuario/KaliDefender/releases/tag/v5.0.0
[4.2.1]: https://github.com/tu-usuario/KaliDefender/releases/tag/v4.2.1

