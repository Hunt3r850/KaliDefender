<div align="center">
  <img src="https://img.shields.io/badge/KaliDefender-v6.0.0-red?style=for-the-badge&logo=kali-linux&logoColor=white" alt="KaliDefender Banner"/>
  <br/>
  <img src="https://img.shields.io/badge/Platform-Kali%20Linux-blueviolet?style=flat-square&logo=linux&logoColor=white" alt="Platform"/>
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=flat-square" alt="License"/>
  <img src="https://img.shields.io/badge/Bash-5.0%2B-green?style=flat-square&logo=gnu-bash&logoColor=white" alt="Bash"/>
  <img src="https://img.shields.io/badge/Python-3.8%2B-blue?style=flat-square&logo=python&logoColor=white" alt="Python"/>
  <img src="https://img.shields.io/badge/Security-Paranoid-red?style=flat-square" alt="Security"/>
  <br/><br/>
  
  <h1>🛡️ KaliDefender v6.0.0</h1>
  <h3>Sistema Modular de Perfilado de Red para Operaciones de Seguridad Ofensiva</h3>
  
  <p>
    <strong>Transforma tu Kali Linux en una plataforma de operaciones con doble personalidad:</strong><br/>
    Un fantasma digital invisible para reconocimiento ➡️ Un arsenal preparado para el ataque<br/>
    Todo con un solo comando y sin comprometer tu OPSEC.
  </p>
</div>

---

## 📑 Tabla de Contenidos

