#!/usr/bin/env python3
"""
KaliDefender Hybrid Network Manager v5.0.0
Gestiona configuraciones avanzadas de Tailscale y ZeroTier para KaliDefender.
Inspirado en la lógica de gestión de labs y aislamiento de redes.
"""

import os
import sys
import json
import subprocess
import argparse
import logging
from pathlib import Path
from typing import Dict, List, Optional, Any

# Configuración mejorada de logging
LOG_PATH = Path("/var/log/kalidefender_net.log")

def setup_logging() -> logging.Logger:
    """Configura el logging con manejo seguro de permisos"""
    logger = logging.getLogger('HybridNet')
    logger.setLevel(logging.INFO)
    
    # Formatter
    formatter = logging.Formatter(
        '%(asctime)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    
    # Handler para consola (siempre disponible)
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)
    
    # Handler para archivo (solo si tenemos permisos)
    try:
        if LOG_PATH.parent.exists() or os.geteuid() == 0:
            file_handler = logging.FileHandler(LOG_PATH, mode='a')
            file_handler.setFormatter(formatter)
            logger.addHandler(file_handler)
    except (PermissionError, OSError) as e:
        logger.warning(f"No se pudo escribir en {LOG_PATH}: {e}")
        logger.info("Usando solo logging por consola")
    
    return logger

logger = setup_logging()


class NetworkManager:
    """Gestor de redes híbridas para KaliDefender"""
    
    @staticmethod
    def run_command(cmd: List[str], timeout: int = 30) -> str:
        """Ejecuta un comando con manejo robusto de errores"""
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=True,
                timeout=timeout
            )
            return result.stdout.strip()
        except subprocess.CalledProcessError as e:
            logger.debug(f"Error en comando {' '.join(cmd)}: {e.stderr[:200] if e.stderr else 'sin detalle'}")
            return ""
        except subprocess.TimeoutExpired:
            logger.error(f"Timeout ejecutando {' '.join(cmd)}")
            return ""
        except FileNotFoundError:
            logger.debug(f"Comando no encontrado: {cmd[0]}")
            return ""
        except Exception as e:
            logger.error(f"Error inesperado en {' '.join(cmd)}: {str(e)}")
            return ""

    def get_tailscale_status(self) -> Dict[str, Any]:
        """Obtiene el estado de Tailscale con validación JSON robusta"""
        status_raw = self.run_command(["tailscale", "status", "--json"])
        if not status_raw:
            return {"active": False, "error": "Tailscale no está activo o no instalado"}
        
        try:
            data = json.loads(status_raw)
            self_data = data.get("Self", {})
            ips = self_data.get("TailscaleIPs", [])
            
            return {
                "active": True,
                "ip": ips[0] if ips else "N/A",
                "exit_node": data.get("ExitNodeStatus") is not None,
                "hostname": self_data.get("HostName", "unknown")
            }
        except json.JSONDecodeError as e:
            logger.error(f"Error parseando JSON de Tailscale: {e}")
            return {"active": False, "error": "JSON inválido"}

    def get_zerotier_status(self) -> Dict[str, Any]:
        """Obtiene el estado de ZeroTier con validación mejorada"""
        networks_raw = self.run_command(["zerotier-cli", "listnetworks", "-j"])
        if not networks_raw:
            return {"active": False, "error": "ZeroTier no está activo o no instalado"}
        
        try:
            networks = json.loads(networks_raw)
            if not isinstance(networks, list):
                return {"active": False, "error": "Formato de respuesta inválido"}
            
            active_nets = [n for n in networks if n.get("status") == "OK"]
            
            network_info = []
            for net in active_nets:
                info = {
                    "id": net.get("id", "unknown"),
                    "name": net.get("name", ""),
                    "ip": net.get("assignedAddresses", ["N/A"])[0] if net.get("assignedAddresses") else "N/A",
                    "type": net.get("type", "unknown")
                }
                network_info.append(info)
            
            return {
                "active": len(active_nets) > 0,
                "networks": network_info,
                "count": len(active_nets)
            }
        except json.JSONDecodeError as e:
            logger.error(f"Error parseando JSON de ZeroTier: {e}")
            return {"active": False, "error": "JSON inválido"}
        except Exception as e:
            logger.error(f"Error obteniendo estado de ZeroTier: {e}")
            return {"active": False, "error": str(e)}

    def optimize_tailscale(self) -> bool:
        """Configura Tailscale para split-tunneling y evita pérdida de conexión"""
        logger.info("Optimizando Tailscale para KaliDefender...")
        
        # Desactivar aceptación de rutas y DNS de Tailscale para evitar conflictos con Tor/Modo Stealth
        result = self.run_command([
            "tailscale", "up",
            "--accept-dns=false",
            "--accept-routes=false"
        ])
        
        if result or self.run_command(["tailscale", "status"]) != "":
            logger.info("✅ Tailscale optimizado: DNS y Rutas globales desactivadas.")
            return True
        else:
            logger.warning("⚠️ No se pudo verificar la optimización de Tailscale")
            return False

    def audit_security(self) -> List[str]:
        """Audita la configuración de red actual y devuelve hallazgos"""
        findings = []
        
        # Auditar Tailscale
        ts = self.get_tailscale_status()
        if ts.get("active"):
            if ts.get("exit_node"):
                findings.append(
                    "⚠️ ALERTA: Tailscale está usando un Exit Node. "
                    "Esto puede filtrar tráfico fuera de Tor en modo Stealth."
                )
            else:
                findings.append(f"✅ Tailscale activo (IP: {ts.get('ip', 'N/A')}) - Configuración segura")
        
        # Auditar ZeroTier
        zt = self.get_zerotier_status()
        if zt.get("active"):
            for net in zt.get("networks", []):
                findings.append(
                    f"✅ ZeroTier red {net['id']} activa con IP {net['ip']}"
                )
        elif zt.get("error") and zt.get("error") != "ZeroTier no está activo o no instalado":
            findings.append(f"⚠️ ZeroTier: {zt['error']}")
        
        if not findings:
            findings.append("ℹ️ No hay redes C2 activas detectadas")
        
        return findings
    
    def get_full_status(self) -> Dict[str, Any]:
        """Obtiene el estado completo de todas las redes"""
        return {
            "timestamp": subprocess.run(["date", "-Iseconds"], capture_output=True, text=True).stdout.strip(),
            "tailscale": self.get_tailscale_status(),
            "zerotier": self.get_zerotier_status(),
            "audit_findings": self.audit_security()
        }


