# 🛡️ KaliDefender v6.0.0

<p align="center">
  <img src="https://img.shields.io/badge/KaliDefender-v6.0.0-red?style=for-the-badge&logo=kali-linux&logoColor=white" alt="KaliDefender">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Kali%20Linux-blueviolet?style=flat-square&logo=linux&logoColor=white">
  <img src="https://img.shields.io/badge/Bash-5.0%2B-green?style=flat-square&logo=gnu-bash&logoColor=white">
  <img src="https://img.shields.io/badge/Python-3.8%2B-blue?style=flat-square&logo=python&logoColor=white">
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=flat-square">
  <img src="https://img.shields.io/badge/Security-Paranoid-red?style=flat-square">
</p>

---

## 📌 Overview

KaliDefender is a hardened network orchestration framework for offensive security operations on Kali Linux.

It allows operators to instantly switch between two completely isolated network postures:

| Mode | Purpose |
|---|---|
| 🥷 Stealth | Anonymous reconnaissance & OSINT (Tor TransProxy) |
| ⚔️ Attack | Active pentesting & C2 operations (Tailscale/ZeroTier) |

---

## ✨ Features

- **Modular Architecture:** Fully restructured code into independent modules.
- **Secure Web Dashboard:** REST API with Bearer Token authentication and HTTPS.
- **Atomic Firewall:** Instant rule application using `iptables-restore`.
- **Full Tor TransProxy Routing:** Complete traffic anonymization.
- **DNS through Tor:** Secure and immutable DNS configuration.
- **Tailscale & ZeroTier Detection:** Automatic C2 network detection and split-tunneling.
- **Fail2Ban Integration:** Adaptive banning for SSH, HTTP, and HTTPS.
- **AppArmor Integration:** Hardened profiles for Metasploit, Nmap, and BurpSuite.
- **WireGuard Server/Client:** Built-in VPN management.
- **Cobalt Strike Integration:** Hardening, Malleable C2 profiles, and redirectors.
- **Multi-Interface Support:** MAC randomization and interface priority management.
- **Backup & Restore System:** Complete system state backup and restoration.
- **Structured JSON Logging:** Ready for SIEM integration.

---

## 📁 Repository Structure

```text
KaliDefender/
├── README.md
├── CHANGELOG.md
├── GUIDE.md
├── INSTALL.md
├── UNINSTALL.md
├── LICENSE
├── kalidefender.sh
├── kalidefender_uninstall.sh
├── hybrid_net_manager.py
└── defaults.conf
```

---

## 🚀 Installation

```bash
git clone https://github.com/Hunt3r850/KaliDefender.git
cd KaliDefender
chmod +x *.sh
sudo ./kalidefender.sh install
```

---

## ⚡ Quick Commands

```bash
sudo kalidefender stealth
sudo kalidefender attack
sudo kalidefender toggle
sudo kalidefender status
sudo kalidefender dashboard
sudo kalidefender backup
sudo kalidefender restore <backup_name>
sudo kalidefender wg-server
sudo kalidefender cobalt-strike
sudo kalidefender randomize-mac eth0
```

---

## 🔐 Security Philosophy

KaliDefender follows:

- **Modularity:** Independent components for firewall, modes, C2, and security.
- **Atomicity:** Firewall rules are applied atomically to prevent lockouts.
- **Idempotence:** Commands can be run multiple times safely.
- **Fail-Safe Design:** Strict error handling and dependency checking.
- **Traceability:** Structured logging for all actions.

---

## 🛣️ Roadmap

- nftables support
- Sliver integration
- Mythic integration
- React dashboard
- SIEM connectors
- Automated testing
- .deb packaging

---

## 📄 License

MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

⚠️ **Aviso de Responsabilidad:** KaliDefender es una herramienta diseñada exclusivamente para:

✅ Profesionales de seguridad autorizados
✅ Pentesters con autorización explícita por escrito
✅ Investigadores de seguridad en entornos controlados
✅ Uso educativo

---

## ⚠️ Disclaimer

This project is intended strictly for authorized security testing, research, and educational environments.

Unauthorized usage is the sole responsibility of the operator.

---

## 👤 Author

Hunt3r850 && AHByte
