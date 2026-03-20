<div align="center">

<img src="https://img.shields.io/badge/ZTE-OLT%20Manager-blue?style=for-the-badge&logo=network-wired&logoColor=white" />
<img src="https://img.shields.io/badge/Flask-2.x-black?style=for-the-badge&logo=flask&logoColor=white" />
<img src="https://img.shields.io/badge/Celery-Worker-37814A?style=for-the-badge&logo=celery&logoColor=white" />
<img src="https://img.shields.io/badge/Redis-Queue-DC382D?style=for-the-badge&logo=redis&logoColor=white" />
<img src="https://img.shields.io/badge/Docker-Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white" />
<img src="https://img.shields.io/badge/Nginx-Proxy-009639?style=for-the-badge&logo=nginx&logoColor=white" />

<br/><br/>

# 🚀 ZTE OLT Manager
### Automated TR-069 Bulk Configuration Tool for ZTE OLT Devices (C300 / C320)

*Efficiently configure hundreds of ONTs in minutes — with live console feedback.*

</div>

---

## 📋 Overview

**ZTE OLT Manager** is a web-based automation tool that bulk-configures ONTs on ZTE OLT devices via TR-069. It connects to your OLT over SSH, discovers all working ONTs across all ports and cards, and pushes configuration commands (ACS URL, DNS server, inform enable) — then reboots each ONT automatically.

Built for ISPs and network engineers who manage large-scale GPON deployments.

---

## ✨ Features

| Feature | Description |
|---|---|
| 🔁 **Bulk TR-069 Config** | Pushes ACS URL, DNS server, and inform enable to all working ONTs |
| 📡 **GTGH & GTGO Support** | Supports both 16-port (GTGH) and 8-port (GTGO) card types |
| ⚡ **Background Processing** | Non-blocking task execution via Celery + Redis |
| 🖥️ **Live Console** | Real-time log streaming on the web dashboard |
| 🐳 **Dockerized** | One-command deployment with Docker Compose |
| 🔒 **HTTPS Ready** | Auto SSL via Let's Encrypt + Nginx reverse proxy |
| 🔄 **Auto Port Detection** | Finds a free host port from 5501+ to avoid conflicts |

---

## 🏗️ Architecture

```
Browser
   │
   ▼
Nginx (HTTPS :443)
   │
   ▼
Flask App (:5000 inside container)
   │           │
   ▼           ▼
Celery      Redis
Worker      Queue
   │
   ▼
ZTE OLT (SSH)
   │
   ▼
ONTs (TR-069 configured)
```

---

## 🛠️ Tech Stack

- **Backend:** Python 3, Flask
- **Task Queue:** Celery + Redis
- **SSH Automation:** Netmiko (`zte_zxros`)
- **Frontend:** Bootstrap 5 (live dashboard)
- **Infrastructure:** Docker, Docker Compose, Nginx, Certbot

---

## ⚙️ Configuration Fields

| Field | Description | Default |
|---|---|---|
| **IP** | OLT management IP address | `103.151.33.146` |
| **Port** | SSH port | `2202` |
| **Card Type** | GTGH (16-port) or GTGO (8-port) | `GTGH` |
| **Username** | OLT SSH username | — |
| **Password** | OLT SSH password | — |
| **ACS URL** | TR-069 ACS server URL | `http://oma.maxnetplus.id:7547` |
| **DNS Server** | DNS server pushed to ONTs via `tr069-mgmt 1 dns` | `103.151.33.1` |

---

## 🚀 Quick Start

### Prerequisites

- A Linux server (Ubuntu 22.04+ recommended) with root access
- Domain pointing to your server's IP
- Ports 80 and 443 open

### Deploy

```bash
git clone https://github.com/adhielesmana/zte-olt-manager.git
cd zte-olt-manager
chmod +x deploy.sh
./deploy.sh
```

The deploy script will:
1. Install Certbot and Docker (skips Nginx — uses existing installation)
2. Write a clean HTTP-only Nginx config for your domain
3. Obtain an SSL certificate via Let's Encrypt (`certbot certonly`)
4. Write the full HTTPS Nginx config with proper proxy headers
5. Auto-detect a free host port starting from **5501**
6. Start the app with `docker compose up -d --build`

### Manual Docker Start (development)

```bash
echo "APP_PORT=5501" > .env
docker compose up --build
```

App will be available at `http://localhost:5501`

---

## 📟 Commands Pushed to Each ONT

For every working ONT discovered, the following commands are sent:

```
pon-onu-mng <gpon-olt_1/card/port:onu_num>
  tr069-mgmt 1 acs <ACS_URL>
  tr069-mgmt 1 dns <DNS_SERVER>
  tr069-mgmt 1 inform enable
  exit

interface gpon-olt_1/<card>/<port>
  onu reboot <onu_num>
  exit
```

---

## 📁 Project Structure

```
zte-olt-manager/
├── app.py                  # Flask app + Celery task (bulk update logic)
├── docker-compose.yml      # Docker services: web, worker, redis
├── Dockerfile              # App container definition
├── deploy.sh               # Production deploy script
├── requirements.txt        # Python dependencies
├── .env                    # Auto-generated: APP_PORT
└── templates/
    └── index.html          # Web dashboard UI
```

---

## 🔁 Re-deploy (Updates)

```bash
git pull
docker compose up -d --build
```

---

## 🛡️ Security Notes

- The deploy script uses `certbot certonly --nginx` — it does **not** auto-modify other Nginx vhosts.
- The deploy script uses `systemctl reload nginx` (not restart) to keep other domains alive.
- Credentials are sent over HTTPS only.

---

## 📄 License

MIT License — free to use and modify.

---

<div align="center">
Made with ❤️ for ISP engineers · <a href="https://maxnetplus.id">maxnetplus.id</a>
</div>
