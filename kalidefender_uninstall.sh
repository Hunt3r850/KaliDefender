#!/bin/bash
# KaliDefender v4.2 - Desinstalador Oficial
# Elimina de forma segura todas las configuraciones y servicios de KaliDefender.

set -euo pipefail

# ==================== UTILIDADES ====================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "❌ Error: Este script requiere privilegios de superusuario (sudo)." >&2
        exit 1
    fi
}

# ==================== FUNCIONES DE LIMPIEZA ====================

restore_firewall() {
    log "🔥 Restaurando reglas de firewall..."
    iptables -F || true
    iptables -X || true
    iptables -t nat -F || true
    iptables -t nat -X || true
    iptables -P INPUT ACCEPT || true
    iptables -P OUTPUT ACCEPT || true
    iptables -P FORWARD ACCEPT || true
    
    if command -v ip6tables &>/dev/null; then
        ip6tables -F || true
        ip6tables -X || true
        ip6tables -P INPUT ACCEPT || true
        ip6tables -P OUTPUT ACCEPT || true
        ip6tables -P FORWARD ACCEPT || true
    fi
    
    rm -f /etc/iptables/rules.stealth.v4 /etc/iptables/rules.attack.v4
    log "✅ Firewall restaurado a políticas por defecto."
}

restore_dns() {
    log "🌐 Restaurando configuración de DNS..."
    chattr -i /etc/resolv.conf 2>/dev/null || true
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo "nameserver 1.1.1.1" >> /etc/resolv.conf
    log "✅ DNS restaurado a servidores públicos."
}

remove_apparmor_profiles() {
    log "🛡️ Eliminando perfiles de AppArmor para Metasploit..."
    if command -v aa-remove-unknown &>/dev/null; then
        aa-remove-unknown 2>/dev/null || true
    fi
    
    if [[ -f /etc/apparmor.d/usr.bin.msfconsole ]]; then
        if command -v apparmor_parser &>/dev/null; then
            apparmor_parser -R /etc/apparmor.d/usr.bin.msfconsole 2>/dev/null || true
        fi
        rm -f /etc/apparmor.d/usr.bin.msfconsole
    fi
    
    systemctl reload apparmor 2>/dev/null || true
    log "✅ Perfiles de AppArmor eliminados."
}

remove_fail2ban_config() {
    log "🛡️ Eliminando configuración de Fail2Ban..."
    rm -f /etc/fail2ban/filter.d/kalidefender.conf
    rm -f /etc/fail2ban/jail.d/kalidefender.local
    systemctl restart fail2ban 2>/dev/null || true
    log "✅ Configuración de Fail2Ban eliminada."
}

remove_service_and_binary() {
    log "⚙️ Eliminando servicio y binario..."
    systemctl disable --now kalidefender.service 2>/dev/null || true
    rm -f /etc/systemd/system/kalidefender.service
    rm -f /usr/local/bin/kalidefender.sh
    systemctl daemon-reload 2>/dev/null || true
    log "✅ Servicio y binario eliminados."
}

remove_config_files() {
    log "📄 Eliminando archivos de configuración y logs..."
    rm -rf /etc/kalidefender/
    rm -f /var/log/kalidefender.log
    log "✅ Archivos de configuración y logs eliminados."
}

remove_mac_randomization() {
    log "📡 Eliminando configuración de aleatorización de MAC..."
    if [[ -f /etc/NetworkManager/conf.d/00-macrandomize.conf ]]; then
        rm -f /etc/NetworkManager/conf.d/00-macrandomize.conf
        systemctl restart NetworkManager 2>/dev/null || true
    fi
    log "✅ Configuración de aleatorización de MAC eliminada."
}

# ==================== MAIN ====================

main() {
    check_root
    log "🧹 Iniciando desinstalación completa de KaliDefender v4.2..."

    # Si no es interactivo (como en pruebas), no pedir confirmación
    if [[ -t 0 ]]; then
        read -p "❓ ¿Estás seguro de que deseas desinstalar KaliDefender? [s/N] " choice
        if [[ "$choice" != "s" && "$choice" != "S" ]]; then
            log "Desinstalación cancelada."
            exit 0
        fi
    fi

    restore_firewall
    restore_dns
    remove_apparmor_profiles
    remove_fail2ban_config
    remove_service_and_binary
    remove_config_files
    remove_mac_randomization

    echo
    log "✅ Desinstalación de KaliDefender completada."
    log "💡 Es posible que algunos paquetes (como tor, tailscale) sigan instalados. Puedes eliminarlos manualmente si lo deseas con 'sudo apt purge <paquete>'."
    log "💡 Si experimentas problemas de red, prueba a reiniciar: sudo systemctl restart NetworkManager"
}

main "$@"
