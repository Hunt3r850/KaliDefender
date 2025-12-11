# 🧹 Guía de Desinstalación de KaliDefender

Esta guía te mostrará cómo desinstalar KaliDefender de tu sistema de forma segura y completa, restaurando la configuración de red original.

---

## 1. Requisitos Previos

- **Privilegios**: Necesitarás acceso `root` o `sudo` para ejecutar el script de desinstalación.

---

## 2. Pasos de Desinstalación

### Paso 2.1: Obtener el Script de Desinstalación

Si ya tienes el repositorio de KaliDefender clonado, navega hasta su directorio:

```bash
cd KaliDefender
```

Si no lo tienes, clónalo:

```bash
git clone https://github.com/tu-usuario/KaliDefender.git
cd KaliDefender
```

### Paso 2.2: Dar Permisos de Ejecución

El script de desinstalación necesita permisos de ejecución:

```bash
chmod +x kalidefender_uninstall.sh
```

### Paso 2.3: Ejecutar el Desinstalador

Ejecuta el script con privilegios de superusuario:

```bash
sudo ./kalidefender_uninstall.sh
```

El script realizará las siguientes acciones:

- ✅ **Restaurar el firewall**: Eliminará todas las reglas de `iptables` creadas por KaliDefender y restaurará las políticas por defecto a `ACCEPT`.
- ✅ **Restaurar DNS**: Desactivará la inmutabilidad del archivo `/etc/resolv.conf` y lo restaurará a un servidor DNS público (8.8.8.8).
- ✅ **Eliminar perfiles de AppArmor**: Desactivará y eliminará los perfiles de AppArmor para Metasploit.
- ✅ **Eliminar configuración de Fail2Ban**: Quitará los filtros y jaulas personalizadas para KaliDefender.
- ✅ **Eliminar el servicio systemd**: Desactivará y eliminará el servicio `kalidefender.service`.
- ✅ **Eliminar archivos de configuración**: Borrará el directorio `/etc/kalidefender/` y los logs.
- ✅ **Restaurar configuración de MAC Aleatoria**: Eliminará la configuración de NetworkManager para la aleatorización de la MAC.

---

## 3. ¿Qué NO se elimina?

El script de desinstalación **NO** elimina los siguientes paquetes, ya que podrías estar usándolos para otros fines:

- ❌ Tor
- ❌ Tailscale
- ❌ ZeroTier
- ❌ Fail2Ban (solo se elimina la configuración personalizada)
- ❌ AppArmor (solo se eliminan los perfiles de Metasploit)

Si deseas eliminar estos paquetes, puedes hacerlo manualmente con `apt purge`:

```bash
sudo apt purge tor tailscale zerotier-one fail2ban apparmor
```

---

## 4. Verificación Post-Desinstalación

Después de ejecutar el script, puedes verificar que el sistema ha vuelto a su estado normal:

```bash
# Verificar que las reglas de iptables estén limpias y las políticas en ACCEPT
sudo iptables -L

# Verificar que el servicio ya no exista
systemctl list-unit-files | grep kalidefender

# Verificar que los perfiles de AppArmor para Metasploit ya no estén cargados
sudo aa-status | grep msf
```

Si todos estos comandos no muestran ninguna configuración relacionada con KaliDefender, la desinstalación ha sido exitosa.

Si tienes algún problema de red después de la desinstalación, un reinicio del servicio de red o del sistema debería solucionarlo:

```bash
sudo systemctl restart NetworkManager
```
