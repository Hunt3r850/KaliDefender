#!/bin/bash
# KaliDefender v6.0.0 - Sistema Modular de Perfilado de Red
# Autor: Hunt3r850
# Licencia: MIT
# Arquitectura: Modular, Segura, Atómica

set -euo pipefail

# ==================== CONFIGURACIÓN GLOBAL ====================
readonly KALI_VERSION="6.0.0"
readonly BASE_DIR="/etc/kalidefender"
readonly LIB_DIR="${BASE_DIR}/lib"
readonly STATE_DIR="${BASE_DIR}/state"
readonly CONFIG_DIR="${BASE_DIR}/config"
readonly BACKUP_DIR="${BASE_DIR}/backups"
readonly LOG_FILE="/var/log/kalidefender.log"

# Cargar configuración por defecto
[[ -f "${CONFIG_DIR}/defaults.conf" ]] && source "${CONFIG_DIR}/defaults.conf"

# Configuración con valores por defecto
ATTACK_TCP_PORTS="${KALIDEFENDER_TCP_PORTS:-22,80,443,4444,5555,8080}"
ATTACK_UDP_PORTS="${KALIDEFENDER_UDP_PORTS:-53,1194}"
FAIL2BAN_BANTIME="${KALIDEFENDER_BANTIME:-24h}"
FAIL2BAN_MAXRETRY="${KALIDEFENDER_MAXRETRY:-3}"
DASHBOARD_PORT="${KALIDEFENDER_DASHBOARD_PORT:-8443}"
DASHBOARD_AUTH_TOKEN="${KALIDEFENDER_AUTH_TOKEN:-}"

# ==================== UTILIDADES CORE ====================

# Sistema de logging estructurado
log() {
    local level="${1:-INFO}"
    local message="${2:-}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Formato JSON para integración SIEM
    if [[ "${LOG_FORMAT:-}" == "json" ]]; then
        echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"message\":\"$message\",\"component\":\"${FUNCNAME[1]:-main}\"}" >> "$LOG_FILE"
    else
        echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
    fi
}

# Verificación de root mejorada
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "ERROR" "Este script requiere privilegios de superusuario (sudo)"
        exit 1
    fi
}

# Verificación de dependencias robusta
check_dependency() {
    local cmd="$1"
    local package="${2:-$cmd}"
    
    if ! command -v "$cmd" &>/dev/null; then
        log "WARNING" "Comando '$cmd' no encontrado. Intentando instalar $package..."
        if apt install -y -qq "$package" 2>/dev/null; then
            log "INFO" "$package instalado correctamente"
            return 0
        else
            log "ERROR" "No se pudo instalar $package"
            return 1
        fi
    fi
    return 0
}

# Validación de entrada segura
validate_action() {
    local action="$1"
    local allowed_actions=("stealth" "attack" "toggle" "status" "backup" "restore" "help")
    
    for allowed in "${allowed_actions[@]}"; do
        [[ "$action" == "$allowed" ]] && return 0
    done
    return 1
}

# Gestión de estado del sistema
get_state() {
    local key="$1"
    local state_file="${STATE_DIR}/${key}"
    
    if [[ -f "$state_file" ]]; then
        cat "$state_file"
    else
        echo "unknown"
    fi
}

set_state() {
    local key="$1"
    local value="$2"
    
    mkdir -p "$STATE_DIR"
    echo "$value" > "${STATE_DIR}/${key}"
    log "DEBUG" "Estado actualizado: $key = $value"
}

# ==================== MÓDULO DE FIREWALL ====================

