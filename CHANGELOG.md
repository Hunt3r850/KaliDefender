# Changelog

Todos los cambios notables en este proyecto serán documentados en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es/1.0.0/),
y este proyecto adhiere al [Versionado Semántico](https://semver.org/lang/es/).

---

## [4.2.0] - 2025-12-11

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
- Soporte para Wireguard nativo.
- Integración con Cobalt Strike.
- Perfiles de AppArmor para más herramientas de pentesting.
- Dashboard web para gestión visual del sistema.
- Soporte para múltiples interfaces de red.
- Integración con sistemas SIEM para monitoreo centralizado.

---

[4.2.0]: https://github.com/tu-usuario/KaliDefender/releases/tag/v4.2.0
