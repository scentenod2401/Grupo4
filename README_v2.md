# 🎓 Grupo 4 - Reto 360 ASIR
### Infraestructura Híbrida Cloud & On-Premise

[![Proyecto](https://img.shields.io/badge/Proyecto-Reto%20360-blue)](https://github.com/scentenod2401/Grupo4)
[![ASIR](https://img.shields.io/badge/ASIR-2024--2026-green)](#)
[![Estado](https://img.shields.io/badge/Estado-En%20Desarrollo-yellow)](#)

---

## 👥 Equipo de Desarrollo

| Miembro | Rama de Trabajo |
|---------|------------------|
| **Steven** | [`Steven`](../../tree/Steven) |
| **José Manuel** | [`José-Manuel`](../../tree/José-Manuel) |
| **Marco** | [`Marco`](../../tree/Marco) |

> 📌 **Nota:** Cada miembro trabaja en su rama personal desarrollando los mismos componentes del proyecto (Proxmox + AWS + Scripts).

---

## 🏭 Arquitectura del Sistema

### 📍 Infraestructura Local (Proxmox)
- **Tailscale VPN** (LXC 100) - Acceso remoto seguro
- **MikroTik Router** (VM 101) - Gateway y routing
- **Cluster LXC** (102-109) - Servicios containerizados
  - Web Servers (HAProxy + Apache)
  - Base de Datos (MySQL/MariaDB)
  - Monitoring (Zabbix)
  - Comunicaciones (Jitsi)

### ☁️ Infraestructura Cloud (AWS)
- **VPC Multi-AZ** (10.4.0.0/16)
- **Bastion Host** + Instancia Privada
- **NAT Gateway** + Internet Gateway
- **S3 Bucket** para backups automáticos
- **SSM** para gestión sin SSH

### 🔄 Funcionalidades Avanzadas
- ⚡ Auto-escalado basado en carga CPU
- 💾 Backups automáticos a S3
- 🔐 Acceso seguro vía Tailscale
- 📊 Monitorización centralizada

---

## 📂 Estructura del Proyecto

```
grupo4/
├── proxmox/              # Infraestructura Proxmox
│   ├── despliegue_proxmox.sh
│   ├── autoescalado.sh
│   └── configuracion/
│       └── lxc-templates/
├── aws/                  # Infraestructura AWS
│   ├── cloudformation/
│   │   └── grupo4_steven_final.yaml
│   └── scripts/
│       └── dump_s3_db.sh
├── scripts/              # Utilidades compartidas
│   ├── backup/
│   │   ├── backup_bd.ps1
│   │   └── dump_bd_S3.ps1
│   └── servicios/
│       ├── reinicio_apache.ps1
│       └── reinicio_mysql.ps1
└── docs/                 # Documentación técnica
    ├── arquitectura.md
    └── instalacion.md
```

---

## 🚀 Quick Start

### Prerrequisitos
```bash
# Proxmox
- Proxmox VE 8.x
- Plantilla Debian 12 LXC
- Bridges configurados (vmbr0, vmbr1)

# AWS
- AWS Academy Account
- AWS CLI configurado
- EC2 Key Pair creado
```

### Despliegue Proxmox
```bash
# Clonar repositorio
git clone https://github.com/scentenod2401/Grupo4.git
cd Grupo4

# Cambiar a tu rama de trabajo
git checkout Steven  # O José-Manuel / Marco

# Ejecutar despliegue
cd proxmox
chmod +x despliegue_proxmox.sh
./despliegue_proxmox.sh
```

### Despliegue AWS
```bash
# Desde AWS CloudFormation Console
1. Subir template: aws/cloudformation/grupo4_steven_final.yaml
2. Introducir parámetros (KeyPair)
3. Crear stack

# O vía CLI
aws cloudformation create-stack \
  --stack-name grupo4-steven \
  --template-body file://aws/cloudformation/grupo4_steven_final.yaml \
  --parameters ParameterKey=KeyPairName,ParameterValue=tu-keypair
```

---

## 📊 Ramas de Trabajo

Cada miembro del equipo trabaja en su rama personal con la misma estructura y componentes:

### 🔹 Componentes Desarrollados
- ✅ Script de despliegue automatizado Proxmox
- ✅ Auto-escalado inteligente con snapshots  
- ✅ CloudFormation VPC completa (AWS)
- ✅ Integración S3 para backups
- ✅ Scripts PowerShell para gestión de servicios

### 🔹 Ramas Activas
- **`Steven`** - Desarrollo personal de Steven
- **`José-Manuel`** - Desarrollo personal de José Manuel
- **`Marco`** - Desarrollo personal de Marco
- **`main`** - Rama principal (merge final)

---

## 🔧 Configuración de Red

### Proxmox Network
| Segmento | CIDR | Uso | Gateway |
|----------|------|-----|---------||
| WAN (vmbr0) | DHCP | Internet + Tailscale | DHCP |
| LAN (vmbr1) | 192.168.14.0/24 | Contenedores LXC | 192.168.14.1 (MikroTik) |

### AWS Network
| Segmento | CIDR | Uso | Gateway |
|----------|------|-----|---------||
| Public Subnet | 10.4.1.0/24 | Bastion + NAT | Internet Gateway |
| Private Subnet | 10.4.2.0/24 | Instancia privada | NAT Gateway |

---

## 📖 Documentación

- 📘 [Arquitectura Completa](docs/arquitectura.md)
- 📗 [Guía de Instalación](docs/instalacion.md)
- 📕 [Troubleshooting](docs/troubleshooting.md)

---

## 🛠️ Stack Tecnológico

| Componente | Tecnología |
|------------|-----------||
| **Virtualización** | Proxmox VE 8.x, LXC Containers |
| **Cloud** | AWS (EC2, VPC, S3, CloudFormation) |
| **Networking** | MikroTik RouterOS, Tailscale VPN |
| **Automatización** | Bash, PowerShell, CloudFormation |
| **Monitorización** | Zabbix |
| **Web Stack** | Apache, PHP, MySQL/MariaDB, HAProxy |

---

## 📝 Notas del Proyecto

- **Duración:** 4 semanas
- **Metodología:** Trabajo colaborativo con ramas individuales
- **Entregable:** Infraestructura híbrida funcional y documentada

---

## 📞 Contacto

**Grupo 4 - ASIR Cantabria**
- 📧 Email: scentenod2401@educantabria.es
- 🔗 GitHub: [scentenod2401/Grupo4](https://github.com/scentenod2401/Grupo4)

---

<div align="center">
  <sub>Desarrollado con ❤️ por el Grupo 4 - ASIR 2024/2026</sub>
</div>