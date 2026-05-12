<div align="center">
  <img src="https://via.placeholder.com/150/FF0000/FFFFFF?text=KaliDefender" alt="KaliDefender Shield" width="150"/>
  <h1>🛡️ KaliDefender v5.1.0</h1>
  <p>
    <strong>Sistema de Perfilado de Red Dual para el Pentester Moderno.</strong><br>
    Alterna al instante entre un modo Stealth (privacidad total a través de Tor) y un modo Attack (exposición controlada para C2 y pentesting), todo desde una interfaz unificada.
  </p>
  <br/>
  <p>
    <img src="https://img.shields.io/badge/platform-Kali%20Linux-blueviolet" alt="Platform"/>
    <img src="https://img.shields.io/github/license/Hunt3r850/KaliDefender" alt="License MIT"/>
    <img src="https://img.shields.io/badge/version-5.1.0--RC-blue" alt="Version"/>
    <img src="https://img.shields.io/badge/security-paranoid-red" alt="Security Level"/>
  </p>
</div>

---

## 💡 Filosofía: Seguridad Operacional (OPSEC) a un Comando de Distancia

En las operaciones de red, el contexto lo es todo. La misma máquina que se usa para navegar de forma anónima e investigar (Modo Stealth) no debería estar expuesta con puertos abiertos para un ataque activo (Modo Attack). KaliDefender resuelve esta dualidad permitiéndote cambiar el comportamiento de red de tu sistema de forma instantánea y segura, sin tener que gestionar decenas de reglas de firewall manualmente.

## ✨ Características Clave

### 🔷 Modo Stealth: El Fantasma Digital
*   **Tunelización Forzada por Tor:** Todo el tráfico TCP y las peticiones DNS son redirigidos de forma transparente a través de la red Tor. Sin fugas.
*   **DNS Inmutable:** Bloquea y sella tu archivo `/etc/resolv.conf` para prevenir cualquier fuga de DNS.
*   **Aislamiento de Tráfico:** Niega cualquier conexión de salida directa, garantizando que solo el tráfico del proceso Tor pueda salir a Internet.

### 🔴 Modo Attack: El Arsenal Preparado
*   **Apertura Selectiva de Puertos:** Expón tus herramientas de pentesting (Metasploit, Empire, servidores web) en los puertos que definas.
*   **Enlace C2 Inteligente:** Detecta automáticamente tu red privada (Tailscale o ZeroTier) y restringe la exposición de los puertos de ataque **solo a esa red privada**, nunca a Internet de forma accidental.
*   **Fortalecimiento de Herramientas:** Integra perfiles de AppArmor para herramientas comunes como `nmap` y `msfconsole`, limitando el alcance de posibles exploits dirigidos a tu propio arsenal.

### 🧩 Funcionalidades Adicionales
*   **Dashboard Web (Experimental):** Una API y panel web para monitorizar y cambiar el modo de la máquina de forma remota.
*   **Fail2Ban Adaptativo:** Monitoriza los intentos de conexión rechazados y banea automáticamente la IP del atacante.
*   **Sistema de Backups:** Guarda y restaura configuraciones de firewall y red completas antes de grandes cambios.
*   **WireGuard & Cobalt Strike Integration (Plantillas):** Pre-configuraciones para desplegar rápidamente tu propia VPN y redirectores de C2.

## 🚀 Instalación y Uso Rápido

```bash
# 1. Clonar el repositorio
git clone https://github.com/Hunt3r850/KaliDefender.git
cd KaliDefender

# 2. Instalar (requiere sudo)
sudo chmod +x kalidefender.sh
sudo ./kalidefender.sh install

# La instalación configura todo y activa el Modo Stealth.