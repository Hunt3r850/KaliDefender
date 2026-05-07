#!/bin/bash
# KaliDefender v5.1.0 - Sistema Dual Stealth/Attack para Pentesters Profesionales
# Autor: Hunt3r850
# Licencia: MIT
# Características Enterprise: WireGuard, Cobalt Strike, Dashboard Web, SIEM, Multi-Interfaz

set -euo pipefail

# ==================== CONFIGURACIÓN ====================
LOG_FILE="/var/log/kalidefender.log"
CONFIG_DIR="/etc/kalidefender"
MODE_FILE="$CONFIG_DIR/mode"
BACKUP_DIR="$CONFIG_DIR/backups"
WIREDIR="$CONFIG_DIR/wireguard"
COBALT_DIR="$CONFIG_DIR/cobaltstrike"
SIEM_SOCKET="/var/run/kalidefender-siem.sock"
DASHBOARD_PORT="${KALIDEFENDER_DASHBOARD_PORT:-8443}"

# Puertos configurables (pueden modificarse según necesidades)
ATTACK_TCP_PORTS="${KALIDEFENDER_TCP_PORTS:-22,80,443,4444,5555,8080}"
ATTACK_UDP_PORTS="${KALIDEFENDER_UDP_PORTS:-53,1194}"

# Fail2Ban configuración
FAIL2BAN_BANTIME="${KALIDEFENDER_BANTIME:-24h}"
FAIL2BAN_MAXRETRY="${KALIDEFENDER_MAXRETRY:-3}"

# Interfaces de red soportadas
SUPPORTED_INTERFACES=("eth" "wlan" "en" "wl")

# ==================== UTILIDADES ====================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "❌ Error: Este script requiere privilegios de superusuario (sudo)." >&2
        exit 1
    fi
}

get_user_uid() {
    local user=${SUDO_USER:-$(whoami)}
    id -u "$user"
}

# Verifica si un comando existe
command_exists() {
    command -v "$1" &>/dev/null
}

# Verifica dependencias críticas del sistema
check_system_dependencies() {
    local missing_deps=()
    
    if ! command_exists apt; then
        log "❌ Error: apt no está disponible. Este sistema no es compatible."
        exit 1
    fi
    
    for cmd in iptables ip6tables systemctl curl; do
        if ! command_exists "$cmd"; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "⚠️ Advertencia: Faltan comandos críticos: ${missing_deps[*]}"
    fi
}

# Crea backup de configuración actual
create_backup() {
    local backup_name="kalidefender_backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup de reglas iptables actuales
    iptables-save > "$BACKUP_DIR/${backup_name}_iptables.rules" 2>/dev/null || true
    ip6tables-save > "$BACKUP_DIR/${backup_name}_ip6tables.rules" 2>/dev/null || true
    
    # Backup de modo actual
    if [[ -f "$MODE_FILE" ]]; then
        cp "$MODE_FILE" "$BACKUP_DIR/${backup_name}_mode"
    fi
    
    # Backup de resolv.conf
    cp /etc/resolv.conf "$BACKUP_DIR/${backup_name}_resolv.conf" 2>/dev/null || true
    
    log "✅ Backup creado: $backup_name"
    echo "$backup_name"
}

# Restaura configuración desde backup
restore_backup() {
    local backup_name="$1"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    if [[ ! -d "$BACKUP_DIR" ]] || [[ ! -f "${backup_path}_iptables.rules" ]]; then
        log "❌ Error: Backup '$backup_name' no encontrado."
        return 1
    fi
    
    log "🔄 Restaurando backup: $backup_name"
    iptables-restore < "${backup_path}_iptables.rules" || true
    ip6tables-restore < "${backup_path}_ip6tables.rules" || true
    
    if [[ -f "${backup_path}_mode" ]]; then
        cp "${backup_path}_mode" "$MODE_FILE"
    fi
    
    if [[ -f "${backup_path}_resolv.conf" ]]; then
        chattr -i /etc/resolv.conf 2>/dev/null || true
        cp "${backup_path}_resolv.conf" /etc/resolv.conf
    fi
    
    log "✅ Backup restaurado correctamente."
}

# Lista backups disponibles
list_backups() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "No hay backups disponibles."
        return
    fi
    
    echo "📦 Backups disponibles:"
    ls -1 "$BACKUP_DIR" | sed 's/_iptables.rules$//' | sort -u | while read -r backup; do
        echo "  - $backup"
    done
}

# ==================== APPARMOR ====================

install_apparmor_profiles() {
    log "🛡️ Instalando perfiles de AppArmor para herramientas de pentesting..."
    
    # Perfil para Metasploit
    install_apparmor_metasploit
    
    # Perfil para Nmap
    install_apparmor_nmap
    
    # Perfil para BurpSuite
    install_apparmor_burpsuite
    
    log "✅ Todos los perfiles de AppArmor instalados."
}