def main():
    parser = argparse.ArgumentParser(
        description="KaliDefender Hybrid Network Manager v5.0.0",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos:
  %(prog)s status      - Muestra estado de redes en JSON
  %(prog)s optimize    - Optimiza Tailscale para KaliDefender
  %(prog)s audit       - Auditoría de seguridad de red
  %(prog)s full        - Estado completo con auditoría
        """
    )
    parser.add_argument(
        "action",
        choices=["status", "optimize", "audit", "full"],
        help="Acción a realizar"
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Mostrar output detallado"
    )
    
    args = parser.parse_args()

    manager = NetworkManager()

    if args.action == "status":
        status = {
            "tailscale": manager.get_tailscale_status(),
            "zerotier": manager.get_zerotier_status()
        }
        print(json.dumps(status, indent=2))
    
    elif args.action == "optimize":
        success = manager.optimize_tailscale()
        sys.exit(0 if success else 1)
    
    elif args.action == "audit":
        findings = manager.audit_security()
        for finding in findings:
            print(finding)
    
    elif args.action == "full":
        status = manager.get_full_status()
        print(json.dumps(status, indent=2))


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        logger.info("\nOperación cancelada por el usuario")
        sys.exit(130)
    except Exception as e:
        logger.error(f"Error fatal: {e}")
        if '--verbose' in sys.argv or '-v' in sys.argv:
            import traceback
            traceback.print_exc()
        sys.exit(1)
