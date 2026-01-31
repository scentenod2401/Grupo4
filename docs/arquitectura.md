# 🏭 Arquitectura del Sistema - Grupo 4

## Visión General

Este documento describe la arquitectura completa de la infraestructura híbrida del Grupo 4, que combina recursos locales en Proxmox con servicios en la nube de AWS.

---

## 📍 Infraestructura Local (Proxmox)

### Topología de Red

```
                     INTERNET
                        │
                        │
         ┌──────────┬──────────┐
         │            │            │
      vmbr0 (WAN)   vmbr1 (LAN)     │
      DHCP          192.168.14.0/24 │
         │            │            │
    ┌────┼────┐       │            │
    │    │    │       │            │
  [100] [101] │    [101]          │
 Tailsc Mikro │   MikroTik        │
   ale  tik   │    .14.1          │
        eth0  │    eth1           │
              │       │            │
              │    [┌──┴──────────┐
              │    │ 102-109 LXC  │
              │    │ .14.10-.17   │
              │    └────────────┘
              │
         TAILSCALE VPN
```

### Contenedores LXC

| ID | Hostname | IP | Red | Función |
|----|----------|-----|-----|--------|
| 100 | tailscale | DHCP | vmbr0 (WAN) | VPN para acceso remoto |
| 101 | mikrotik | DHCP (eth0)<br>192.168.14.1 (eth1) | vmbr0+vmbr1 | Router/Gateway |
| 102 | web | 192.168.14.10 | vmbr1 (LAN) | Servidor Web |
| 103 | bd | 192.168.14.11 | vmbr1 (LAN) | Base de Datos |
| 104 | haproxy | 192.168.14.12 | vmbr1 (LAN) | Load Balancer |
| 105 | zabbix | 192.168.14.13 | vmbr1 (LAN) | Monitorización |
| 106 | jitsi | 192.168.14.14 | vmbr1 (LAN) | Videoconferencia |
| 107 | plantilla1 | 192.168.14.15 | vmbr1 (LAN) | Servidor adicional |
| 108 | plantilla2 | 192.168.14.16 | vmbr1 (LAN) | Servidor adicional |
| 109 | plantilla3 | 192.168.14.17 | vmbr1 (LAN) | Base auto-escalado |

### Especificaciones Técnicas

- **Plantilla Base:** Debian 12 Standard LXC
- **CPU:** 2 cores por contenedor
- **RAM:** 4096 MB por contenedor
- **Disco:** 40 GB por contenedor
- **Bridges:** vmbr0 (WAN/DHCP), vmbr1 (LAN/192.168.14.0/24)

---

## ☁️ Infraestructura Cloud (AWS)

### Topología VPC

```
            AWS Cloud (us-east-1)
      ┌───────────────────────────┐
      │    VPC 10.4.0.0/16             │
      │                                │
      │  ┌───────────────────────┐  │
      │  │  Public Subnet        │  │
      │  │  10.4.1.0/24          │  │
      │  │                        │  │
      │  │  [Bastion Host]       │  │
      │  │  [NAT Gateway]        │  │
      │  └──────┬───────────────┘  │
      │         │                    │
      │      [IGW]                   │
      │         │                    │
      │  ┌──────┴───────────────┐  │
      │  │  Private Subnet       │  │
      │  │  10.4.2.0/24          │  │
      │  │                        │  │
      │  │  [Private Instance]   │  │
      │  └───────────────────────┘  │
      │                                │
      │  [S3 Bucket]                  │
      │  grupo4-steven-*              │
      └───────────────────────────┘
```

### Componentes AWS

| Recurso | Tipo | CIDR/IP | Función |
|---------|------|---------|--------|
| VPC | Virtual Private Cloud | 10.4.0.0/16 | Red virtual aislada |
| Public Subnet | Subnet | 10.4.1.0/24 | Recursos con acceso público |
| Private Subnet | Subnet | 10.4.2.0/24 | Recursos sin acceso directo a internet |
| Internet Gateway | IGW | - | Salida a internet desde VPC |
| NAT Gateway | NAT | 10.4.1.x | Salida a internet desde subnet privada |
| Bastion Host | t3.nano | 10.4.1.x | Punto de acceso SSH |
| Private Instance | t3.nano | 10.4.2.x | Servidor privado con SSM |
| S3 Bucket | Storage | - | Almacenamiento backups BD |

---

## 🔄 Auto-Escalado (Proxmox)

### Mecanismo

El sistema de auto-escalado monitoriza la carga CPU del contenedor base (LXC 109) y clona instancias automáticamente según umbrales:

- **Umbral Superior:** CPU > 2.0 → Crear clon
- **Umbral Inferior:** CPU < 1.5 → Eliminar clon
- **Clones Máximos:** 2 (IDs 200-201)

### Flujo de Escalado

```
Monitoreo CPU (109)
     │
     │ CPU > 2.0?
     ├─── SÍ → Crear snapshot
     │         │
     │         └─→ Clonar a 200/201
     │             │
     │             └─→ Asignar IP .200/.201
     │
     │ CPU < 1.5?
     └─── SÍ → Eliminar clon 201/200
               │
               └─→ Limpiar snapshots
```

---

## 💾 Sistema de Backups

### Backup de Base de Datos a S3

1. **Dump local:** `mysqldump` genera archivo SQL
2. **Compresión:** Gzip reduce tamaño
3. **Subida S3:** AWS CLI sube a `s3://grupo4-steven-*/backups/`
4. **Timestamp:** Cada backup incluye fecha/hora
5. **Logs:** Registro en `/var/log/backup-bd.log`

---

## 🔐 Seguridad

### Proxmox
- LXC unprivileged (no root en host)
- Firewall habilitado en interfaces
- Passwords configurables
- Tailscale VPN para acceso remoto

### AWS
- Security Groups restrictivos
- Bastion como único punto de entrada SSH
- Instancia privada sin IP pública
- SSM Session Manager (sin SSH directo)
- S3 con acceso bloqueado público
- IAM roles con LabInstanceProfile

---

## 📊 Monitorización
- **Zabbix (LXC 105):** Monitorización centralizada de infraestructura
- **CloudWatch (AWS):** Métricas nativas de instancias EC2
- **Logs locales:** `/var/log/` en cada contenedor

---

## 🔗 Conectividad

### Acceso Remoto
- **Tailscale VPN:** Acceso seguro a red Proxmox desde cualquier lugar
- **Bastion Host (AWS):** SSH jump server para instancia privada
- **SSM (AWS):** Acceso sin SSH vía AWS Systems Manager

### Inter-Conectividad
- **LAN Proxmox:** Comunicación directa entre LXC vía 192.168.14.0/24
- **AWS Subnets:** Routing entre subnets vía Route Tables
- **Internet:** MikroTik + NAT Gateway proveen salida a internet

---

**Documento actualizado:** 31 de enero de 2026