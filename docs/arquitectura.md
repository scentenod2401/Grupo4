# 🏭 Arquitectura del Sistema - Grupo 4

> ⚠️ **Work in Progress:** Este documento está en desarrollo activo y se actualizará conforme avance el proyecto.

## Visión General

Este documento describe la arquitectura completa de la infraestructura híbrida del Grupo 4, que combina recursos locales en Proxmox con servicios en la nube de AWS.

---

## 📍 Infraestructura Local (Proxmox)

### Servidor Proxmox

| Componente | Dirección | Puerto | Descripción |
|------------|-----------|--------|-------------|
| **Proxmox VE** | `192.168.31.104` | `8006` | Panel de administración Proxmox |
| **ProxMenux Monitor** | `192.168.31.104` | `8008` | Sistema de monitorización |
| **HAProxy Stats** | `192.168.31.224` | `9999` | Panel de estadísticas HAProxy (`/stats`) |

### Topología de Red

```
                     INTERNET
                        │
                 [Router Principal]
                   192.168.31.1
                        │
         ┌──────────────┴───────────────┐
         │                              │
    Red Principal              Servidor Proxmox
    192.168.31.0/24           192.168.31.104
         │                              │
         │                    ┌─────────┴─────────┐
         │                    │                   │
         │                 vmbr0 (WAN)       vmbr1 (LAN)
         │              192.168.31.0/24   192.168.14.0/24
         │                    │                   │
    ┌────┴────────┐      ┌────┼────────┐          │
    │             │      │    │        │          │
 [Tailscale]  [Otros]  [100] [101]    │       [101]
 192.168.31.204       Tailsc MikroTik │     MikroTik
                        LXC    VM      │     Gateway
                              WAN:     │     LAN:
                           192.168.31.224   192.168.14.1
                              eth0     │     eth1
                         (HAProxy:9999)│       │
                                       │    [┌──┴──────────┐
                                       │    │ LXC 102-109  │
                                       │    │ .14.10-.17   │
                                       │    └──────────────┘
                                       │
                                  TAILSCALE VPN
                              (Acceso Remoto Seguro)
```

### Direccionamiento IP Detallado

#### Red Principal (192.168.31.0/24)
| Dispositivo | IP | Función |
|-------------|-----|--------|
| Router Principal | 192.168.31.254 | Gateway a Internet |
| Servidor Proxmox | 192.168.31.104 | Host de virtualización |
| Tailscale (Host) | 192.168.31.204 | VPN para acceso remoto |
| MikroTik WAN | 192.168.31.224 | Router virtual (interfaz WAN) + HAProxy Stats |

#### Red LAN Interna (192.168.14.0/24)
| ID | Hostname | IP | Tipo | Función |
|----|----------|-----|------|--------|
| 100 | tailscale | 192.168.31.204 (bridge a host) | LXC | VPN Tailscale en contenedor |
| 101 | mikrotik | 192.168.31.224 (eth0 WAN)<br>192.168.14.1 (eth1 LAN) | VM | Router/Gateway/Firewall + HAProxy Proxy |
| 102 | web | 192.168.14.10 | LXC | Servidor Web Apache/PHP |
| 103 | bd | 192.168.14.11 | LXC | Base de Datos MySQL/MariaDB |
| 104 | haproxy | 192.168.14.12 | LXC | Load Balancer (backend) |
| 105 | zabbix | 192.168.14.13 | LXC | Monitorización Zabbix |
| 106 | jitsi | 192.168.14.14 | LXC | Videoconferencia Jitsi |
| 107 | plantilla1 | 192.168.14.15 | LXC | Servidor adicional |
| 108 | plantilla2 | 192.168.14.16 | LXC | Servidor adicional |
| 109 | plantilla3 | 192.168.14.17 | LXC | Base para auto-escalado |
| 200-201 | clones | 192.168.14.200-201 | LXC | Clones automáticos (escalado) |

### Configuración de Bridges Proxmox

| Bridge | Red | Función | Conectividad |
|--------|-----|---------|-------------|
| **vmbr0** | 192.168.31.0/24 | WAN/Internet | Conectado a red principal, acceso a internet |
| **vmbr1** | 192.168.14.0/24 | LAN Interna | Red privada para contenedores LXC |

### Especificaciones Técnicas por Contenedor

| Recurso | Valor Estándar | Notas |
|---------|----------------|-------|
| **Sistema Operativo** | Debian 12 Standard | Plantilla LXC oficial |
| **CPU** | 2 cores | Por contenedor |
| **RAM** | 4096 MB (4 GB) | Por contenedor |
| **Disco** | 40 GB | Almacenamiento por contenedor |
| **Modo LXC** | Unprivileged | Mayor seguridad |