# Aplicación atómica de reglas iptables
firewall_apply_atomic() {
    local rules_file="${STATE_DIR}/iptables.rules"
    
    log "INFO" "Aplicando reglas de firewall de forma atómica..."
    
    # Generar archivo de reglas completo
    cat > "$rules_file" << 'EOF'
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT DROP [0:0]
:KALIDEFENDER-IN - [0:0]
:KALIDEFENDER-OUT - [0:0]
:KALIDEFENDER-FAIL2BAN - [0:0]

# Loopback
-A INPUT -i lo -j ACCEPT
-A OUTPUT -o lo -j ACCEPT

# Conexiones establecidas
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
-A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# DHCP
-A OUTPUT -p udp --sport 68 --dport 67 -j ACCEPT
-A INPUT -p udp --sport 67 --dport 68 -j ACCEPT

# Cadenas personalizadas
-A INPUT -j KALIDEFENDER-IN
-A OUTPUT -j KALIDEFENDER-OUT

# Fail2Ban chain
-A INPUT -j KALIDEFENDER-FAIL2BAN

COMMIT

*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
COMMIT
EOF

    # Aplicar reglas de forma atómica
    if iptables-restore < "$rules_file" 2>/dev/null; then
        log "INFO" "Firewall aplicado exitosamente"
        return 0
    else
        log "ERROR" "Error al aplicar reglas de firewall"
        return 1
    fi
}

# Configuración específica del modo
firewall_configure_mode() {
    local mode="$1"
    local rules_file="${STATE_DIR}/iptables.rules"
    
    case "$mode" in
        stealth)
            # Agregar reglas de Tor
            sed -i '/KALIDEFENDER-OUT/a -A KALIDEFENDER-OUT -m owner --uid-owner debian-tor -j ACCEPT' "$rules_file"
            ;;
        attack)
            # Agregar reglas de ataque
            local uid
            uid=$(get_user_uid)
            sed -i "/KALIDEFENDER-OUT/a -A KALIDEFENDER-OUT -m owner --uid-owner $uid -j ACCEPT" "$rules_file"
            sed -i '/KALIDEFENDER-OUT/a -A KALIDEFENDER-OUT -m owner --uid-owner 0 -j ACCEPT' "$rules_file"
            ;;
    esac
    
    firewall_apply_atomic
}

# ==================== MÓDULO DE MODOS ====================

mode_stealth() {
    log "INFO" "🦊 Activando Modo Stealth - Privacidad Total"
    
    # Verificar que Tor esté instalado y funcionando
    if ! systemctl is-active --quiet tor; then
        log "WARNING" "Tor no está activo. Intentando iniciar..."
        systemctl start tor || {
            log "ERROR" "No se pudo iniciar Tor"
            return 1
        }
    fi
    
    # Configurar firewall para modo stealth
    firewall_configure_mode "stealth"
    
    # Configurar DNS seguro (inmutable)
    configure_secure_dns
    
    # Configurar transproxy de Tor
    configure_tor_transproxy
    
    set_state "mode" "stealth"
    log "INFO" "✅ Modo Stealth activado correctamente"
}

mode_attack() {
    log "INFO" "⚔️ Activando Modo Attack - Pentesting Controlado"
    
    # Detectar red C2
    detect_c2_network
    
    # Configurar firewall para modo attack
    firewall_configure_mode "attack"
    
    # Abrir puertos según configuración
    open_attack_ports
    
    # Restaurar DNS público
    restore_public_dns
    
    set_state "mode" "attack"
    log "INFO" "✅ Modo Attack activado correctamente"
}

# ==================== MÓDULO DE RED C2 ====================

