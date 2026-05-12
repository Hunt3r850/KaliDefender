# 📋 Changelog - KaliDefender

Todos los cambios notables en este proyecto serán documentados en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/),
y este proyecto adhiere a [Semantic Versioning](https://semver.org/lang/es/).

---

## [6.0.0] - 2024-01-15

### 🎉 Añadido
- **Arquitectura Modular:** Código completamente reestructurado en módulos independientes
- **Dashboard Web Seguro:** API REST con autenticación Bearer Token y HTTPS
- **Sistema de Backups:** Backup y restauración completa del estado del sistema
- **Firewall Atómico:** Aplicación de reglas mediante `iptables-restore` para cambios instantáneos
- **Logging Estructurado:** Soporte para formato JSON (integración SIEM)
- **Validación de Entrada:** Whitelist de acciones permitidas en el dashboard
- **Script de Desinstalación:** `kalidefender_uninstall.sh` para limpieza completa

### 🔧 Mejorado
- **Detección de C2:** Más robusta con mejor parsing de ZeroTier y Tailscale
- **Manejo de Errores:** Verificación de dependencias y servicios mejorada
- **Configuración DNS:** Manejo más seguro de `/etc/resolv.conf` inmutable
- **Estado Centralizado:** Archivos de estado en lugar de variables globales
- **Documentación:** README, GUIDE, INSTALL y UNINSTALL completos y profesionales

### 🔒 Seguridad
- Dashboard solo escucha en localhost (127.0.0.1)
- Autenticación por token en todas las llamadas API
- Headers de seguridad HTTP (X-Content-Type-Options, Cache-Control)
- Certificados SSL autofirmados generados automáticamente

### 🗑️ Eliminado
- Funciones mockup de SIEM y Cobalt Strike (serán reimplementadas como plugins)
- Código duplicado y no utilizado
- Variables globales innecesarias

### 📝 Documentación
- README.md completamente reescrito
- GUIDE.md con guía de uso detallada
- INSTALL.md con instrucciones paso a paso
- UNINSTALL.md para desinstalación limpia
- CHANGELOG.md (este archivo)

---

## [5.1.0] - 2023-12-01

### Añadido
- Soporte para múltiples interfaces de red
- Dashboard web experimental
- Integración WireGuard
- Plantillas para Cobalt Strike redirector

### Mejorado
- Configuración de Fail2Ban adaptativa
- Detección de redes C2 (Tailscale/ZeroTier)
- Logging del sistema

---

## [5.0.0] - 2023-11-15

### Añadido
- Lanzamiento inicial público
- Modo Stealth con Tor TransProxy
- Modo Attack con puertos configurables
- Perfiles AppArmor para herramientas de pentesting
- Integración básica con Fail2Ban

---

## [4.0.0] - 2023-10-01

### Añadido
- Versión beta privada
- Firewall base con iptables
- Configuración de Tor
- Aleatorización de MAC

---

## [0.1.0] - 2023-09-01

### Añadido
- Concepto inicial y prototipo
- Script monolítico básico