### Flujo de Tráfico

```
Internet
   ↓
Router Principal (192.168.31.1)
   ↓
Proxmox Host (192.168.31.104)
   ↓
┌──────────────┬─────────────────┐
│              │                 │
vmbr0 (WAN)   vmbr1 (LAN)
│              │
│              MikroTik Router (101)
│              192.168.14.1
│              │
│              ├─→ Web (102) - .14.10
│              ├─→ BD (103) - .14.11
│              ├─→ HAProxy (104) - .14.12
│              ├─→ Zabbix (105) - .14.13
│              ├─→ Jitsi (106) - .14.14
│              ├─→ Plantilla1 (107) - .14.15
│              ├── Plantilla2 (108) - .14.16
│              └─→ Plantilla3 (109) - .14.17
│
Tailscale (100) - .31.204
(Acceso remoto VPN)

MikroTik WAN (192.168.31.224)
  └─→ HAProxy Stats Web: :9999/stats
```

---

## ☁️ Infraestructura Cloud (AWS)

### Topología VPC

```
            AWS Cloud (us-east-1)
      ┌───────────────────────────────┐
      │    VPC 10.4.0.0/16            │
      │                               │
      │  ┌─────────────────────────┐  │
      │  │  Public Subnet          │  │
      │  │  10.4.1.0/24 (AZ-A)     │  │
      │  │                         │  │
      │  │  [Bastion Host]         │  │
      │  │  EC2 t3.nano            │  │
      │  │                         │  │
      │  │  [NAT Gateway]          │  │
      │  │  Elastic IP             │  │
      │  └──────┬──────────────────┘  │
      │         │                     │
      │      [Internet Gateway]       │
      │         │                     │
      │  ┌──────┴──────────────────┐  │
      │  │  Private Subnet         │  │
      │  │  10.4.2.0/24 (AZ-A)     │  │
      │  │                         │  │
      │  │  [Private Instance]     │  │
      │  │  EC2 t3.nano            │  │
      │  │  + SSM Agent            │  │
      │  └─────────────────────────┘  │
      │                               │
      │  [S3 Bucket]                  │
      │  grupo4-steven-*              │
      │  └─→ /backups/               │
      │      └─→ bd_dump_*.sql.gz    │
      └───────────────────────────────┘
```

### Componentes AWS Detallados

| Recurso | Tipo/Tamaño | CIDR/Configuración | Función |
|---------|-------------|-------------------|--------|
| **VPC** | Virtual Private Cloud | 10.4.0.0/16 | Red virtual aislada (65,536 IPs) |
| **Public Subnet** | Subnet (AZ us-east-1a) | 10.4.1.0/24 | Recursos con acceso público (256 IPs) |
| **Private Subnet** | Subnet (AZ us-east-1a) | 10.4.2.0/24 | Recursos sin acceso directo (256 IPs) |
| **Internet Gateway** | IGW | - | Salida/entrada internet para VPC |
| **NAT Gateway** | NAT + Elastic IP | Public Subnet | Internet para subnet privada |
| **Bastion Host** | EC2 t3.nano | Public Subnet | Jump server SSH (único punto entrada) |
| **Private Instance** | EC2 t3.nano | Private Subnet | Servidor backend con SSM |
| **S3 Bucket** | Object Storage | - | Backups automáticos de BD |
| **Security Groups** | Firewall | Reglas restrictivas | Control de acceso por puerto/IP |

### Tabla de Rutas

#### Public Subnet Route Table
| Destino | Target | Descripción |
|---------|--------|-------------|
| 10.4.0.0/16 | local | Tráfico interno VPC |
| 0.0.0.0/0 | Internet Gateway | Salida a internet |

#### Private Subnet Route Table
| Destino | Target | Descripción |
|---------|--------|-------------|
| 10.4.0.0/16 | local | Tráfico interno VPC |
| 0.0.0.0/0 | NAT Gateway | Salida a internet vía NAT |

---

## 🔄 Auto-Escalado Inteligente (Proxmox)

### Mecanismo de Escalado

El sistema monitoriza la carga CPU del contenedor base (LXC 109) y gestiona clones automáticamente:

**Parámetros de Configuración:**
- **Contenedor Base:** LXC 109 (192.168.14.17)
- **Umbral de Escalado:** CPU > 2.0 (200% uso)
- **Umbral de Reducción:** CPU < 1.5 (150% uso)
- **Clones Máximos:** 2 instancias (IDs 200-201)
- **IPs de Clones:** 192.168.14.200, 192.168.14.201
- **Intervalo de Monitoreo:** Cada 60 segundos

### Flujo de Trabajo del Auto-Escalado

