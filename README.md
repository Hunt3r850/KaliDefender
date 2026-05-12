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
  - [Modo Stealth: El Fantasma Digital](#modo-stealth-el-fantasma-digital)
  - [Modo Attack: El Arsenal Preparado](#modo-attack-el-arsenal-preparado)
  - [Dashboard Web Seguro](#dashboard-web-seguro)
  - [Sistema de Backups](#sistema-de-backups)
  - [Integración con Redes C2](#integración-con-redes-c2)
- [⚙️ Configuración Avanzada](#️-configuración-avanzada)
- [🔧 Solución de Problemas](#-solución-de-problemas)
- [🤝 Contribuir](#-contribuir)
- [📜 Licencia y Responsabilidad](#-licencia-y-responsabilidad)
- [🙏 Agradecimientos](#-agradecimientos)

---

## 🎯 Visión General

### El Problema que Resuelve

En operaciones de seguridad ofensiva, el contexto es crítico:

- **Reconocimiento e Investigación:** Necesitas navegar de forma anónima, sin exponer tu identidad ni tus herramientas.
- **Ataque Activo:** Necesitas tener puertos abiertos para recibir conexiones reversas, alojar payloads o comandar implantes.

Gestionar manualmente reglas de firewall, configuración de Tor, y asegurarte de no cometer errores de OPSEC es tedioso y propenso a fallos. **KaliDefender automatiza esta dualidad de forma segura y profesional.**

### La Solución

KaliDefender te permite cambiar instantáneamente entre dos perfiles de red completamente diferentes:

| Característica | Modo Stealth 🥷 | Modo Attack ⚔️ |
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

```bash
sudo kalidefender stealth