- [🎯 Visión General](#-visión-general)
- [✨ Características Principales](#-características-principales)
- [🏗️ Arquitectura del Sistema](#️-arquitectura-del-sistema)
- [📦 Instalación](#-instalación)
- [🚀 Guía de Uso Rápido](#-guía-de-uso-rápido)
- [📖 Documentación Completa](#-documentación-completa)
- [⚙️ Configuración Avanzada](#️-configuración-avanzada)
- [🔧 Solución de Problemas](#-solución-de-problemas)
- [🤝 Contribuir](#-contribuir)
- [📜 Licencia y Responsabilidad](#-licencia-y-responsabilidad)

---

## 🎯 Visión General

### El Problema que Resuelve

En operaciones de seguridad ofensiva, el contexto es crítico. Necesitas dos personalidades de red completamente diferentes según la fase de la operación:

- **Fase de Reconocimiento:** Debes ser invisible, todo el tráfico anónimo, sin puertos expuestos.
- **Fase de Ataque Activo:** Necesitas puertos abiertos para recibir conexiones, pero sin exponerte a Internet accidentalmente.

### La Solución

**KaliDefender** te permite cambiar instantáneamente entre dos perfiles de red completamente diferentes con un solo comando:

| Característica | 🥷 Modo Stealth | ⚔️ Modo Attack |
|---------------|-----------------|-----------------|
| **Tráfico de salida** | 100% a través de Tor | Directo (controlado por usuario) |
| **Puertos de entrada** | Todos cerrados | Abiertos selectivamente |
| **Resolución DNS** | A través de Tor (localhost) | DNS público (Cloudflare/Google) |
| **Red C2 privada** | No aplica | Detectada y usada automáticamente |
| **Exposición a Internet** | Invisible | Controlada y consciente |
| **Caso de uso** | OSINT, investigación, navegación anónima | Pentesting, red team, C2 |

---

## ✨ Características Principales

### 🔷 Modo Stealth - Privacidad Total
- **TransProxy de Tor:** Todo el tráfico TCP es redirigido automáticamente a través de Tor usando TransPort (9040)
- **DNS sobre Tor:** Todas las consultas DNS son redirigidas al resolver de Tor (DNSPort 5353)
- **DNS Inmutable:** Bloquea `/etc/resolv.conf` con atributo inmutable (`chattr +i`)
- **Aislamiento de Procesos:** Solo el proceso Tor (usuario `debian-tor`) puede hacer conexiones directas
- **Sin Fugas:** Todo otro tráfico de salida es bloqueado por política DROP predeterminada

### 🔴 Modo Attack - Arsenal Controlado
- **Apertura Selectiva de Puertos:** Expón solo los puertos que necesitas (configurables)
- **Detección Automática de C2:** Reconoce si estás en una red privada (Tailscale/ZeroTier)
- **Restricción Inteligente:** Si hay C2, los puertos solo se abren a esa red privada
- **Advertencia Explícita:** Si no hay C2, te advierte antes de exponer puertos a Internet
- **Fail2Ban Integrado:** Protege tus puertos expuestos de ataques de fuerza bruta

### 🖥️ Dashboard Web Seguro
- **API REST segura** con autenticación por token Bearer
- **HTTPS** con certificado autofirmado generado automáticamente
- **Solo localhost:** El dashboard solo escucha en `127.0.0.1` por seguridad
- **Whitelist de acciones:** Solo permite comandos predefinidos (stealth, attack, status)
- **Endpoints:**
  - `GET /api/status` - Obtener estado del sistema
  - `POST /api/action` - Cambiar modo de operación

### 📦 Sistema de Backups
- Backup completo de reglas iptables (IPv4 e IPv6)
- Respaldo del estado del sistema
- Copia de configuraciones críticas (Tor, DNS)
- Restauración atómica y verificada

### 🛡️ Seguridad Adicional
- **AppArmor:** Perfiles de seguridad para herramientas de pentesting
- **Fail2Ban:** Baneo automático de IPs que intenten conexiones no autorizadas
- **Logging estructurado:** Soporte para formato JSON (integración SIEM)
- **Aplicación atómica de firewall:** Usa `iptables-restore` para cambios instantáneos
- **Validación de entrada:** Whitelist de acciones en dashboard y CLI

---

## 🏗️ Arquitectura del Sistema

### Estructura de Archivos del Proyecto

KaliDefender/
|
├── README.md # Documentación principal
|
├── CHANGELOG.md # Historial de cambios
|
├── GUIDE.md # Guía de uso detallada
|
├── INSTALL.md # Instrucciones de instalación
|
├── UNINSTALL.md # Desinstalación completa
|
├── LICENSE # Licencia MIT
|
├── kalidefender.sh # Script principal (CLI)
|
├── kalidefender_uninstall.sh # Script de desinstalación
|
└── hybrid_net_manager.py # Dashboard web (Python)

###  Estructura en el Sistema

/etc/kalidefender/ # Directorio principal de configuración

├── config/

│ └── defaults.conf # Configuración centralizada

├── state/ # Estado del sistema en tiempo real

│ ├── mode # Modo actual (stealth/attack)

│ ├── c2_provider # Proveedor C2 detectado

│ └── c2_subnet # Subred C2

├── backups/ # Backups del sistema

│ └── kalidefender_backup_YYYYMMDD_HHMMSS/

│ ├── iptables.rules

│ ├── ip6tables.rules

│ ├── state/

│ ├── resolv.conf

│ └── torrc

├── certs/ # Certificados SSL para dashboard

│ ├── dashboard.pem

│ └── dashboard.key

└── logs/

└── kalidefender.log # Log estructurado del sistema

/usr/local/bin/kalidefender # Ejecutable principal

/etc/systemd/system/
└── kalidefender.service # Servicio systemd para auto-inicio


### Principios de Diseño

1. **Modularidad:** Cada función es independiente y testeable
2. **Atomicidad:** Los cambios de firewall son instantáneos (iptables-restore)
3. **Idempotencia:** Ejecutar el mismo comando múltiples veces produce el mismo resultado
4. **Fail-Safe:** Si algo falla, el sistema vuelve a un estado seguro conocido
5. **Trazabilidad:** Cada acción queda registrada en logs estructurados

---

## 📦 Instalación

### Requisitos Previos

- **Sistema Operativo:** Kali Linux 2023.1 o superior
- **Arquitectura:** x86_64 / amd64
- **RAM:** 512 MB mínimo (2 GB recomendado)
- **Disco:** 100 MB libres (500 MB recomendado)
- **Privilegios:** Acceso root (sudo)
- **Red:** Conexión a Internet para instalación inicial

### Instalación Rápida (3 Pasos)

```bash
# 1. Clonar el repositorio
git clone https://github.com/Hunt3r850/KaliDefender.git
cd KaliDefender

# 2. Dar permisos de ejecución a los scripts
chmod +x *.sh

# 3. Instalar (requiere sudo)
sudo ./kalidefender.sh install

¡Listo! KaliDefender está activo en Modo Stealth por defecto.

¿Qué hace la instalación?

✅ Verifica que el sistema sea compatible (Kali Linux, dependencias)

✅ Instala todas las dependencias necesarias (Tor, Fail2Ban, AppArmor, etc.)

✅ Configura Tor con TransProxy (puerto 9040) y DNSPort (puerto 5353)

✅ Configura Fail2Ban con reglas personalizadas para KaliDefender

✅ Instala perfiles de AppArmor para herramientas de pentesting

✅ Crea el servicio systemd para inicio automático

✅ Configura DNS inmutable en modo stealth

✅ Activa el Modo Stealth por defecto

✅ Copia el ejecutable a /usr/local/bin/kalidefender

Instalación Personalizada con Variables de Entorno

# Personalizar puertos de ataque
export KALIDEFENDER_TCP_PORTS="22,443,1337,4444,8080"
export KALIDEFENDER_UDP_PORTS="53,1194,51820"

# Personalizar Fail2Ban (más agresivo)
export KALIDEFENDER_BANTIME="48h"
export KALIDEFENDER_MAXRETRY="5"

# Dashboard en puerto estándar
export KALIDEFENDER_DASHBOARD_PORT="443"
export KALIDEFENDER_AUTH_TOKEN="mi-token-seguro-2024"

# Logs en JSON para integración SIEM
export KALIDEFENDER_LOG_FORMAT="json"

# Instalar con configuración personalizada
sudo -E ./kalidefender.sh install

Verificar Instalación

# Verificar que el ejecutable existe
which kalidefender
# Output: /usr/local/bin/kalidefender

# Verificar que el servicio está activo
systemctl status kalidefender

# Verificar el modo actual
sudo kalidefender status

# Verificar logs en tiempo real
tail -f /var/log/kalidefender.log
