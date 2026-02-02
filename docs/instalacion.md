# 📗 Guía de Instalación - Grupo 4

## Requisitos Previos

### Proxmox
- ✅ Proxmox VE 8.x instalado y configurado
- ✅ Plantilla Debian 12 LXC descargada
- ✅ Bridges de red configurados (vmbr0, vmbr1)
- ✅ Acceso root al servidor Proxmox
- ✅ Espacio en disco suficiente (500GB+ recomendado)

### AWS
- ✅ Cuenta AWS Academy activa
- ✅ AWS CLI instalado y configurado
- ✅ EC2 Key Pair creado
- ✅ Permisos para CloudFormation, EC2, VPC, S3

---

## Instalación Proxmox

### Paso 1: Clonar Repositorio

```bash
git clone https://github.com/scentenod2401/Grupo4.git
cd Grupo4
git checkout Steven  # O José-Manuel / Marco
```

### Paso 2: Verificar Plantilla LXC

```bash
# Listar plantillas disponibles
ls /var/lib/vz/template/cache/

# Si no existe Debian 12, descargarla
pveam update
pveam download local debian-12-standard_12.12-1_amd64.tar.zst
```

### Paso 3: Verificar Bridges

```bash
# Listar bridges
ip link show | grep vmbr

# Verificar configuración
cat /etc/network/interfaces
```

Debes tener:
- **vmbr0:** Bridge WAN (conectado a tu red con DHCP/internet)
- **vmbr1:** Bridge LAN (sin IP o con IP manual)

### Paso 4: Configurar Script

Editar `despliegue_proxmox.sh` si es necesario:

```bash
nano despliegue_proxmox.sh

# Verificar/ajustar variables:
# - BRIDGE_WAN="vmbr0"
# - BRIDGE_LAN="vmbr1"
# - ROOT_PASS="12345678"  # ¡CAMBIAR!
# - TEMPLATE_LXC (ruta correcta)
```

### Paso 5: Ejecutar Despliegue

```bash
# Dar permisos de ejecución
chmod +x despliegue_proxmox.sh

# Ejecutar como root
./despliegue_proxmox.sh

# Seguir instrucciones en pantalla
```

El script creará:
- LXC 100 (Tailscale) en vmbr0
- VM 101 (MikroTik) - **requiere creación manual**
- LXC 102-109 en vmbr1 con IPs estáticas

---

## Instalación AWS

### Paso 1: Configurar AWS CLI

```bash
aws configure
# Introducir:
# - AWS Access Key ID
# - AWS Secret Access Key  
# - Region: us-east-1
# - Output: json
```

### Paso 2: Verificar Key Pair

```bash
# Listar key pairs
aws ec2 describe-key-pairs --region us-east-1

# Si no tienes uno, crear:
aws ec2 create-key-pair --key-name grupo4-key --query 'KeyMaterial' --output text > grupo4-key.pem
chmod 400 grupo4-key.pem
```

### Paso 3: Desplegar Stack CloudFormation

**Opción A: Consola Web**

1. Ir a [AWS CloudFormation Console](https://console.aws.amazon.com/cloudformation/)
2. Click en "Create Stack"
3. Upload template: `grupo4_steven_final.yaml`
4. Stack name: `grupo4-steven`
5. Parámetros:
   - KeyPairName: `grupo4-key` (o tu key pair)
6. Next → Next → Create Stack
7. Esperar ~5-10 minutos

**Opción B: AWS CLI**

```bash
aws cloudformation create-stack \
  --stack-name grupo4-steven \
  --template-body file://grupo4_steven_final.yaml \
  --parameters ParameterKey=KeyPairName,ParameterValue=grupo4-key \
  --region us-east-1
```

---

## Verificación Final

### Proxmox
```bash
# Listar contenedores
pct list

# Estado de todos
for i in {100..109}; do pct status $i; done
```

### AWS
```bash
# Ver instancias
aws ec2 describe-instances --region us-east-1

# Ver bucket S3
aws s3 ls
```

---

**Documento actualizado:** 31 de enero de 2026