detect_c2_network() {
    local c2_detected="none"
    local c2_subnet=""
    
    # Verificar Tailscale
    if command -v tailscale &>/dev/null && tailscale status &>/dev/null; then
        c2_detected="tailscale"
        c2_subnet="100.64.0.0/10"  # Rango por defecto de Tailscale
        log "INFO" "🔐 Red C2 detectada: Tailscale"
        
    # Verificar ZeroTier
    elif command -v zerotier-cli &>/dev/null; then
        local zt_status
        zt_status=$(zerotier-cli info 2>/dev/null || echo "")
        
        if [[ "$zt_status" == *"ONLINE"* ]]; then
            c2_detected="zerotier"
            # Obtener subredes de ZeroTier
            local zt_networks
            zt_networks=$(zerotier-cli listnetworks -j 2>/dev/null | grep -oP '(?<="routes":\[).*?(?=\])' | grep -oP '\d+\.\d+\.\d+\.\d+/\d+' | head -1 || echo "")
            c2_subnet="${zt_networks:-10.0.0.0/8}"
            log "INFO" "🔐 Red C2 detectada: ZeroTier ($c2_subnet)"
        fi
    fi
    
    set_state "c2_provider" "$c2_detected"
    set_state "c2_subnet" "$c2_subnet"
    
    if [[ "$c2_detected" == "none" ]]; then
        log "WARNING" "⚠️ Sin red C2 detectada - Los puertos se expondrán a Internet"
        echo "⚠️ ADVERTENCIA: Sin red privada C2. ¿Desea continuar? (s/N):"
        read -r response
        [[ "$response" =~ ^[Ss]$ ]] || exit 1
    fi
}

open_attack_ports() {
    local c2_subnet
    c2_subnet=$(get_state "c2_subnet")
    
    log "INFO" "Abriendo puertos de ataque..."
    
    # Puerto de dashboard (siempre con restricción si hay C2)
    if [[ -n "$c2_subnet" && "$c2_subnet" != "none" ]]; then
        iptables -A KALIDEFENDER-IN -s "$c2_subnet" -p tcp --dport "$DASHBOARD_PORT" -j ACCEPT
    else
        iptables -A KALIDEFENDER-IN -p tcp --dport "$DASHBOARD_PORT" -j ACCEPT
    fi
    
    # Puertos TCP de ataque
    IFS=',' read -ra TCP_PORTS <<< "$ATTACK_TCP_PORTS"
    for port in "${TCP_PORTS[@]}"; do
        if [[ -n "$c2_subnet" && "$c2_subnet" != "none" ]]; then
            iptables -A KALIDEFENDER-IN -s "$c2_subnet" -p tcp --dport "$port" -j ACCEPT
        else
            iptables -A KALIDEFENDER-IN -p tcp --dport "$port" -m conntrack --ctstate NEW -j ACCEPT
        fi
        log "DEBUG" "Puerto TCP $port abierto"
    done
    
    # Puertos UDP de ataque
    IFS=',' read -ra UDP_PORTS <<< "$ATTACK_UDP_PORTS"
    for port in "${UDP_PORTS[@]}"; do
        if [[ -n "$c2_subnet" && "$c2_subnet" != "none" ]]; then
            iptables -A KALIDEFENDER-IN -s "$c2_subnet" -p udp --dport "$port" -j ACCEPT
        else
            iptables -A KALIDEFENDER-IN -p udp --dport "$port" -j ACCEPT
        fi
        log "DEBUG" "Puerto UDP $port abierto"
    done
}

# ==================== MÓDULO DE TOR ====================

configure_tor_transproxy() {
    log "INFO" "Configurando Tor TransProxy..."
    
    # Verificar que el usuario debian-tor existe
    if ! id -u debian-tor &>/dev/null; then
        log "ERROR" "Usuario debian-tor no encontrado"
        return 1
    fi
    
    # Asegurar que Tor esté configurado correctamente
    if [[ -f /etc/tor/torrc ]]; then
        # Backup de la configuración actual
        cp /etc/tor/torrc "/etc/tor/torrc.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Configurar Tor para TransProxy
        cat >> /etc/tor/torrc << 'EOF'

# KaliDefender TransProxy Configuration
VirtualAddrNetworkIPv4 10.192.0.0/10
AutomapHostsOnResolve 1
TransPort 9040
DNSPort 5353
AvoidDiskWrites 1
EOF
        
        # Reiniciar Tor
        systemctl restart tor
        
        # Esperar a que Tor esté listo
        sleep 3
        
        # Verificar que Tor está funcionando
        if ! systemctl is-active --quiet tor; then
            log "ERROR" "Tor no se inició correctamente"
            return 1
        fi
    fi
    
    # Configurar redirección de tráfico
    iptables -t nat -A OUTPUT -p tcp -m owner ! --uid-owner debian-tor -j REDIRECT --to-ports 9040
    iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports 5353
    
    log "INFO" "TransProxy de Tor configurado correctamente"
}