```
[Inicio] Script autoescalado.sh ejecutándose
    ↓
[Monitor] Obtener CPU de LXC 109
    ↓
    ├─→ CPU > 2.0 (Alta carga)
    │   ↓
    │   [Verificar] ¿Hay clones activos?
    │   ↓
    │   ├─→ NO: Crear snapshot → Clonar a LXC 200
    │   │        → Configurar IP .14.200
    │   │        → Iniciar LXC 200
    │   │        → Registrar en logs
    │   │
    │   └─→ SÍ (1 clon): Clonar a LXC 201
    │                    → Configurar IP .14.201
    │                    → Iniciar LXC 201
    │                    → Máximo alcanzado
    │
    └─→ CPU < 1.5 (Baja carga)
        ↓
        [Verificar] ¿Hay clones activos?
        ↓
        └─→ SÍ: Detener último clon (201 o 200)
                → Eliminar clon
                → Limpiar snapshot
                → Registrar en logs

[Loop] Esperar 60s y repetir
```

### Comandos Clave del Script

```bash
# Obtener carga CPU
CPU_LOAD=$(pct exec $BASE_LXC -- top -bn1 | grep "Cpu(s)" | awk '{print $2}')

# Crear snapshot
pvesh create /nodes/$NODE/lxc/$BASE_LXC/snapshot --snapname auto-scale-snapshot

# Clonar contenedor
pct clone $BASE_LXC $CLONE_ID --hostname clone-$CLONE_ID

# Configurar IP estática
pct set $CLONE_ID --net0 name=eth0,bridge=vmbr1,ip=192.168.14.$IP_SUFFIX/24,gw=192.168.14.1

# Iniciar clon
pct start $CLONE_ID
```

---

## 💾 Sistema de Backups

### Backup Automático de Base de Datos a S3

**Script:** `aws/scripts/dump_s3_db.sh`

**Proceso:**
1. **Dump Database:** `mysqldump` extrae datos completos de MySQL/MariaDB
2. **Compresión:** `gzip` reduce tamaño (~70-80% reducción)
3. **Timestamp:** Formato `bd_dump_YYYYMMDD_HHMMSS.sql.gz`
4. **Upload S3:** AWS CLI sube a bucket con versionado
5. **Verificación:** Checksum MD5 para integridad
6. **Limpieza:** Elimina archivos locales antiguos (>7 días)
7. **Logging:** Registra éxito/fallo en `/var/log/backup-bd.log`

**Ejemplo de Nombre de Backup:**
```
s3://grupo4-steven-abc123/backups/bd_dump_20260131_142530.sql.gz
```

**Programación (cron):**
```bash
# Backup diario a las 02:00 AM
0 2 * * * /path/to/dump_s3_db.sh >> /var/log/backup-bd.log 2>&1
```

---

## 🔐 Seguridad

### Capa Proxmox

| Medida | Implementación | Beneficio |
|--------|----------------|----------|
| **LXC Unprivileged** | Contenedores sin privilegios root en host | Aislamiento y protección del host |
| **Firewall Habilitado** | nftables/iptables en interfaces | Control de tráfico por puerto/protocolo |
| **Red Segregada** | vmbr0 (WAN) / vmbr1 (LAN) separadas | Aislamiento de redes pública/privada |
| **Passwords Fuertes** | Contraseñas configurables por script | Autenticación robusta |
| **Tailscale VPN** | Túnel cifrado WireGuard | Acceso remoto seguro sin exponer puertos |

### Capa AWS

| Medida | Implementación | Beneficio |
|--------|----------------|----------|
| **Security Groups** | Reglas whitelist por IP/puerto | Firewall a nivel de instancia |
| **Bastion Host** | Único punto de entrada SSH | Reduce superficie de ataque |
| **Sin IP Pública** | Instancia privada sin dirección pública | Invisible desde internet |
| **SSM Session Manager** | Acceso sin SSH keys | Gestión segura sin exponer puerto 22 |
| **S3 Block Public** | Bloqueo de acceso público al bucket | Datos privados protegidos |
| **IAM Roles** | LabInstanceProfile con permisos mínimos | Principio de menor privilegio |
| **Encryption** | EBS volúmenes cifrados por defecto | Datos en reposo protegidos |

---

## 📊 Monitorización y Logging

### HAProxy Stats Dashboard

**Acceso Web:** `http://192.168.31.224:9999/stats`

**Información Disponible:**
- Estado de backends en tiempo real (up/down)
- Número de conexiones activas
- Tráfico HTTP (requests/sec)
- Latencia de respuesta por backend
- Health checks de servidores
- Distribución de carga entre servidores

**Arquitectura HAProxy:**
```
Clientes → MikroTik:9999 → HAProxy (LXC 104) → Backends
                           192.168.14.12        │
                                                ├─→ Web1 (.14.10)
                                                ├─→ Web2 (clone .14.200)
                                                └─→ Web3 (clone .14.201)
```