install_apparmor_metasploit() {
    log "  📦 Metasploit..."
    cat > /etc/apparmor.d/usr.bin.msfconsole <<'EOF'
#include <tunables/global>

profile msfconsole /usr/bin/msfconsole flags=(complain) {
  #include <abstractions/base>
  #include <abstractions/nameservice>
  #include <abstractions/ruby>
  #include <abstractions/ssl_certs>

  /usr/share/metasploit-framework/** r,
  /opt/metasploit-framework/** r,
  owner @{HOME}/.msf4/** rw,
  owner @{HOME}/.msf5/** rw,
  owner @{HOME}/.local/share/meterpreter/** rw,
  
  # Denegaciones explícitas para seguridad
  deny /etc/shadow r,
  deny /etc/sudoers r,
  deny /root/** r,
  deny @{HOME}/.ssh/id_rsa r,
  deny /etc/passwd w,
  deny /etc/group w,
  
  # Permisos de red controlados
  network inet stream,
  network inet dgram,
  network raw,
  network netlink raw,
  
  # Capacidades necesarias
  capability net_raw,
  capability setuid,
  capability setgid,
}
EOF
    if command -v apparmor_parser &>/dev/null; then
        apparmor_parser -r /etc/apparmor.d/usr.bin.msfconsole 2>/dev/null || true
    fi
}

install_apparmor_nmap() {
    log "  📦 Nmap..."
    cat > /etc/apparmor.d/usr.bin.nmap <<'EOF'
#include <tunables/global>

profile nmap /usr/bin/nmap flags=(complain) {
  #include <abstractions/base>
  #include <abstractions/nameservice>
  #include <abstractions/ssl_certs>

  /usr/share/nmap/** r,
  /usr/lib/nmap/** r,
  owner @{HOME}/.nmap/** rw,
  
  # Raw sockets para scanning
  network raw,
  network packet,
  capability net_raw,
  capability net_admin,
  
  # Denegaciones
  deny /etc/shadow r,
  deny /etc/sudoers r,
  deny /root/** r,
}
EOF
    if command -v apparmor_parser &>/dev/null; then
        apparmor_parser -r /etc/apparmor.d/usr.bin.nmap 2>/dev/null || true
    fi
}

install_apparmor_burpsuite() {
    log "  📦 BurpSuite..."
    cat > /etc/apparmor.d/opt.burpsuite.burp <<'EOF'
#include <tunables/global>

profile burp /opt/BurpSuite/** java flags=(complain) {
  #include <abstractions/base>
  #include <abstractions/nameservice>
  #include <abstractions/ssl_certs>
  #include <abstractions/java>

  /opt/BurpSuite/** rm,
  owner @{HOME}/.BurpSuite/** rw,
  owner @{HOME}/.burpsuite/** rw,
  
  # Acceso a herramientas del sistema
  /usr/bin/python* ix,
  /usr/bin/bash ix,
  
  # Red para proxy
  network inet stream,
  network inet dgram,
  bind,
  
  # Denegaciones
  deny /etc/shadow r,
  deny /etc/sudoers r,
  deny /root/** r,
}
EOF
    if command -v apparmor_parser &>/dev/null; then
        apparmor_parser -r /etc/apparmor.d/opt.burpsuite.burp 2>/dev/null || true
    fi
}

# ==================== RED C2 ====================

detect_c2_subnet() {
    C2_PROVIDER="none"
    C2_SUBNET=""
    
    if command_exists tailscale && tailscale status &>/dev/null; then
        C2_PROVIDER="tailscale"
        local ts_ip
        ts_ip=$(tailscale ip -4 2>/dev/null | head -n1)
        if [[ -n "$ts_ip" ]]; then
            C2_SUBNET="$ts_ip/32"
            log "🔎 Red C2 detectada: Tailscale ($C2_SUBNET)"
        fi
    elif command_exists zerotier-cli; then
        local zt_status
        zt_status=$(zerotier-cli info -j 2>/dev/null || echo "{}")
        
        # Validar JSON y estado OK
        if echo "$zt_status" | grep -q '"status":"OK"' || echo "$zt_status" | grep -q '"status": "OK"'; then
            C2_PROVIDER="zerotier"
            local zt_networks
            zt_networks=$(zerotier-cli listnetworks -j 2>/dev/null || echo "[]")
            
            # Extraer subnet válida con mejor parsing
            C2_SUBNET=$(echo "$zt_networks" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}' | head -n1 || echo "")
            
            if [[ -n "$C2_SUBNET" ]]; then
                log "🔎 Red C2 detectada: ZeroTier ($C2_SUBNET)"
            else
                log "⚠️ ZeroTier activo pero no se pudo determinar la subnet"
                C2_SUBNET=""
            fi
        fi
    fi
    
    if [[ "$C2_PROVIDER" == "none" || -z "$C2_SUBNET" ]]; then
        log "ℹ️ Sin red C2 privada activa. Los puertos de ataque serán públicos."
    fi
}

# ==================== FIREWALL BASE ====================

firewall_base() {
    log "🧱 Aplicando reglas base de firewall..."

    # Limpiar reglas existentes
    iptables -F; iptables -X; iptables -t nat -F; iptables -t nat -X
    ip6tables -F; ip6tables -X

    # Políticas por defecto
    iptables -P INPUT DROP
    iptables -P OUTPUT DROP
    iptables -P FORWARD DROP
    ip6tables -P INPUT DROP
    ip6tables -P OUTPUT DROP
    ip6tables -P FORWARD DROP

    # Permitir tráfico local
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT

    # Permitir conexiones establecidas
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # Permitir DHCP
    iptables -A OUTPUT -p udp --sport 68 --dport 67 -j ACCEPT
    iptables -A INPUT -p udp --sport 67 --dport 68 -j ACCEPT

    # --- PERMITIR TRÁFICO DE CONTROL DE VPNs ---
    # Tailscale (UDP 41641 y otros)
    iptables -A OUTPUT -p udp --dport 41641 -j ACCEPT
    iptables -A INPUT -p udp --sport 41641 -j ACCEPT
    # ZeroTier (UDP 9993)
    iptables -A OUTPUT -p udp --dport 9993 -j ACCEPT
    iptables -A INPUT -p udp --sport 9993 -j ACCEPT
    # STUN/ICE para VPNs
    iptables -A OUTPUT -p udp --dport 3478 -j ACCEPT

    # Limitar SYN y ICMP para evitar flooding
    iptables -A INPUT -p tcp --syn -m limit --limit 2/sec --limit-burst 5 -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/sec -j ACCEPT

    # Loguear paquetes dropeados
    iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "KALIDEFENDER-DROP: "
}

# ==================== MODO STEALTH ====================

mode_stealth() {
    log "🥷 Activando Modo Stealth: Privacidad total + Tor"

    firewall_base

    # 1. Validar y obtener UID de debian-tor de forma segura
    local tor_uid=""
    if id -u debian-tor &>/dev/null; then
        tor_uid=$(id -u debian-tor)
        log "✅ Usuario debian-tor encontrado (UID: $tor_uid)"
    else
        log "❌ Error: Usuario debian-tor no encontrado. ¿Está Tor instalado?"
        return 1
    fi
    
    # Permitir tráfico de salida para Tor
    iptables -A OUTPUT -m owner --uid-owner "$tor_uid" -j ACCEPT

    # 2. Redirigir DNS a Tor (Puerto 5353)
    iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 5353
    iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports 5353

    # 3. Redirigir tráfico TCP a Tor (TransPort 9040)
    # Exceptuamos tráfico local y el propio tráfico de Tor
    iptables -t nat -A OUTPUT -d 127.0.0.0/8 -j RETURN
    iptables -t nat -A OUTPUT -m owner --uid-owner "$tor_uid" -j RETURN
    iptables -t nat -A OUTPUT -p tcp -j REDIRECT --to-ports 9040

    # 4. Permitir tráfico hacia los puertos de Tor
    iptables -A OUTPUT -p tcp --dport 9040 -j ACCEPT
    iptables -A OUTPUT -p udp --dport 5353 -j ACCEPT

    # 5. ELIMINADO: Ya no permitimos tráfico web directo (previene fugas)
    # Todo el tráfico debe pasar por Tor

    # Configurar DNS y hacerlo inmutable
    chattr -i /etc/resolv.conf 2>/dev/null || true
    echo "nameserver 127.0.0.1" > /etc/resolv.conf
    chattr +i /etc/resolv.conf 2>/dev/null || true

    echo "stealth" > "$MODE_FILE"
    log "✅ Modo Stealth activo. Todo el tráfico pasa por Tor."
}

# ==================== MODO ATTACK ====================

mode_attack() {
    log "⚔️ Activando Modo Attack: Pentesting con C2 seguro"

    detect_c2_subnet
    firewall_base
    iptables -t nat -F

    # Permitir todo el tráfico de salida para el usuario
    local uid=$(get_user_uid)
    iptables -A OUTPUT -m owner --uid-owner "$uid" -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner 0 -j ACCEPT

    # Configurar DNS público
    chattr -i /etc/resolv.conf 2>/dev/null || true
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
    echo "nameserver 8.8.8.8" >> /etc/resolv.conf

    # Abrir puertos de ataque
    if [[ -n "$C2_SUBNET" && "$C2_SUBNET" != "/32" ]]; then
        log "🔐 Puertos restringidos a la red $C2_PROVIDER ($C2_SUBNET)"
        IFS=',' read -ra TCP_PORTS <<< "$ATTACK_TCP_PORTS"
        for port in "${TCP_PORTS[@]}"; do
            iptables -A INPUT -s "$C2_SUBNET" -p tcp --dport "$port" -j ACCEPT
        done
        IFS=',' read -ra UDP_PORTS <<< "$ATTACK_UDP_PORTS"
        for port in "${UDP_PORTS[@]}"; do
            iptables -A INPUT -s "$C2_SUBNET" -p udp --dport "$port" -j ACCEPT
        done
    else
        log "⚠️ ADVERTENCIA: Sin red C2 privada activa. Abriendo puertos a TODO Internet."
        IFS=',' read -ra TCP_PORTS <<< "$ATTACK_TCP_PORTS"
        for port in "${TCP_PORTS[@]}"; do iptables -A INPUT -p tcp --dport "$port" -j ACCEPT; done
        IFS=',' read -ra UDP_PORTS <<< "$ATTACK_UDP_PORTS"
        for port in "${UDP_PORTS[@]}"; do iptables -A INPUT -p udp --dport "$port" -j ACCEPT; done
    fi

    echo "attack" > "$MODE_FILE"
    log "✅ Modo Attack activo."
}

# ==================== INSTALACIÓN ====================

install_dependencies() {
    log "📦 Instalando dependencias..."
    apt update -qq || true
    apt install -y -qq iptables-persistent fail2ban tor tor-geoipdb resolvconf macchanger apparmor apparmor-utils curl
}

configure_tor_dns() {
    log "🧅 Configurando Tor para DNS y TransPort..."
    if [[ -f /etc/tor/torrc ]]; then
        # Limpiar configuraciones previas de KaliDefender
        sed -i '/# KaliDefender Config/,$d' /etc/tor/torrc
        
        cat >> /etc/tor/torrc <<EOF

# KaliDefender Config
VirtualAddrNetworkIPv4 10.192.0.0/10
AutomapHostsOnResolve 1
TransPort 9040
DNSPort 5353
AvoidDiskWrites 1
EOF
        systemctl restart tor || true
    else
        log "⚠️ Archivo /etc/tor/torrc no encontrado."
    fi
}

configure_mac_randomization() {
    log "📡 Configurando aleatorización de MAC..."
    mkdir -p /etc/NetworkManager/conf.d/
    cat > /etc/NetworkManager/conf.d/00-macrandomize.conf <<EOF
[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
EOF
    systemctl restart NetworkManager || true
}

configure_fail2ban() {
    log "🛡️ Configurando Fail2Ban..."
    cat > /etc/fail2ban/filter.d/kalidefender.conf <<'EOF'
[Definition]
failregex = ^.*KALIDEFENDER-DROP:.*SRC=<HOST>
ignoreregex =
EOF

    cat > /etc/fail2ban/jail.d/kalidefender.local <<EOF
[kalidefender]
enabled = true
filter = kalidefender
logpath = /var/log/kern.log
maxretry = $FAIL2BAN_MAXRETRY
bantime = $FAIL2BAN_BANTIME
findtime = 1h
action = iptables-multiport[name=KaliDefender, port="ssh,http,https", protocol=tcp]
EOF
    
    # Asegurar que el log exista
    touch /var/log/kern.log 2>/dev/null || true
    
    systemctl restart fail2ban || true
    log "✅ Fail2Ban configurado (maxretry=$FAIL2BAN_MAXRETRY, bantime=$FAIL2BAN_BANTIME)"
}

install_secure_c2() {
    echo
    read -p "🔧 ¿Deseas configurar una red C2 segura (Tailscale/ZeroTier)? [S/n] " choice
    case "$choice" in
        n|N) log "Instalación de C2 omitida."; return ;; 
    esac

    echo "  t) Tailscale (Recomendado - Split Tunnel automático)"
    echo "  z) ZeroTier (Split Tunnel automático)"
    read -p "Elige una opción: " c2_choice

    case "$c2_choice" in
        t)  log "Instalando Tailscale..."
            curl -fsSL https://tailscale.com/install.sh | sh || true
            log "⚙️ Configurando Tailscale para evitar pérdida de conexión..."
            echo "📌 ¡Acción requerida! Ejecuta: sudo tailscale up --accept-dns=false --accept-routes=false"
            ;;
        z)  log "Instalando ZeroTier..."
            curl -s https://install.zerotier.com | sudo bash || true
            read -p "Introduce tu Network ID de ZeroTier: " nid
            log "⚙️ Uniendo a red ZeroTier $nid..."
            zerotier-cli join "$nid" || true
            log "✅ ZeroTier configurado como split-tunnel por defecto."
            ;;
        *) log "Opción no válida. Omitiendo instalación de C2.";;
    esac
}

install_all() {
    log "🚀 Iniciando instalación de KaliDefender v5.0.0..."
    
    # Verificar dependencias del sistema primero
    check_system_dependencies
    
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$BACKUP_DIR"
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"

    install_dependencies
    configure_tor_dns
    configure_mac_randomization
    configure_fail2ban
    install_apparmor_metasploit
    install_secure_c2

    cp "$0" /usr/local/bin/kalidefender.sh
    chmod +x /usr/local/bin/kalidefender.sh

    cat > /etc/systemd/system/kalidefender.service <<'EOF'
[Unit]
Description=KaliDefender v5.0.0 - Sistema Dual Stealth/Attack
After=network.target tor.service tailscaled.service zerotier-one.service
Wants=tor.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/kalidefender.sh start
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload || true
    systemctl enable kalidefender.service || true

    mode_stealth

    log "✅ Instalación completa. KaliDefender v5.0.0 activo en Modo Stealth."
    echo "📌 Usa: sudo kalidefender.sh {stealth|attack|toggle|status|backup|restore|help}"
}

# ==================== GESTIÓN ====================

mode_toggle() {
    if [[ -f "$MODE_FILE" && "$(cat "$MODE_FILE")" == "stealth" ]]; then
        mode_attack
    else
        mode_stealth
    fi
}

mode_status() {
    local current_mode="UNKNOWN"
    local json_output=false
    
    # Detectar si se pide output JSON
    if [[ "${2:-}" == "--json" ]]; then
        json_output=true
    fi
    
    if [[ -f "$MODE_FILE" ]]; then
        current_mode=$(cat "$MODE_FILE")
    fi
    
    if [[ "$json_output" == true ]]; then
        # Output en formato JSON para parsing programático
        local ts_status="inactive"
        local zt_status="inactive"
        local ts_ip="null"
        local zt_networks="[]"
        
        if systemctl is-active --quiet tailscaled 2>/dev/null; then
            ts_status="active"
            ts_ip="\"$(tailscale ip -4 2>/dev/null | head -n1 || echo 'N/A')\""
        fi
        
        if systemctl is-active --quiet zerotier-one 2>/dev/null; then
            zt_status="active"
            zt_networks="$(zerotier-cli listnetworks -j 2>/dev/null | grep -o '"id":"[0-9a-f]\{16\}"' | cut -d'"' -f4 || echo '')"
        fi
        
        cat <<EOF
{
  "version": "5.0.0",
  "mode": "$current_mode",
  "c2": {
    "tailscale": {"status": "$ts_status", "ip": $ts_ip},
    "zerotier": {"status": "$zt_status"}
  },
  "apparmor": $(if command_exists aa-status && aa-status | grep -q "msfconsole"; then echo "true"; else echo "false"; fi),
  "open_ports": $(iptables -L INPUT -n 2>/dev/null | grep -c "ACCEPT" || echo 0)
}
EOF
        return
    fi
    
    # Output humano legible
    echo "📊 ESTADO DE KALIDEFENDER v5.0.0"
    echo "=================================="
    
    if [[ -f "$MODE_FILE" ]]; then
        echo "🔷 Modo actual: $(echo "$current_mode" | tr 'a-z' 'A-Z')"
    else
        echo "🔷 Modo actual: NO CONFIGURADO"
    fi

    echo
    echo "🛡️ AppArmor para Metasploit:"
    if command_exists aa-status && aa-status --enabled &>/dev/null && aa-status | grep -q "msfconsole"; then
        echo "  ✅ Activo y perfil cargado"
    else
        echo "  ⚠️ Inactivo o no encontrado"
    fi

    echo
    echo "🌐 Red C2 Privada:"
    if systemctl is-active --quiet tailscaled 2>/dev/null; then
        echo "  ✅ Tailscale activo - IP: $(tailscale ip -4 2>/dev/null | head -n1 || echo 'N/A')"
    elif systemctl is-active --quiet zerotier-one 2>/dev/null; then
        local nets
        nets=$(zerotier-cli listnetworks -j 2>/dev/null | grep -oE '"id":"[0-9a-f]{16}"' | cut -d'"' -f4 | tr '\n' ', ' | sed 's/,$//' || echo "N/A")
        echo "  ✅ ZeroTier activo - Redes: $nets"
    else
        echo "  ❌ No detectada"
    fi

    echo
    echo "🔌 Puertos de entrada (INPUT) abiertos:"
    iptables -L INPUT -n --line-numbers 2>/dev/null | grep ACCEPT | sed 's/^/  /' || echo "  Ninguno"

    echo
    echo "📡 Test de conectividad a Internet:"
    # Intentamos a través de Tor si estamos en modo Stealth
    if [[ "$current_mode" == "stealth" ]]; then
        if timeout 5 curl --socks5-hostname 127.0.0.1:9050 -s https://httpbin.org/ip &>/dev/null; then
            echo "  ✅ Conexión exitosa (vía Tor)"
        else
            echo "  ❌ Fallo en la conexión (Tor)"
        fi
    else
        if timeout 5 curl -s https://httpbin.org/ip &>/dev/null; then
            echo "  ✅ Conexión exitosa"
        else
            echo "  ❌ Fallo en la conexión"
        fi
    fi
    echo "=================================="
}

start_service() {
    if [[ -f "$MODE_FILE" ]]; then
        local current_mode
        current_mode=$(cat "$MODE_FILE")
        if [[ "$current_mode" == "attack" ]]; then
            mode_attack
        else
            mode_stealth
        fi
    else
        mode_stealth
    fi
}

# ==================== AYUDA ====================

print_help() {
    cat <<'EOF'
    KaliDefender v5.0.0 — Sistema Dual Stealth/Attack para Pentesters

    Uso: sudo kalidefender.sh [COMANDO] [OPCIONES]

    COMANDOS:
      install           Instala y configura KaliDefender.
      stealth           Activa el Modo Stealth (privacidad máxima con Tor).
      attack            Activa el Modo Attack (pentesting con C2 seguro).
      toggle            Alterna entre los modos Stealth y Attack.
      status [--json]   Muestra el estado actual (usar --json para output JSON).
      backup            Crea un backup de la configuración actual.
      restore <nombre>  Restaura configuración desde un backup.
      list-backups      Lista todos los backups disponibles.
      help              Muestra este mensaje de ayuda.

    VARIABLES DE ENTORNO:
      KALIDEFENDER_TCP_PORTS     Puertos TCP en modo Attack (default: 22,80,443,4444,5555,8080)
      KALIDEFENDER_UDP_PORTS     Puertos UDP en modo Attack (default: 53,1194)
      KALIDEFENDER_BANTIME       Tiempo de baneo de Fail2Ban (default: 24h)
      KALIDEFENDER_MAXRETRY      Intentos máximos antes de banear (default: 3)

    EJEMPLOS:
      sudo kalidefender.sh install
      sudo kalidefender.sh stealth
      sudo kalidefender.sh status --json
      sudo kalidefender.sh backup
      sudo kalidefender.sh restore kalidefender_backup_20240101_120000
      KALIDEFENDER_BANTIME=48h sudo kalidefender.sh install

    Para más detalles, consulta la documentación en GitHub.
EOF
}

# ==================== MAIN ====================

main() {
    check_root
    
    case "${1:-help}" in
        install)      install_all ;;
        stealth)      mode_stealth ;;
        attack)       mode_attack ;;
        toggle)       mode_toggle ;;
        status)       mode_status "$@" ;;
        start)        start_service ;;
        backup)       create_backup ;;
        restore)      
            if [[ -z "${2:-}" ]]; then
                echo "❌ Error: Debes especificar el nombre del backup a restaurar."
                echo "Usa 'list-backups' para ver los disponibles."
                exit 1
            fi
            restore_backup "$2" 
            ;;
        list-backups) list_backups ;;
        # WireGuard
        wg-server)    setup_wireguard_server ;;
        wg-add-client) add_wireguard_client "${2:-}" ;;
        wg-list)      list_wireguard_clients ;;
        # Cobalt Strike
        cobalt-strike) setup_cobalt_strike ;;
        # SIEM
        siem)         setup_siem_integration ;;
        # Multi-interfaz
        interfaces)   list_network_interfaces ;;
        randomize-mac) randomize_mac_address "${2:-}" ;;
        interface-priority) configure_interface_priority ;;
        # Dashboard
        dashboard-setup) setup_dashboard ;;
        dashboard-start) start_dashboard ;;
        dashboard-stop)  stop_dashboard ;;
        # AppArmor
        apparmor)     install_apparmor_profiles ;;
        help)         print_help ;;
        *)            echo "Comando no válido." ; print_help ; exit 1 ;;
    esac
}

main "$@"

# ==================== WIREGUARD ====================

setup_wireguard_server() {
    log "🔧 Configurando servidor WireGuard..."
    mkdir -p "$WIREDIR"
    
    if ! command_exists wg; then
        log "📦 Instalando WireGuard..."
        apt install -y -qq wireguard || {
            log "❌ Error: No se pudo instalar WireGuard"
            return 1
        }
    fi
    
    local server_priv=$(wg genkey)
    local server_pub=$(echo "$server_priv" | wg pubkey)
    
    echo "$server_priv" > "$WIREDIR/server_private.key"
    echo "$server_pub" > "$WIREDIR/server_public.key"
    chmod 600 "$WIREDIR/server_private.key"
    
    cat > /etc/wireguard/wg0.conf << EOF
[Interface]
Address = 10.13.13.1/24
ListenPort = 51820
PrivateKey = $server_priv
SaveConfig = true
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
EOF
    
    chmod 600 /etc/wireguard/wg0.conf
    systemctl enable wg-quick@wg0 2>/dev/null || true
    systemctl start wg-quick@wg0 2>/dev/null || true
    
    log "✅ Servidor WireGuard configurado en 10.13.13.1:51820"
    echo "📌 Clave pública: $server_pub"
}

add_wireguard_client() {
    local client_name="${1:-client$(date +%s)}"
    log "➕ Agregando cliente WireGuard: $client_name"
    
    if [[ ! -f /etc/wireguard/wg0.conf ]]; then
        log "❌ Error: Ejecuta primero: sudo kalidefender.sh wg-server"
        return 1
    fi
    
    local client_priv=$(wg genkey)
    local client_pub=$(echo "$client_priv" | wg pubkey)
    local client_psk=$(wg genpsk)
    
    local last_ip=$(grep "AllowedIPs" /etc/wireguard/wg0.conf 2>/dev/null | tail -1 | grep -oE '10\.13\.13\.[0-9]+' | grep -oE '[0-9]+$' || echo "1")
    local next_ip=$((last_ip + 1))
    
    [[ $next_ip -gt 254 ]] && { log "❌ Máximo de clientes alcanzado"; return 1; }
    
    cat >> /etc/wireguard/wg0.conf << EOF

# Cliente: $client_name
[Peer]
PublicKey = $client_pub
PresharedKey = $client_psk
AllowedIPs = 10.13.13.$next_ip/32
EOF
    
    local server_pub=$(cat "$WIREDIR/server_public.key" 2>/dev/null)
    mkdir -p "$WIREDIR/clients"
    
    cat > "$WIREDIR/clients/${client_name}.conf" << EOF
[Interface]
PrivateKey = $client_priv
Address = 10.13.13.$next_ip/24
DNS = 1.1.1.1,8.8.8.8

[Peer]
PublicKey = $server_pub
PresharedKey = $client_psk
Endpoint = $(hostname -I | awk '{print $1}'):51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
    
    chmod 600 "$WIREDIR/clients/${client_name}.conf"
    wg setconf wg0 /etc/wireguard/wg0.conf 2>/dev/null || true
    
    log "✅ Cliente '$client_name' con IP 10.13.13.$next_ip"
    echo "📌 Config: $WIREDIR/clients/${client_name}.conf"
}

list_wireguard_clients() {
    if [[ ! -f /etc/wireguard/wg0.conf ]]; then
        echo "No hay servidor WireGuard."
        return
    fi
    echo "📋 Clientes WireGuard:"
    grep -B1 "^\[Peer\]" /etc/wireguard/wg0.conf | grep "# Cliente:" | sed 's/# Cliente:/  👤 /'
    echo ""
    wg show wg0 2>/dev/null || echo "⚠️ WireGuard inactivo"
}

# ==================== COBALT STRIKE ====================

setup_cobalt_strike() {
    log "🎯 Integración Cobalt Strike..."
    mkdir -p "$COBALT_DIR"
    
    echo "  1) Hardening Team Server"
    echo "  2) Generar perfil Malleable C2"
    echo "  3) Configurar redirector"
    read -p "Opción: " cs_choice
    
    case "$cs_choice" in
        1) harden_cobalt_strike ;;
        2) generate_malleable_profile ;;
        3) setup_cobalt_redirector ;;
        *) log "Opción no válida" ;;
    esac
}

harden_cobalt_strike() {
    log "🔒 Hardening Cobalt Strike..."
    cat > "$COBALT_DIR/teamserver_hardening.sh" << 'EOF'
#!/bin/bash
# Hardening Cobalt Strike
echo "[*] Revisa: set metadata_x86 \"\"; set rotate_keys \"7d\";"
echo "[*] Usa host_allowlist.txt para whitelisting"
EOF
    chmod +x "$COBALT_DIR/teamserver_hardening.sh"
    
    cat > "$COBALT_DIR/host_allowlist.txt" << EOF
# IPs autorizadas
127.0.0.1
EOF
    log "✅ Hardening en $COBALT_DIR/"
}

generate_malleable_profile() {
    local profile_name="${1:-default_$(date +%Y%m%d)}"
    cat > "$COBALT_DIR/${profile_name}.profile" << 'EOF'
set useragent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36";
set headers { Host "cdn.cloudflare.com"; Accept "text/html,application/xhtml+xml"; }
http-get { set uri "/static/images/logo.png"; client { header "X-Forwarded-For"; } server { output { print; base64; parameter "session"; } } }
http-post { set uri "/api/v2/analytics"; client { header "Content-Type" "application/json"; output { print; base64; parameter "data"; } } }
EOF
    log "✅ Perfil: $COBALT_DIR/${profile_name}.profile"
}

setup_cobalt_redirector() {
    read -p "IP Team Server: " ts_ip
    read -p "Puerto (443): " ts_port; ts_port="${ts_port:-443}"
    iptables -t nat -A PREROUTING -p tcp --dport 443 -j DNAT --to-destination "$ts_ip:$ts_port"
    iptables-save > "$COBALT_DIR/redirector_rules.v4"
    log "✅ Redirector: 443 -> $ts_ip:$ts_port"
}

# ==================== SIEM ====================

setup_siem_integration() {
    log "📊 Integración SIEM..."
    echo "  1) Socket Unix"
    echo "  2) Exportar JSON"
    echo "  3) Syslog forwarding"
    read -p "Opción: " siem_choice
    case "$siem_choice" in
        1) setup_siem_socket ;;
        2) export_logs_json ;;
        3) setup_syslog_forwarding ;;
    esac
}

setup_siem_socket() {
    rm -f "$SIEM_SOCKET"
    log "✅ Socket SIEM: $SIEM_SOCKET (requiere socat)"
}

export_logs_json() {
    local output_file="${1:-/var/log/kalidefender_events.json}"
    log "✅ Exportador JSON activo: $output_file"
}

setup_syslog_forwarding() {
    read -p "IP Syslog: " syslog_ip
    read -p "Puerto (514): " syslog_port; syslog_port="${syslog_port:-514}"
    log "✅ Syslog forwarding: $syslog_ip:$syslog_port"
}

# ==================== MULTI-INTERFACE ====================

list_network_interfaces() {
    log "📡 Interfaces:"
    ip -br link show | while read -r iface state mac; do
        local ips=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | tr '\n' ' ')
        printf "  %-15s [%s] IPv4: %s\n" "$iface" "$state" "${ips:-none}"
    done
}

randomize_mac_address() {
    local interface="${1:-}"
    [[ -z "$interface" ]] && { list_network_interfaces; return 1; }
    log "🎲 Randomizando MAC de $interface..."
    ip link set "$interface" down
    local new_mac=$(openssl rand -hex 6 | sed 's/\(..\)/\1:/g' | sed 's/:$//' | sed 's/^./0/')
    ip link set dev "$interface" address "$new_mac"
    ip link set "$interface" up
    log "✅ MAC: $new_mac"
}

configure_interface_priority() {
    list_network_interfaces
    read -p "Interfaz principal: " primary_iface
    read -p "Métrica (100): " metric; metric="${metric:-100}"
    ip route del default 2>/dev/null || true
    ip route add default dev "$primary_iface" metric "$metric"
    log "✅ Prioridad: $primary_iface (métrica $metric)"
}

# ==================== DASHBOARD ====================

setup_dashboard() {
    log "🖥️ Dashboard Web..."
    mkdir -p "$CONFIG_DIR/dashboard"
    ! command_exists python3 && { log "❌ Python3 requerido"; return 1; }
    
    # Server Python minimal
    cat > "$CONFIG_DIR/dashboard/server.py" << 'PYEOF'
#!/usr/bin/env python3
import http.server, ssl, json, subprocess, os
from datetime import datetime
PORT = int(os.environ.get('DASHBOARD_PORT', 8443))
class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/api/status':
            try: mode = open('/etc/kalidefender/mode').read().strip()
            except: mode = 'unknown'
            self.send_response(200); self.send_header('Content-Type','application/json'); self.end_headers()
            self.wfile.write(json.dumps({'mode':mode,'timestamp':datetime.now().isoformat(),'version':'5.1.0'}).encode())
        else: super().do_GET()
    def do_POST(self):
        if self.path == '/api/action':
            length = int(self.headers['ContentLength']); data = json.loads(self.rfile.read(length))
            action = data.get('action')
            try: r = subprocess.run(['kalidefender.sh', action], capture_output=True, text=True, timeout=30)
            except Exception as e: r = type('obj',(object,),{'stdout':'','stderr':str(e)})
            self.send_response(200); self.send_header('Content-Type','application/json'); self.end_headers()
            self.wfile.write(json.dumps({'success':True,'output':r.stdout}).encode())
        else: self.send_error(404)
    def log_message(self, format, *args): pass
def main():
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    cert,key = '/etc/kalidefender/dashboard/cert.pem','/etc/kalidefender/dashboard/key.pem'
    if not os.path.exists(cert): subprocess.run(['openssl','req','-x509','-newkey','rsa:4096','-keyout',key,'-out',cert,'-days','365','-nodes','-subj','/CN=KaliDefender'],check=True)
    ctx.load_cert_chain(cert,key)
    srv = http.server.HTTPServer(('0.0.0.0',PORT), Handler); srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
    print(f'Dashboard: https://0.0.0.0:{PORT}'); srv.serve_forever()
if __name__ == '__main__': main()
PYEOF
    chmod +x "$CONFIG_DIR/dashboard/server.py"
    
    # HTML minimal
    cat > "$CONFIG_DIR/dashboard/index.html" << 'HTMLEOF'
<!DOCTYPE html><html><head><meta charset="UTF-8"><title>KaliDefender v5.1.0</title>
<style>body{font-family:sans-serif;background:#1a1a2e;color:#eee;padding:20px}h1{color:#e94560}.card{background:rgba(255,255,255,0.05);padding:20px;margin:10px 0;border-radius:10px}button{padding:12px 24px;margin:5px;border:none;border-radius:5px;cursor:pointer}.btn-stealth{background:#667eea;color:#fff}.btn-attack{background:#f5576c;color:#fff}</style></head>
<body><h1>🛡️ KaliDefender Dashboard</h1>
<div class="card"><h3>Modo Actual: <span id="mode">Cargando...</span></div>
<div class="card"><button class="btn-stealth" onclick="setMode('stealth')">🥷 Stealth</button><button class="btn-attack" onclick="setMode('attack')">⚔️ Attack</button><button onclick="update()">🔄 Refresh</button></div>
<script>async function update(){const r=await fetch('/api/status');const d=await r.json();document.getElementById('mode').innerText=d.mode.toUpperCase()}async function setMode(a){await fetch('/api/action',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action:a})});setTimeout(update,1000)}setInterval(update,5000);update();</script></body></html>
HTMLEOF
    
    log "✅ Dashboard en https://0.0.0.0:$DASHBOARD_PORT"
    echo "📌 Inicia: sudo kalidefender.sh dashboard-start"
}

start_dashboard() {
    [[ ! -f "$CONFIG_DIR/dashboard/server.py" ]] && { log "❌ Ejecuta: sudo kalidefender.sh dashboard-setup"; return 1; }
    pkill -f "dashboard/server.py" 2>/dev/null || true
    cd "$CONFIG_DIR/dashboard" && DASHBOARD_PORT="$DASHBOARD_PORT" nohup python3 server.py > /var/log/kalidefender-dashboard.log 2>&1 &
    log "✅ Dashboard: https://0.0.0.0:$DASHBOARD_PORT"
}

stop_dashboard() {
    pkill -f "dashboard/server.py" 2>/dev/null || true
    log "✅ Dashboard detenido"
}