# ==================== MÓDULO DE SEGURIDAD ====================

configure_secure_dns() {
    log "INFO" "Configurando DNS seguro..."
    
    # Hacer resolv.conf inmutable
    chattr -i /etc/resolv.conf 2>/dev/null || true
    echo "nameserver 127.0.0.1" > /etc/resolv.conf
    chattr +i /etc/resolv.conf 2>/dev/null || true
    
    log "INFO" "DNS configurado para usar Tor (127.0.0.1)"
}

restore_public_dns() {
    log "INFO" "Restaurando DNS público..."
    
    chattr -i /etc/resolv.conf 2>/dev/null || true
    cat > /etc/resolv.conf << EOF
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
    
    log "INFO" "DNS público restaurado"
}

# ==================== MÓDULO FAIL2BAN ====================

configure_fail2ban() {
    log "INFO" "Configurando Fail2Ban adaptativo..."
    
    # Crear filtro personalizado
    cat > /etc/fail2ban/filter.d/kalidefender.conf << 'EOF'
[Definition]
failregex = ^.*KALIDEFENDER-FAIL2BAN:.*SRC=<HOST>.*
ignoreregex =
EOF
    
    # Configurar jail
    cat > /etc/fail2ban/jail.d/kalidefender.local << EOF
[kalidefender]
enabled = true
filter = kalidefender
logpath = /var/log/kern.log
maxretry = ${FAIL2BAN_MAXRETRY}
bantime = ${FAIL2BAN_BANTIME}
findtime = 1h
action = iptables-multiport[name=KaliDefender, port="ssh,http,https", protocol=tcp]
EOF
    
    # Reiniciar Fail2Ban
    systemctl restart fail2ban
    
    # Verificar estado
    if systemctl is-active --quiet fail2ban; then
        log "INFO" "Fail2Ban configurado y activo"
    else
        log "ERROR" "Fail2Ban no pudo iniciarse"
        return 1
    fi
}

# ==================== CARACTERÍSTICAS ENTERPRISE ====================
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



# Lista backups disponibles
list_backups() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "No hay backups disponibles."
        return
    fi
    
    echo "📦 Backups disponibles:"
    ls -1 "$BACKUP_DIR" | sort -u | while read -r backup; do
        echo "  - $backup"
    done
}

# ==================== MÓDULO DE INSTALACIÓN ====================

install_kalidefender() {
    log "INFO" "🚀 Instalando KaliDefender v${KALI_VERSION}..."
    
    # Verificar sistema
    check_dependency "apt" "apt"
    check_dependency "iptables" "iptables"
    check_dependency "systemctl" "systemd"
    
    # Crear estructura de directorios
    mkdir -p "$STATE_DIR" "$BACKUP_DIR" "$CONFIG_DIR"
    touch "$LOG_FILE"
    chmod 640 "$LOG_FILE"
    
    # Instalar dependencias
    log "INFO" "Instalando dependencias..."
    apt update -qq
    apt install -y -qq \
        iptables-persistent \
        fail2ban \
        tor \
        tor-geoipdb \
        apparmor \
        apparmor-utils \
        curl \
        wireguard \
        python3 \
        python3-pip || {
        log "ERROR" "Error instalando dependencias"
        return 1
    }
    
    # Configurar servicios
    configure_tor_transproxy
    configure_fail2ban
    install_apparmor_profiles
    
    # Copiar script al sistema
    cp "$0" /usr/local/bin/kalidefender
    chmod +x /usr/local/bin/kalidefender
    
    # Crear servicio systemd
    cat > /etc/systemd/system/kalidefender.service << EOF
[Unit]
Description=KaliDefender v${KALI_VERSION} - Sistema de Perfilado de Red
After=network.target tor.service
Wants=tor.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/kalidefender start
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable kalidefender.service
    
    # Activar modo stealth por defecto
    mode_stealth
    
    log "INFO" "✅ KaliDefender v${KALI_VERSION} instalado correctamente"
    echo ""
    echo "📌 KaliDefender está funcionando en Modo Stealth"
    echo "📌 Comandos disponibles:"
    echo "   sudo kalidefender stealth    - Modo privacidad total"
    echo "   sudo kalidefender attack     - Modo pentesting"
    echo "   sudo kalidefender status     - Ver estado actual"
    echo "   sudo kalidefender help       - Ayuda completa"
}

