#!/usr/bin/env python3
"""
KaliDefender Hybrid Network Manager
Gestiona configuraciones avanzadas de Tailscale y ZeroTier para KaliDefender.
Inspirado en la lógica de gestión de labs y aislamiento de redes.
"""

import os
import sys
import json
import subprocess
import argparse
import logging
from typing import Dict, List, Optional

# Configuración de logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/kalidefender_net.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('HybridNet')

class NetworkManager:
    @staticmethod
    def run_command(cmd: List[str]) -> str:
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            return result.stdout.strip()
        except subprocess.CalledProcessError as e:
            logger.error(f"Error ejecutando {' '.join(cmd)}: {e.stderr}")
            return ""

    def get_tailscale_status(self) -> Dict:
        status_raw = self.run_command(["tailscale", "status", "--json"])
        if not status_raw:
            return {"active": False}
        try:
            data = json.loads(status_raw)
            return {
                "active": True,
                "ip": data.get("Self", {}).get("TailscaleIPs", ["N/A"])[0],
                "exit_node": data.get("ExitNodeStatus") is not None
            }
        except json.JSONDecodeError:
            return {"active": False}

    def get_zerotier_status(self) -> Dict:
        networks_raw = self.run_command(["zerotier-cli", "listnetworks", "-j"])
        if not networks_raw:
            return {"active": False}
        try:
            networks = json.loads(networks_raw)
            active_nets = [n for n in networks if n.get("status") == "OK"]
            return {
                "active": len(active_nets) > 0,
                "networks": [{"id": n["id"], "ip": n.get("assignedAddresses", ["N/A"])[0]} for n in active_nets]
            }
        except json.JSONDecodeError:
            return {"active": False}

    def optimize_tailscale(self):
        """Configura Tailscale para split-tunneling y evita pérdida de conexión"""
        logger.info("Optimizando Tailscale para KaliDefender...")
        # Desactivar aceptación de rutas y DNS de Tailscale para evitar conflictos con Tor/Modo Stealth
        self.run_command(["tailscale", "up", "--accept-dns=false", "--accept-routes=false"])
        logger.info("Tailscale optimizado: DNS y Rutas globales desactivadas.")

    def audit_security(self):
        """Audita la configuración de red actual"""
        findings = []
        ts = self.get_tailscale_status()
        if ts.get("active") and ts.get("exit_node"):
            findings.append("⚠️ Tailscale está usando un Exit Node. Esto puede filtrar tráfico fuera de Tor en modo Stealth.")
        
        zt = self.get_zerotier_status()
        if zt.get("active"):
            for net in zt["networks"]:
                findings.append(f"✅ ZeroTier red {net['id']} activa con IP {net['ip']}")
        
        return findings

def main():
    parser = argparse.ArgumentParser(description="KaliDefender Hybrid Network Manager")
    parser.add_argument("action", choices=["status", "optimize", "audit"])
    args = parser.parse_args()

    manager = NetworkManager()

    if args.action == "status":
        status = {
            "tailscale": manager.get_tailscale_status(),
            "zerotier": manager.get_zerotier_status()
        }
        print(json.dumps(status, indent=2))
    elif args.action == "optimize":
        manager.optimize_tailscale()
    elif args.action == "audit":
        for finding in manager.audit_security():
            print(finding)

if __name__ == "__main__":
    main()