### Zabbix (LXC 105 - 192.168.14.13)

**Monitoriza:**
- Estado de contenedores LXC (up/down)
- Uso de CPU, RAM, disco
- Tráfico de red (interfaces vmbr0/vmbr1)
- Servicios críticos (Apache, MySQL, HAProxy)
- Auto-escalado (creación/eliminación de clones)

### CloudWatch (AWS)

**Métricas Nativas:**
- EC2: CPU, red, disco, estado de instancia
- S3: Tamaño de bucket, número de objetos
- VPC: Tráfico NAT Gateway, uso de ancho de banda

### Logs Locales

| Sistema | Ubicación | Contenido |
|---------|-----------|----------|
| **Proxmox** | `/var/log/pve/` | Logs de virtualización |
| **Auto-escalado** | `/var/log/autoescalado.log` | Eventos de escalado |
| **Backup BD** | `/var/log/backup-bd.log` | Resultados de backups |
| **Apache** | `/var/log/apache2/` | Access/error logs |
| **MySQL** | `/var/log/mysql/` | Query logs, errores |
| **HAProxy** | `/var/log/haproxy.log` | Balanceo y conexiones |

---

## 🔗 Conectividad y Accesos

### Acceso Remoto a Proxmox

**Vía Tailscale VPN:**
```bash
# Conectar a red Tailscale
tailscale up

# Acceso web a Proxmox
https://192.168.31.104:8006

# Acceso a ProxMenux Monitor
http://192.168.31.104:8008

# Acceso a HAProxy Stats
http://192.168.31.224:9999/stats

# Acceso SSH a contenedores
ssh root@192.168.14.10  # Web
ssh root@192.168.14.11  # BD
ssh root@192.168.14.12  # HAProxy
```

### Acceso a AWS

**Bastion Host (SSH Jump):**
```bash
# Conexión al bastion
ssh -i grupo4-key.pem ec2-user@<bastion-public-ip>

# Desde bastion, saltar a instancia privada
ssh ec2-user@10.4.2.x
```

**SSM Session Manager (sin SSH):**
```bash
# Requiere AWS CLI configurado
aws ssm start-session --target <instance-id>
```

### Inter-Conectividad

| Origen | Destino | Protocolo | Descripción |
|--------|---------|-----------|-------------|
| LXC 102-109 | 192.168.14.0/24 | TCP/UDP | Comunicación entre contenedores |
| LXC → Internet | 0.0.0.0/0 | TCP/UDP | Vía MikroTik (192.168.14.1) |
| Public Subnet | Private Subnet | TCP | Vía routing interno VPC |
| Private Subnet | Internet | TCP/UDP | Vía NAT Gateway |
| Tailscale | LAN Proxmox | Cifrado | Túnel WireGuard |
| MikroTik:9999 | HAProxy:80 | HTTP | Proxy para stats dashboard |

---

## 🚧 Componentes en Desarrollo

> **Nota:** Los siguientes componentes están planificados o en implementación:

- [ ] **HAProxy Load Balancing:** Configuración de balanceo entre múltiples servidores web
- [X] **HAProxy Stats Dashboard:** Panel web de estadísticas en puerto 9999 ✅
- [ ] **Jitsi Meet:** Despliegue completo de videoconferencia
- [ ] **Zabbix Dashboards:** Paneles personalizados de monitorización
- [ ] **Alertas Automatizadas:** Notificaciones por email/Telegram
- [ ] **HTTPS/SSL:** Certificados SSL para servicios web
- [ ] **Failover Automático:** Alta disponibilidad con replicación
- [ ] **Backup Incremental:** Backups diferenciales para optimización

---

## 📝 Notas Técnicas

### Cambios Recientes
- **31/01/2026 14:31:** Añadido acceso a HAProxy Stats Dashboard (192.168.31.224:9999/stats)
- **31/01/2026 14:24:** Actualización de IPs reales de infraestructura Proxmox
- **31/01/2026:** Documentación detallada de topología de red
- **31/01/2026:** Ampliación de sección de seguridad y monitorización

### Referencias
- Proxmox VE: https://pve.proxmox.com/wiki/Main_Page
- MikroTik RouterOS: https://wiki.mikrotik.com/
- HAProxy Documentation: https://www.haproxy.org/
- AWS CloudFormation: https://docs.aws.amazon.com/cloudformation/
- Tailscale: https://tailscale.com/kb/

---

**Documento actualizado:** 31 de enero de 2026, 14:31 CET  
**Estado:** Work in Progress 🚧  
**Autor:** Grupo 4 - ASIR Cantabria