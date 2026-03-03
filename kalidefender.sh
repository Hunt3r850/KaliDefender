#!/bin/bash
# KaliDefender v4.2 - Sistema Dual Stealth/Attack para Pentesters Profesionales
# Autor: Hunt3r850
# Licencia: MIT

set -euo pipefail

# ==================== CONFIGURACIÓN ====================
LOG_FILE="/var/log/kalidefender.log"
CONFIG_DIR="/etc/kalidefender"
MODE_FILE="$CONFIG_DIR/mode"

# Puertos a abrir en modo ATTACK (separados por comas)
ATTACK_TCP_PORTS="22,80,443,4444,5555,8080"
ATTACK_UDP_PORTS="53,1194"

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

# ==================== APPARMOR ====================

install_apparmor_metasploit() {
    log "🛡️ Instalando perfiles de AppArmor para Metasploit..."

    cat > /etc/apparmor.d/usr.bin.msfconsole <<'EOF'
#include <tunables/global>

profile msfconsole /usr/bin/msfconsole {
  #include <abstractions/base>
  #include <abstractions/nameservice>
  #include <abstractions/ruby>

  # Permite acceso a los recursos de Metasploit
  /usr/share/metasploit-framework/** r,
  /opt/metasploit-framework/** r,

  # Permite acceso a archivos de usuario
  owner @{HOME}/.msf4/** rw,

  # Niega acceso a archivos críticos
  deny /etc/shadow r,
  deny /etc/sudoers r,
  deny /root/** r,
  deny @{HOME}/.ssh/id_rsa r,

  # Permite operaciones de red
  network inet stream,
  network inet dgram,
  network raw,
}
EOF

    if command -v apparmor_parser &>/dev/null; then
        apparmor_parser -r /etc/apparmor.d/usr.bin.msfconsole
        log "✅ Perfil de AppArmor para msfconsole instalado."
    else
        log "⚠️ AppArmor no detectado, perfil guardado pero no cargado."
    fi
}

# ==================== RED C2 ====================

detect_c2_subnet() {
    C2_PROVIDER="none"
    C2_SUBNET=""
    if command -v tailscale &>/dev/null && tailscale status &>/dev/null; then
        C2_PROVIDER="tailscale"
        C2_SUBNET=$(tailscale ip -4 | cut -d' ' -f1)/32
        log "🔎 Red C2 detectada: Tailscale ($C2_SUBNET)"
    elif command -v zerotier-cli &>/dev/null && zerotier-cli info -j | grep -q '\"status\":\"OK\"' ; then
        C2_PROVIDER="zerotier"
        C2_SUBNET=$(zerotier-cli listnetworks -j | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/[0-9]\{1,2\}' | head -n1)
        log "🔎 Red C2 detectada: ZeroTier ($C2_SUBNET)"
    else
        log "ℹ️ Sin red C2 privada. Los puertos de ataque serán públicos."
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

    # Redirigir DNS a Tor
    iptables -t nat -A OUTPUT -p udp --dport 53 ! -d 127.0.0.0/8 -j REDIRECT --to-ports 5353
    iptables -t nat -A OUTPUT -p tcp --dport 53 ! -d 127.0.0.0/8 -j REDIRECT --to-ports 5353

    # Permitir tráfico web para usuario y root
    local uid=$(get_user_uid)
    iptables -A OUTPUT -m owner --uid-owner "$uid" -p tcp -m multiport --dports 80,443 -j ACCEPT
    iptables -A OUTPUT -m owner --uid-owner 0 -p tcp -m multiport --dports 80,443 -j ACCEPT

    # Configurar DNS y hacerlo inmutable
    chattr -i /etc/resolv.conf 2>/dev/null || true
    echo "nameserver 127.0.0.1" > /etc/resolv.conf
    chattr +i /etc/resolv.conf 2>/dev/null || true

    echo "stealth" > "$MODE_FILE"
    if [[ -d /etc/iptables ]]; then
        iptables-save > /etc/iptables/rules.stealth.v4
    fi
    log "✅ Modo Stealth activo."
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
        log "⚠️ ADVERTENCIA: Sin red C2 privada. Abriendo puertos a TODO Internet."
        IFS=',' read -ra TCP_PORTS <<< "$ATTACK_TCP_PORTS"
        for port in "${TCP_PORTS[@]}"; do iptables -A INPUT -p tcp --dport "$port" -j ACCEPT; done
        IFS=',' read -ra UDP_PORTS <<< "$ATTACK_UDP_PORTS"
        for port in "${UDP_PORTS[@]}"; do iptables -A INPUT -p udp --dport "$port" -j ACCEPT; done
    fi

    echo "attack" > "$MODE_FILE"
    if [[ -d /etc/iptables ]]; then
        iptables-save > /etc/iptables/rules.attack.v4
    fi
    log "✅ Modo Attack activo."
}

# ==================== INSTALACIÓN ====================

install_dependencies() {
    log "📦 Instalando dependencias..."
    apt update -qq || true
    apt install -y -qq iptables-persistent fail2ban tor tor-geoipdb resolvconf macchanger apparmor apparmor-utils curl
}

configure_tor_dns() {
    log "🧅 Configurando Tor para DNS..."
    if [[ -f /etc/tor/torrc ]]; then
        if ! grep -q "DNSPort 5353" /etc/tor/torrc; then
            cat >> /etc/tor/torrc <<EOF

DNSPort 5353
AutomapHostsOnResolve 1
AvoidDiskWrites 1
EOF
        fi
        systemctl restart tor || true
    else
        log "⚠️ Archivo /etc/tor/torrc no encontrado. Omitiendo configuración de Tor."
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
maxretry = 3
bantime = 1h
EOF
    systemctl restart fail2ban || true
}

install_secure_c2() {
    echo
    read -p "🔧 ¿Deseas configurar una red C2 segura (Tailscale/ZeroTier)? [S/n] " choice
    case "$choice" in
        n|N) log "Instalación de C2 omitida."; return ;; 
    esac

    echo "  t) Tailscale (recomendado)"
    echo "  z) ZeroTier"
    read -p "Elige una opción: " c2_choice

    case "$c2_choice" in
        t)  log "Instalando Tailscale..."
            curl -fsSL https://tailscale.com/install.sh | sh || true
            echo "📌 ¡Acción requerida! Ejecuta 'sudo tailscale up' para autenticarte."
            ;;
        z)  log "Instalando ZeroTier..."
            curl -s https://install.zerotier.com | sudo bash || true
            read -p "Introduce tu Network ID de ZeroTier: " nid
            zerotier-cli join "$nid" || true
            ;;
        *) log "Opción no válida. Omitiendo instalación de C2.";;
    esac
}

install_all() {
    log "🚀 Iniciando instalación de KaliDefender v4.2..."
    
    mkdir -p "$CONFIG_DIR"
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"

    install_dependencies
    configure_tor_dns
    configure_mac_randomization
    configure_fail2ban
    install_apparmor_metasploit
    install_secure_c2

    # Copiar script y crear servicio
    cp "$0" /usr/local/bin/kalidefender.sh
    chmod +x /usr/local/bin/kalidefender.sh

    cat > /etc/systemd/system/kalidefender.service <<'EOF'
[Unit]
Description=KaliDefender v4.2 - Servicio de Seguridad
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

    # Iniciar en modo Stealth
    mode_stealth

    log "✅ Instalación completa. KaliDefender está activo en Modo Stealth."
    echo "📌 Usa: sudo kalidefender.sh {stealth|attack|toggle|status|help}"
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
    echo "📊 ESTADO DE KALIDEFENDER v4.2"
    echo "=================================="
    
    if [[ -f "$MODE_FILE" ]]; then
        echo "🔷 Modo actual: $(cat "$MODE_FILE" | tr 'a-z' 'A-Z')"
    else
        echo "🔷 Modo actual: NO CONFIGURADO"
    fi

    echo
    echo "🛡️ AppArmor para Metasploit:"
    if command -v aa-status &>/dev/null && aa-status --enabled &>/dev/null && aa-status | grep -q "msfconsole"; then
        echo "  ✅ Activo y perfil cargado"
    else
        echo "  ⚠️ Inactivo o no encontrado"
    fi

    echo
    echo "🌐 Red C2 Privada:"
    if systemctl is-active --quiet tailscaled 2>/dev/null; then
        echo "  ✅ Tailscale activo - IP: $(tailscale ip -4 2>/dev/null || echo 'N/A')"
    elif systemctl is-active --quiet zerotier-one 2>/dev/null; then
        local nets
        nets=$(zerotier-cli listnetworks -j 2>/dev/null | grep -o '[0-9a-f]\{16\}' || echo "N/A")
        echo "  ✅ ZeroTier activo - Redes: $nets"
    else
        echo "  ❌ No detectada"
    fi

    echo
    echo "🔌 Puertos de entrada (INPUT) abiertos:"
    iptables -L INPUT -n --line-numbers | grep ACCEPT | sed 's/^/  /' || echo "  Ninguno"

    echo
    echo "📡 Test de conectividad a Internet:"
    if timeout 3 curl -s https://httpbin.org/ip &>/dev/null; then
        echo "  ✅ Conexión exitosa"
    else
        echo "  ❌ Fallo en la conexión"
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
    KaliDefender v4.2 — Sistema Dual Stealth/Attack para Pentesters

    Uso: sudo kalidefender.sh [COMANDO]

    COMANDOS:
      install   Instala y configura KaliDefender.
      stealth   Activa el Modo Stealth (privacidad máxima con Tor).
      attack    Activa el Modo Attack (pentesting con C2 seguro).
      toggle    Alterna entre los modos Stealth y Attack.
      status    Muestra el estado actual del sistema de seguridad.
      help      Muestra este mensaje de ayuda.

    FLUJO DE TRABAJO RECOMENDADO:
      1. Ejecuta `sudo ./kalidefender.sh install`.
      2. Mantén el sistema en `stealth` para reconocimiento.
      3. Cambia a `attack` para la fase de explotación.
      4. Vuelve a `stealth` al finalizar el engagement.

    Para más detalles, consulta la documentación en GitHub.
EOF
}

# ==================== MAIN ====================

main() {
    check_root
    
    case "${1:-help}" in
        install)    install_all ;;
        stealth)    mode_stealth ;;
        attack)     mode_attack ;;
        toggle)     mode_toggle ;;
        status)     mode_status ;;
        start)      start_service ;;
        help)       print_help ;;
        *)          echo "Comando no válido." ; print_help ; exit 1 ;;
    esac
}

main "$@"