# ==================== MÓDULO DE ESTADO ====================

show_status() {
    local mode
    mode=$(get_state "mode")
    local c2_provider
    c2_provider=$(get_state "c2_provider")
    
    echo "📊 ESTADO DE KALIDEFENDER v${KALI_VERSION}"
    echo "=========================================="
    echo "🔷 Modo: ${mode^^}"
    echo "🌐 Red C2: ${c2_provider:-No detectada}"
    echo ""
    echo "🔌 Puertos abiertos:"
    iptables -L KALIDEFENDER-IN -n --line-numbers 2>/dev/null | grep ACCEPT || echo "  Ninguno"
    echo ""
    echo "🛡️ Servicios:"
    echo "  Tor: $(systemctl is-active tor)"
    echo "  Fail2Ban: $(systemctl is-active fail2ban)"
    echo "=========================================="
}

# ==================== SISTEMA DE BACKUP ====================

create_backup() {
    local backup_name="kalidefender_backup_$(date +%Y%m%d_%H%M%S)"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    mkdir -p "$backup_path"
    
    # Backup de reglas iptables
    iptables-save > "${backup_path}/iptables.rules" 2>/dev/null
    ip6tables-save > "${backup_path}/ip6tables.rules" 2>/dev/null
    
    # Backup de estado
    cp -r "$STATE_DIR" "${backup_path}/state"
    
    # Backup de configuración
    cp /etc/resolv.conf "${backup_path}/resolv.conf" 2>/dev/null
    cp /etc/tor/torrc "${backup_path}/torrc" 2>/dev/null
    
    log "INFO" "✅ Backup creado: $backup_name"
    echo "$backup_name"
}

