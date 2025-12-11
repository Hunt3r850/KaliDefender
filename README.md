# 🛡️ KaliDefender v4.2

**Sistema Dual Stealth/Attack para Pentesters Profesionales**

> Privacidad total + C2 seguro + Aislamiento de Metasploit — todo en un solo script.

[![Kali Linux](https://img.shields.io/badge/Kali_Linux-2023+-blue?logo=kali-linux)](https://www.kali.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/Bash-5.0+-orange.svg)](https://www.gnu.org/software/bash/)
[![Security](https://img.shields.io/badge/Security-AppArmor-red.svg)](https://apparmor.net/)

---

## 📖 Descripción

**KaliDefender** transforma tu Kali Linux en una plataforma de red teaming **segura, furtiva y eficaz**. Diseñado para pentesters profesionales que necesitan máxima privacidad durante la fase de reconocimiento y máxima efectividad durante la explotación, sin comprometer la seguridad del sistema operativo.

### Características Principales

- 🥷 **Modo Stealth**: Navegación 100% anónima por Tor, sin fugas DNS
- ⚔️ **Modo Attack**: Handlers de Metasploit accesibles **solo desde tu red privada** (Tailscale/ZeroTier)
- 🛡️ **AppArmor**: Metasploit aislado del sistema (no puede leer `/etc/shadow`, escribir en `/root`, etc.)
- 📡 **MAC Randomization**: Evita tracking físico en redes WiFi
- 🔒 **Fail2Ban + Firewall estricto**: Bloquea escaneos y ataques automatizados
- 🔄 **Toggle rápido**: Cambia de modo en segundos

Optimizado para **ThinkPad X13**, pero compatible con cualquier Kali Linux.

---

## 🚀 Características Detalladas

| Función | Beneficio |
|---------|-----------|
| **Modo Stealth** | Navegación anónima, actualizaciones seguras, DNS sobre Tor |
| **Modo Attack** | C2 evasivo, sin puertos públicos expuestos |
| **Tailscale/ZeroTier integrado** | Comunicación cifrada entre máquinas, bypass de NAT |
| **AppArmor para Metasploit** | Contención post-explotación, protección del sistema |
| **Toggle rápido** | Cambia de modo instantáneamente (`kalidefender.sh toggle`) |
| **Instalación/desinstalación limpia** | Sin rastros en el sistema, reversible al 100% |
| **Fail2Ban personalizado** | Protección contra escaneos de puertos y fuerza bruta |
| **MAC Address Randomization** | Anti-tracking en redes WiFi públicas |

---

## 📥 Instalación

### Requisitos Previos

- **Sistema Operativo**: Kali Linux 2023.1 o superior
- **Privilegios**: Acceso root o sudo
- **Conexión**: Internet activa durante la instalación

### Instalación Rápida

```bash
git clone https://github.com/Hunt3r850/KaliDefender.git
cd KaliDefender
chmod +x kalidefender.sh
sudo ./kalidefender.sh install
```

Durante la instalación:
- Se te preguntará si deseas usar **Tailscale** o **ZeroTier** para el canal C2 seguro
- El sistema inicia en **modo Stealth** por defecto
- Se configurarán automáticamente: AppArmor, Tor, Fail2Ban, iptables

> 📖 **Guía detallada**: [INSTALL.md](INSTALL.md)

---

## 🧪 Uso Básico

### Comandos Principales

```bash
# Activar modo privacidad (navegación anónima)
sudo kalidefender.sh stealth

# Activar modo pentesting (C2 seguro)
sudo kalidefender.sh attack

# Alternar entre modos
sudo kalidefender.sh toggle

# Ver estado del sistema
sudo kalidefender.sh status

# Mostrar ayuda
sudo kalidefender.sh help
```

### Flujo de Trabajo Recomendado

1. **Fase de Reconocimiento**: Mantén el sistema en **modo Stealth**
   ```bash
   sudo kalidefender.sh stealth
   ```

2. **Fase de Explotación**: Cambia a **modo Attack**
   ```bash
   sudo kalidefender.sh attack
   ```

3. **Post-Engagement**: Vuelve a **modo Stealth**
   ```bash
   sudo kalidefender.sh stealth
   ```

> 📚 **Guía completa de uso**: [GUIDE.md](GUIDE.md)

---

## 🔒 Seguridad y Privacidad

### Modo Stealth

En este modo, tu sistema opera con máxima privacidad:

- ✅ Todo el tráfico DNS redirigido a Tor (puerto 5353)
- ✅ Solo HTTP/HTTPS permitido para navegación
- ✅ Sin puertos de entrada abiertos
- ✅ `/etc/resolv.conf` inmutable
- ✅ MAC address randomizada en cada conexión WiFi
- ✅ Protección contra fugas DNS

### Modo Attack

En este modo, tu sistema está optimizado para pentesting seguro:

- 🔒 Puertos de ataque **solo accesibles desde tu red privada** (Tailscale/ZeroTier)
- 🛡️ Metasploit aislado con AppArmor (no puede acceder a archivos sensibles)
- 🌐 Salida directa a Internet (necesario para exploits)
- ⚠️ **Advertencia**: No navegues en este modo, tu IP es visible

### AppArmor para Metasploit

KaliDefender incluye perfiles de AppArmor que restringen las capacidades de Metasploit:

- ❌ No puede leer `/etc/shadow`, `/root/.ssh/`, credenciales del sistema
- ❌ No puede escribir en directorios sensibles (`/root/`, `/etc/`)
- ❌ No puede acceder a Docker, systemd, o recursos del kernel
- ✅ Puede operar normalmente para pentesting

---

## 🌐 Red C2 Segura

### ¿Por qué usar una red privada?

- **Evita exponer puertos públicos** (4444, 5555, etc.) a Internet
- **El tráfico parece legítimo** (WireGuard cifrado)
- **Funciona tras NAT/firewalls** corporativos
- **Comunicación cifrada** entre tus máquinas de ataque

### Opciones Disponibles

#### Tailscale (Recomendado)

- Instalación automática desde el script
- Configuración simple y rápida
- Panel de administración web: https://login.tailscale.com/admin/machines

```bash
# Después de la instalación
sudo tailscale up
```

#### ZeroTier

- Mayor control sobre la red
- Ideal para equipos avanzados
- Crea una red en: https://my.zerotier.com/

```bash
# Después de la instalación
sudo zerotier-cli join TU_NETWORK_ID
```

---

## 🧹 Desinstalación

Para eliminar completamente KaliDefender de tu sistema:

```bash
chmod +x kalidefender_uninstall.sh
sudo ./kalidefender_uninstall.sh
```

El script de desinstalación:
- ✅ Restaura reglas de firewall originales
- ✅ Elimina perfiles de AppArmor
- ✅ Restaura configuración de DNS
- ✅ Elimina el servicio systemd
- ✅ Limpia todos los archivos de configuración

> 📖 **Detalles completos**: [UNINSTALL.md](UNINSTALL.md)

---

## 📊 Verificación de Estado

Ejecuta el comando de estado para ver información detallada:

```bash
sudo kalidefender.sh status
```

**Salida de ejemplo:**

```
📊 ESTADO KALIDEFENDER v4.2
==========================
Modo: stealth

🛡️ AppArmor para Metasploit:
  ✅ Activo

🌐 Red C2 Privada:
  ✅ Tailscale activo - IP: 100.64.1.2

🔌 Puertos INPUT abiertos:
  Ninguno

📡 Test de conectividad:
  ✅ Internet OK
```

---

## ⚠️ Advertencias y Buenas Prácticas

### ⛔ NO Hacer

- ❌ **No uses modo Attack en redes públicas** sin red privada configurada
- ❌ **No navegues en modo Attack** — tu IP real es visible
- ❌ **No uses este software en sistemas sin autorización**

### ✅ Hacer

- ✅ **Siempre vuelve a Stealth** tras terminar un pentest
- ✅ **Actualiza Tailscale/ZeroTier** regularmente
- ✅ **Revisa logs**: `tail -f /var/log/kalidefender.log`
- ✅ **Prueba fugas DNS**: visita https://dnsleaktest.com en modo Stealth
- ✅ **Verifica AppArmor**: `sudo aa-status | grep msf`

---

## 🐛 Solución de Problemas

### Problema: Sin conexión a Internet en modo Stealth

```bash
# Verificar que Tor esté corriendo
sudo systemctl status tor

# Reiniciar Tor
sudo systemctl restart tor

# Verificar DNS
cat /etc/resolv.conf
```

### Problema: No puedo conectar a Metasploit en modo Attack

```bash
# Verificar tu IP de red privada
sudo kalidefender.sh status

# Asegúrate de usar la IP correcta en LHOST
# Tailscale: 100.64.x.x
# ZeroTier: 192.168.19x.x
```

### Problema: AppArmor bloquea operaciones legítimas

```bash
# Ver logs de AppArmor
sudo dmesg | grep -i apparmor | tail -20

# Temporalmente desactivar AppArmor para Metasploit
sudo aa-complain /usr/bin/msfconsole
```

---

## 📚 Documentación Adicional

- [INSTALL.md](INSTALL.md) - Guía de instalación paso a paso
- [GUIDE.md](GUIDE.md) - Documentación técnica completa
- [UNINSTALL.md](UNINSTALL.md) - Guía de desinstalación
- [CHANGELOG.md](CHANGELOG.md) - Historial de versiones

---

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

---

## 📜 Licencia

Este proyecto está licenciado bajo la Licencia MIT. Ver el archivo [LICENSE](LICENSE) para más detalles.

---

## ⚖️ Disclaimer Legal

**Este software está diseñado exclusivamente para pruebas de seguridad autorizadas y fines educativos.**

- ⚠️ El uso de este software en sistemas sin permiso explícito es **ilegal**
- ⚠️ El autor no se hace responsable del uso indebido de esta herramienta
- ⚠️ Siempre obtén autorización por escrito antes de realizar pruebas de penetración
- ⚠️ Conoce y respeta las leyes locales sobre seguridad informática

---

## 👤 Autor

Lic. Ahmed Alfonso

- GitHub: [@Hunt3r850](https://github.com/Hunt3r850)
- Email: aalfonso850@yahoo.com

---

## 🙏 Agradecimientos

- [Kali Linux](https://www.kali.org/) - La distribución de pentesting por excelencia
- [Tor Project](https://www.torproject.org/) - Por la privacidad en línea
- [Tailscale](https://tailscale.com/) - Por simplificar las VPN
- [AppArmor](https://apparmor.net/) - Por la seguridad a nivel de aplicación
- [Metasploit Framework](https://www.metasploit.com/) - Por la herramienta de pentesting más completa

---

## 📈 Roadmap

- [ ] Soporte para Wireguard nativo
- [ ] Integración con Cobalt Strike
- [ ] Perfiles de AppArmor para más herramientas
- [ ] Dashboard web para gestión
- [ ] Soporte para múltiples interfaces de red
- [ ] Integración con SIEM

---

> 💡 **¿Problemas o sugerencias?** Abre un [issue](https://github.com/Hunt3r850/KaliDefender/issues) o consulta los logs en `/var/log/kalidefender.log`

---

**⭐ Si este proyecto te resulta útil, considera darle una estrella en GitHub**
