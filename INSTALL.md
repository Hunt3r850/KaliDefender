# 📥 Guía de Instalación de KaliDefender v4.2

Esta guía te ayudará a instalar KaliDefender en tu sistema Kali Linux paso a paso.

---

## 1. Requisitos Previos

Antes de comenzar, asegúrate de cumplir con los siguientes requisitos:

- **Sistema Operativo**: Kali Linux 2023.1 o una versión más reciente.
- **Privilegios**: Necesitarás acceso `root` o `sudo` para ejecutar los comandos de instalación.
- **Conexión a Internet**: Se requiere una conexión a Internet activa para descargar los paquetes necesarios.
- **Git**: Debes tener `git` instalado. Si no lo tienes, instálalo con:
  ```bash
  sudo apt update && sudo apt install git -y
  ```

---

## 2. Pasos de Instalación

Sigue estos pasos para instalar y configurar KaliDefender en tu sistema.

### Paso 2.1: Clonar el Repositorio

Primero, clona el repositorio oficial de KaliDefender desde GitHub:

```bash
git clone https://github.com/tu-usuario/KaliDefender.git
cd KaliDefender
```

### Paso 2.2: Dar Permisos de Ejecución

El script principal necesita permisos de ejecución. Asígnaselos con el siguiente comando:

```bash
chmod +x kalidefender.sh
```

### Paso 2.3: Ejecutar el Instalador

Ahora, ejecuta el script de instalación con privilegios de superusuario:

```bash
sudo ./kalidefender.sh install
```

El instalador se encargará de:

- Instalar todas las dependencias necesarias (Tor, AppArmor, Fail2Ban, etc.).
- Configurar los perfiles de AppArmor para Metasploit.
- Crear las reglas de firewall iniciales.
- Configurar el servicio `systemd` para KaliDefender.
- Preguntarte por la configuración de la red C2 segura.

### Paso 2.4: Configurar la Red C2 Segura (Recomendado)

Durante la instalación, se te ofrecerá la opción de configurar una red privada para tu canal de Comando y Control (C2). Esto es **altamente recomendado** para evitar exponer los puertos de Metasploit a Internet.

Las opciones son:

- **Tailscale (Recomendado)**: Es la opción más sencilla y rápida. El script instalará Tailscale automáticamente. Después de la instalación, solo necesitas autenticarte:
  ```bash
  sudo tailscale up
  ```

- **ZeroTier**: Ofrece más control y es ideal para configuraciones avanzadas. Deberás crear una red en [my.zerotier.com](https://my.zerotier.com/) y luego unir tu máquina a ella:
  ```bash
  sudo zerotier-cli join TU_NETWORK_ID
  ```

- **No configurar**: Si eliges no configurar una red C2, los puertos de ataque serán accesibles desde cualquier red. **Esto es muy arriesgado en redes públicas.**

---

## 3. Verificación Post-Instalación

Una vez finalizada la instalación, puedes verificar que todo esté funcionando correctamente con el comando `status`:

```bash
sudo kalidefender.sh status
```

La salida debería mostrar algo similar a esto:

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

## 4. Primeros Pasos

Por defecto, KaliDefender inicia en **modo Stealth**. Este es el modo recomendado para todas las actividades que no sean de pentesting activo.

- Para navegar, investigar o actualizar tu sistema, mantente en `stealth`.
- Antes de lanzar un ataque o un handler de Metasploit, cambia a `attack`.
- Cuando termines, vuelve siempre a `stealth`.

```bash
# Cambiar a modo ataque
sudo kalidefender.sh attack

# Volver a modo sigiloso
sudo kalidefender.sh stealth
```

¡Y eso es todo! Ya tienes KaliDefender instalado y funcionando. Para una guía más detallada sobre todas las funcionalidades, consulta la [Guía de Uso Completa (GUIDE.md)](GUIDE.md).
