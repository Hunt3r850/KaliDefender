# 🛡️ Guía de Uso Completa: KaliDefender v4.2

Esta guía proporciona una descripción técnica detallada de KaliDefender, su filosofía de seguridad y cómo utilizar todas sus funcionalidades de manera efectiva.

---

## 1. Filosofía de Seguridad: Mínimo Privilegio por Contexto

KaliDefender se basa en el principio de **"mínimo privilegio por contexto"**. Esto significa que el sistema aplica diferentes niveles de seguridad según la tarea que estés realizando:

- **Contexto de Reconocimiento (Modo Stealth)**: Durante la fase de investigación, la prioridad es la **privacidad y el sigilo**. En este modo, todo el tráfico se enruta a través de Tor y el firewall es extremadamente restrictivo.

- **Contexto de Explotación (Modo Attack)**: Durante un pentest activo, la prioridad es la **eficacia ofensiva**. En este modo, se permite la salida directa a Internet (necesaria para muchos exploits), pero con dos capas de protección clave:
    1. **Contención de Red**: Los puertos de escucha (handlers) solo son accesibles desde tu red C2 privada (Tailscale/ZeroTier).
    2. **Contención de Sistema**: Metasploit se ejecuta bajo un perfil de AppArmor que limita su acceso al sistema de archivos y a otros recursos críticos.

Este enfoque dual te permite operar de forma segura y efectiva en todas las fases de una prueba de penetración.

---

## 2. Modos de Operación

### 2.1. 🥷 Modo Stealth (Privacidad Total)

Este es el modo por defecto y el recomendado para el 90% del tiempo.

**Características Técnicas:**
- **DNS sobre Tor**: Todas las consultas DNS (puerto 53) se redirigen al puerto DNS de Tor (5353), evitando fugas de DNS.
- **Firewall Restrictivo**: Solo se permite el tráfico de salida para los puertos 80 (HTTP) y 443 (HTTPS) para el usuario `kali` y `root`.
- **Sin Puertos de Entrada**: No se permite ninguna conexión entrante.
- **DNS Inmutable**: El archivo `/etc/resolv.conf` se bloquea para evitar modificaciones accidentales.
- **MAC Aleatoria**: La dirección MAC de tu tarjeta WiFi se cambia en cada nueva conexión para evitar el seguimiento físico.

**Comando para activar:**
```bash
sudo kalidefender.sh stealth
```

> 📌 **Úsalo siempre que navegues, actualices el sistema, realices investigaciones OSINT o no estés atacando activamente un objetivo.**

### 2.2. ⚔️ Modo Attack (Pentesting Seguro)

Este modo está diseñado para la fase de explotación de un pentest.

**Características Técnicas:**
- **Salida Directa a Internet**: El tráfico no pasa por Tor, lo cual es necesario para que muchos exploits y payloads funcionen correctamente.
- **Puertos C2 Privados**: Los puertos de escucha para tus handlers (definidos en la configuración) solo son accesibles desde la subred de tu red C2 (Tailscale o ZeroTier).
- **Aislamiento de Metasploit**: El framework de Metasploit se ejecuta bajo un perfil de AppArmor que le impide acceder a archivos y directorios sensibles del sistema host.
- **DNS Público**: Se utiliza un servidor DNS público y confiable (1.1.1.1).

**Comando para activar:**
```bash
sudo kalidefender.sh attack
```

**Ejemplo de configuración en Metasploit:**

1. Primero, obtén tu IP de la red C2:
   ```bash
   sudo kalidefender.sh status
   # Copia la IP de Tailscale o ZeroTier
   ```

2. Usa esa IP como `LHOST` en tu handler:
   ```ruby
   use exploit/multi/handler
   set PAYLOAD windows/x64/meterpreter/reverse_tcp
   set LHOST 100.64.1.2   # ← Tu IP de Tailscale/ZeroTier
   set LPORT 4444
   exploit -j
   ```

> ⚠️ **¡Nunca navegues por Internet en este modo!** Tu dirección IP real será visible. Este modo es exclusivamente para actividades de pentesting.

---

## 3. Funcionalidades Detalladas

### 3.1. Red C2 Segura (Tailscale / ZeroTier)

Exponer los puertos de un handler de Metasploit directamente a Internet es una mala práctica de seguridad. KaliDefender lo soluciona integrando redes privadas virtuales (VPNs) de malla.

- **¿Por qué es más seguro?**
  - El tráfico de tu C2 viaja a través de un túnel cifrado (WireGuard en el caso de Tailscale).
  - No tienes puertos abiertos en tu IP pública.
  - Funciona detrás de la mayoría de los firewalls y NAT, ya que el cliente establece la conexión saliente.

### 3.2. Aislamiento con AppArmor para Metasploit

Si un atacante explota una vulnerabilidad en el propio Metasploit o en un módulo que estés utilizando, el perfil de AppArmor de KaliDefender limita el daño que puede hacer.

**Protecciones clave:**
- **Lectura de archivos**: Bloquea el acceso a `/etc/shadow`, `~/.ssh/`, `~/.aws/`, `~/.kube/`, etc.
- **Escritura de archivos**: Impide la escritura en directorios del sistema como `/root`, `/etc`, `/usr/bin`.
- **Ejecución**: No permite que Metasploit ejecute comandos que puedan escalar privilegios o interactuar con otros servicios críticos como `systemd` o `docker`.

**Verificación del estado de AppArmor:**
```bash
sudo aa-status | grep -E "msfconsole|msfd"
```

### 3.3. Cambio Rápido de Modo (`toggle`)

Durante un engagement, es posible que necesites cambiar rápidamente entre el modo de ataque y el modo de sigilo. El comando `toggle` está diseñado para esto.

```bash
sudo kalidefender.sh toggle
```

Este comando detecta el modo actual y cambia al otro, aplicando las reglas de firewall y red correspondientes en segundos.

### 3.4. Verificación de Estado (`status`)

El comando `status` es tu panel de control principal para entender el estado de seguridad de tu sistema.

```bash
sudo kalidefender.sh status
```

**Información que proporciona:**
- Modo actual (Stealth o Attack).
- Estado de los perfiles de AppArmor para Metasploit.
- Detección y estado de la red C2 (Tailscale o ZeroTier), incluyendo tu IP privada.
- Lista de puertos de entrada abiertos (deberían ser ninguno en modo Stealth).
- Un test rápido de conectividad a Internet.

---

## 4. Buenas Prácticas de Seguridad

1. **Siempre vuelve a Stealth**: Después de terminar tus actividades de pentesting, ejecuta `sudo kalidefender.sh stealth` para cerrar los puertos y volver a la máxima privacidad.
2. **Actualiza tus herramientas de C2**: Mantén Tailscale y ZeroTier actualizados a sus últimas versiones.
3. **Revisa los logs**: KaliDefender registra todas sus acciones en `/var/log/kalidefender.log`. Si algo no funciona como esperas, este es el primer lugar donde debes mirar.
   ```bash
   tail -f /var/log/kalidefender.log
   ```
4. **Prueba de Fugas de DNS**: En modo Stealth, visita [https://dnsleaktest.com](https://dnsleaktest.com) para verificar que todas tus consultas DNS se están enrutando a través de la red Tor.