restore_backup() {
    local backup_name="$1"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    if [[ ! -d "$backup_path" ]]; then
        log "ERROR" "Backup '$backup_name' no encontrado"
        return 1
    fi
    
    log "INFO" "🔄 Restaurando backup: $backup_name"
    
    # Restaurar iptables
    [[ -f "${backup_path}/iptables.rules" ]] && iptables-restore < "${backup_path}/iptables.rules"
    [[ -f "${backup_path}/ip6tables.rules" ]] && ip6tables-restore < "${backup_path}/ip6tables.rules"
    
    # Restaurar estado
    [[ -d "${backup_path}/state" ]] && cp -r "${backup_path}/state"/* "$STATE_DIR"
    
    # Restaurar configuraciones
    [[ -f "${backup_path}/resolv.conf" ]] && cp "${backup_path}/resolv.conf" /etc/resolv.conf
    [[ -f "${backup_path}/torrc" ]] && cp "${backup_path}/torrc" /etc/tor/torrc && systemctl restart tor
    
    log "INFO" "✅ Backup restaurado correctamente"
}

# ==================== DASHBOARD WEB SEGURO ====================

start_dashboard() {
    log "INFO" "Iniciando dashboard web seguro..."
    
    # Generar token de autenticación si no existe
    if [[ -z "$DASHBOARD_AUTH_TOKEN" ]]; then
        DASHBOARD_AUTH_TOKEN=$(openssl rand -hex 32)
        log "INFO" "Token de autenticación generado: $DASHBOARD_AUTH_TOKEN"
        echo "⚠️ GUARDA ESTE TOKEN: $DASHBOARD_AUTH_TOKEN"
    fi
    
    # Iniciar servidor Python seguro
    cat > /tmp/kalidefender_dashboard.py << PYEOF
import http.server
import ssl
import json
import subprocess
import os
import hashlib
from datetime import datetime

PORT = int(os.environ.get('DASHBOARD_PORT', 8443))
AUTH_TOKEN = os.environ.get('DASHBOARD_AUTH_TOKEN', '')

class SecureHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/api/status':
            if not self.verify_auth():
                self.send_error(401)
                return
            self.send_json_response(self.get_status())
        else:
            self.send_error(404)
    
    def do_POST(self):
        if self.path == '/api/action':
            if not self.verify_auth():
                self.send_error(401)
                return
            
            content_length = int(self.headers.get('Content-Length', 0))
            if content_length == 0:
                self.send_error(400)
                return
            
            data = json.loads(self.rfile.read(content_length))
            action = data.get('action', '')
            
            # Whitelist de acciones permitidas
            allowed_actions = ['stealth', 'attack', 'status']
            if action not in allowed_actions:
                self.send_error(400, "Acción no permitida")
                return
            
            result = self.execute_action(action)
            self.send_json_response(result)
        else:
            self.send_error(404)
    
    def verify_auth(self):
        auth_header = self.headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            return False
        token = auth_header.split(' ')[1]
        return hashlib.sha256(token.encode()).hexdigest() == hashlib.sha256(AUTH_TOKEN.encode()).hexdigest()
    
    def get_status(self):
        return {
            'version': '${KALI_VERSION}',
            'timestamp': datetime.now().isoformat(),
            'mode': open('/etc/kalidefender/state/mode').read().strip() if os.path.exists('/etc/kalidefender/state/mode') else 'unknown',
            'uptime': subprocess.getoutput('uptime -p')
        }
    
    def execute_action(self, action):
        try:
            result = subprocess.run(
                ['sudo', '/usr/local/bin/kalidefender', action],
                capture_output=True,
                text=True,
                timeout=30
            )
            return {
                'success': True,
                'output': result.stdout,
                'action': action
            }
        except Exception as e:
            return {
                'success': False,
                'error': str(e),
                'action': action
            }
    
    def send_json_response(self, data):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Cache-Control', 'no-cache')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())

def main():
    # Generar certificado autofirmado
    cert_dir = '/etc/kalidefender/certs'
    os.makedirs(cert_dir, exist_ok=True)
    
    cert_file = os.path.join(cert_dir, 'dashboard.pem')
    key_file = os.path.join(cert_dir, 'dashboard.key')
    
    if not os.path.exists(cert_file):
        subprocess.run([
            'openssl', 'req', '-x509', '-newkey', 'rsa:4096',
            '-keyout', key_file, '-out', cert_file,
            '-days', '365', '-nodes',
            '-subj', '/CN=KaliDefender Dashboard'
        ], check=True)
    
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(cert_file, key_file)
    
    server = http.server.HTTPServer(('127.0.0.1', PORT), SecureHandler)
    server.socket = context.wrap_socket(server.socket, server_side=True)
    
    print(f"Dashboard seguro iniciado en https://localhost:{PORT}")
    print(f"Token: {AUTH_TOKEN}")
    
    server.serve_forever()

if __name__ == '__main__':
    main()
PYEOF
    
    # Iniciar dashboard en background
    nohup python3 /tmp/kalidefender_dashboard.py > /var/log/kalidefender-dashboard.log 2>&1 &
    local pid=$!
    
    sleep 2
    
    if kill -0 $pid 2>/dev/null; then
        log "INFO" "Dashboard iniciado en https://localhost:${DASHBOARD_PORT}"
        echo "📊 Dashboard: https://localhost:${DASHBOARD_PORT}"
        echo "🔑 Token: $DASHBOARD_AUTH_TOKEN"
        echo "📌 Usa: curl -H 'Authorization: Bearer $DASHBOARD_AUTH_TOKEN' https://localhost:${DASHBOARD_PORT}/api/status"
    else
        log "ERROR" "No se pudo iniciar el dashboard"
        return 1
    fi
}

# ==================== MAIN ====================

main() {
    # Verificar root inmediatamente
    check_root
    
    case "${1:-help}" in
        install)
            install_kalidefender
            ;;
        stealth)
            mode_stealth
            ;;
        attack)
            mode_attack
            ;;
        toggle)
            local current_mode
            current_mode=$(get_state "mode")
            if [[ "$current_mode" == "stealth" ]]; then
                mode_attack
            else
                mode_stealth
            fi
            ;;
        status)
            show_status
            ;;
        backup)
            create_backup
            ;;
        restore)
            if [[ -z "${2:-}" ]]; then
                echo "❌ Error: Especifica el nombre del backup"
                exit 1
            fi
            restore_backup "$2"
            ;;
        dashboard)
            start_dashboard
            ;;
        wg-server)    setup_wireguard_server ;;
        wg-add-client) add_wireguard_client "${2:-}" ;;
        wg-list)      list_wireguard_clients ;;
        cobalt-strike) setup_cobalt_strike ;;
        interfaces)   list_network_interfaces ;;
        randomize-mac) randomize_mac_address "${2:-}" ;;
        interface-priority) configure_interface_priority ;;
        list-backups) list_backups ;;
        apparmor)     install_apparmor_profiles ;;
        help|--help|-h)
            cat << 'EOF'
KaliDefender v6.0.0 - Sistema de Perfilado de Red para Pentesters

USO:
  sudo kalidefender [COMANDO] [OPCIONES]

COMANDOS:
  install       Instala y configura KaliDefender
  stealth       Activa el Modo Stealth (privacidad total con Tor)
  attack        Activa el Modo Attack (pentesting con C2 seguro)
  toggle        Alterna entre modos Stealth y Attack
  status        Muestra el estado actual
  backup        Crea un backup de la configuración actual
  restore NAME  Restaura configuración desde un backup
  dashboard     Inicia el dashboard web seguro
  wg-server     Configura el servidor WireGuard
  wg-add-client Agrega un cliente WireGuard
  wg-list       Lista los clientes WireGuard
  cobalt-strike Configura integración con Cobalt Strike
  interfaces    Lista las interfaces de red
  randomize-mac Aleatoriza la MAC de una interfaz
  list-backups  Lista todos los backups disponibles
  apparmor      Instala perfiles de AppArmor
  help          Muestra este mensaje de ayuda

VARIABLES DE ENTORNO:
  KALIDEFENDER_TCP_PORTS      Puertos TCP en modo Attack (default: 22,80,443,4444,5555,8080)
  KALIDEFENDER_UDP_PORTS      Puertos UDP en modo Attack (default: 53,1194)
  KALIDEFENDER_BANTIME        Tiempo de baneo Fail2Ban (default: 24h)
  KALIDEFENDER_MAXRETRY       Intentos máximos Fail2Ban (default: 3)
  KALIDEFENDER_DASHBOARD_PORT Puerto dashboard (default: 8443)
  KALIDEFENDER_AUTH_TOKEN     Token autenticación dashboard

EJEMPLOS:
  sudo kalidefender install
  sudo kalidefender stealth
  sudo KALIDEFENDER_TCP_PORTS="22,443,1337" kalidefender attack
  sudo kalidefender dashboard
EOF
            ;;
        *)
            echo "❌ Comando no válido: $1"
            echo "Usa 'sudo kalidefender help' para ver los comandos disponibles"
            exit 1
            ;;
    esac
}

# Ejecutar main
main "$@"