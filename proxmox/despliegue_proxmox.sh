#!/bin/sh
set -e

# ===== CONFIGURACIÓN GENERAL =====
BRIDGE_WAN="vmbr0"              # DHCP
BRIDGE_LAN="vmbr1"              # Estático
TEMPLATE_LXC="/var/lib/vz/template/cache/debian-12-standard_12.12-1_amd64.tar.zst"

# ===== 1. TAILSCALE (100) - LXC en vmbr0 (DHCP) =====
TAILSCALE_ID=100
TAILSCALE_HOSTNAME="tailscale"
TAILSCALE_CORES=2
TAILSCALE_MEM=256
TAILSCALE_HD=4

# ===== 2. MIKROTIK (101) - VM en vmbr0 (DHCP) + vmbr1 (192.168.14.1 Gateway LAN) =====
MIKROTIK_ID=101
MIKROTIK_HOSTNAME="mikrotik"
MIKROTIK_IP_LAN="192.168.14.1"    # IP fija en vmbr1 (LAN Gateway)
MIKROTIK_CORES=2
MIKROTIK_MEM=512
MIKROTIK_HD=20

# ===== 3. LXC RESTO (102-109) - En vmbr1 (LAN Estático) =====
LXC_LAN_IDS="102 103 104 105 106 107 108 109"
LXC_LAN_HOSTNAMES="web bd haproxy zabbix jitsi plantilla1 plantilla2 plantilla3"
LXC_LAN_IPS="192.168.14.10 192.168.14.11 192.168.14.12 192.168.14.13 192.168.14.14 192.168.14.15 192.168.14.16 192.168.14.17"
LXC_LAN_CORES=2
LXC_LAN_MEM=4096
LXC_LAN_HD=40
LXC_LAN_GW="192.168.14.1"         # Gateway LAN (Mikrotik)

# ===== CONTRASEÑAS =====
ROOT_PASS="12345678"            # CAMBIAR

# ===== FIN CONFIGURACIÓN =====

# Validar que se ejecuta como root
if [ "$(id -u)" -ne 0 ]; then
   echo "❌ Este script debe ejecutarse como root"
   exit 1
fi

# Validar plantillas
if [ ! -f "$TEMPLATE_LXC" ]; then
   echo "❌ Plantilla LXC no encontrada: $TEMPLATE_LXC"
   exit 1
fi

# Validar bridges
for bridge in "$BRIDGE_WAN" "$BRIDGE_LAN"; do
    if ! ip link show "$bridge" >/dev/null 2>&1; then
        echo "❌ Bridge $bridge no existe"
        echo "Bridges disponibles:"
        ip link show | grep "^[0-9]*: vmbr"
        exit 1
    fi
done

# Mostrar plan
clear
echo "╔════════════════════════════════════════════════════════╗"
echo "║     DESPLIEGUE COMPLETO DE INFRAESTRUCTURA             ║"
echo "║    (vmbr0=DHCP, vmbr1=LAN Estático 192.168.14.0/24)  ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "📊 PLAN DE DESPLIEGUE:"
echo ""
echo "1️⃣  TAILSCALE (100) - LXC"
echo "   Bridge:  $BRIDGE_WAN (DHCP)"
echo "   Cores:   $TAILSCALE_CORES | Mem: ${TAILSCALE_MEM}MB | Disco: ${TAILSCALE_HD}GB"
echo ""
echo "2️⃣  MIKROTIK (101) - VM"
echo "   Interfaces:"
echo "   - eth0 (WAN):      $BRIDGE_WAN → DHCP"
echo "   - eth1 (LAN):      $BRIDGE_LAN → $MIKROTIK_IP_LAN (Gateway)"
echo "   Cores: $MIKROTIK_CORES | Mem: ${MIKROTIK_MEM}MB | Disco: ${MIKROTIK_HD}GB"
echo ""
echo "3️⃣  LXC RESTO (102-109) - LAN"
echo "   Bridge:  $BRIDGE_LAN"
echo "   Red:     192.168.14.0/24"
echo "   Gateway: $LXC_LAN_GW (Mikrotik)"
echo "   Cantidad: 8 contenedores"
echo ""
echo "📋 CONTENEDORES A CREAR:"
printf "%-8s %-15s %-20s %-10s\n" "ID" "HOSTNAME" "IP/DHCP" "TIPO"
echo "────────────────────────────────────────────────────────"
echo "100      tailscale      DHCP             LXC (WAN)"
echo "101      mikrotik       DHCP (eth0) +    VM (WAN+LAN)"
echo "                        192.168.14.1 (eth1)"

ct_counter=1
for ct_id in $LXC_LAN_IDS; do
    hostname=$(echo $LXC_LAN_HOSTNAMES | cut -d' ' -f$ct_counter)
    ip=$(echo $LXC_LAN_IPS | cut -d' ' -f$ct_counter)
    printf "%-8s %-15s %-20s %-10s\n" "$ct_id" "$hostname" "$ip" "LXC (LAN)"
    ct_counter=$((ct_counter + 1))
done
echo ""

read -p "¿Desplegar TODO (incluyendo Mikrotik VM)? (s/n): " -r reply
if [ "$reply" != "s" ] && [ "$reply" != "S" ]; then
    echo "⏹️  Abortado por el usuario"
    exit 0
fi

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║          INICIANDO DESPLIEGUE COMPLETO                ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

CREATED=0
FAILED=0

# ========== 1. CREAR TAILSCALE (100) LXC EN vmbr0 DHCP ==========
echo "[1/3] Desplegando Tailscale (100) en vmbr0 (DHCP)..."
if pct status $TAILSCALE_ID >/dev/null 2>&1; then
    echo "⚠️  LXC 100 ya existe"
else
    if pct create $TAILSCALE_ID "$TEMPLATE_LXC" \
        --cores $TAILSCALE_CORES \
        --hostname "$TAILSCALE_HOSTNAME" \
        --memory $TAILSCALE_MEM \
        --net0 name=eth0,bridge=$BRIDGE_WAN,firewall=1,type=veth \
        --storage local-lvm \
        --rootfs local-lvm:$TAILSCALE_HD \
        --unprivileged 1 \
        --features keyctl=1,nesting=1,fuse=1 \
        --ostype debian \
        --password=$ROOT_PASS \
        --start 0 \
        --onboot 1 \
        >/dev/null 2>&1; then
        echo "✅ Tailscale creado (100) - DHCP en vmbr0"
        CREATED=$((CREATED + 1))
        pct start $TAILSCALE_ID >/dev/null 2>&1
    else
        echo "❌ Error creando Tailscale"
        FAILED=$((FAILED + 1))
    fi
fi
echo ""

# ========== 2. CREAR MIKROTIK (101) VM ==========
echo "[2/3] MIKROTIK (101) - VM con interfaces:"
echo "      - eth0: $BRIDGE_WAN (DHCP WAN)"
echo "      - eth1: $BRIDGE_LAN (Gateway LAN $MIKROTIK_IP_LAN)"
echo ""
echo "⚠️  NOTA: Mikrotik requiere ISO personalizado"
echo "   Este script NO puede crear la VM automáticamente"
echo ""
echo "   Pasos para crear Mikrotik manualmente:"
echo "   1. Descargar ISO de Mikrotik RouterOS (CHR o regular)"
echo "   2. Subir a Proxmox almacenamiento"
echo "   3. Crear VM (ID 101) con:"
echo "      - CPU: $MIKROTIK_CORES cores"
echo "      - RAM: ${MIKROTIK_MEM}MB"
echo "      - Disco: ${MIKROTIK_HD}GB"
echo "      - net0: $BRIDGE_WAN (interfaz ether1 - será WAN)"
echo "      - net1: $BRIDGE_LAN (interfaz ether2 - será LAN Gateway)"
echo ""
echo "   4. Configurar en Mikrotik (SSH o terminal):"
echo "      - ether1: IP por DHCP (WAN)"
echo "      - ether2: 192.168.14.1/24 (LAN Gateway)"
echo "      - Routing: Default route hacia ether1 (WAN)"
echo "      - NAT: (opcional) Masquerade de LAN a WAN"
echo ""
read -p "¿Ya tienes Mikrotik 101 creado y configurado? (s/n): " -r reply_mikrotik
if [ "$reply_mikrotik" = "s" ] || [ "$reply_mikrotik" = "S" ]; then
    echo "✅ Asumiendo Mikrotik 101 existe y está configurado"
    CREATED=$((CREATED + 1))
else
    echo "⚠️  Continúa con LXC LAN y crea Mikrotik manualmente después"
fi
echo ""

# ========== 3. CREAR LXC LAN (102-109) EN vmbr1 ==========
echo "[3/3] Desplegando LXC LAN (102-109) en vmbr1 (Estático)..."
ct_counter=1
for ct_id in $LXC_LAN_IDS; do
    hostname=$(echo $LXC_LAN_HOSTNAMES | cut -d' ' -f$ct_counter)
    ip=$(echo $LXC_LAN_IPS | cut -d' ' -f$ct_counter)
    
    echo "[$(date '+%H:%M:%S')] (${ct_counter}/8) Creando: $hostname ($ct_id) → $ip"
    
    if pct status $ct_id >/dev/null 2>&1; then
        echo "  ⚠️  Ya existe"
        ct_counter=$((ct_counter + 1))
        continue
    fi
    
    if pct create $ct_id "$TEMPLATE_LXC" \
        --cores $LXC_LAN_CORES \
        --hostname "$hostname" \
        --memory $LXC_LAN_MEM \
        --net0 name=eth0,bridge=$BRIDGE_LAN,firewall=1,gw=$LXC_LAN_GW,ip=$ip/24,type=veth \
        --storage local-lvm \
        --rootfs local-lvm:$LXC_LAN_HD \
        --unprivileged 1 \
        --features keyctl=1,nesting=1,fuse=1 \
        --ostype debian \
        --password=$ROOT_PASS \
        --start 0 \
        --onboot 1 \
        >/dev/null 2>&1; then
        
        echo "  ✅ Creado"
        CREATED=$((CREATED + 1))
        pct start $ct_id >/dev/null 2>&1
    else
        echo "  ❌ Error"
        FAILED=$((FAILED + 1))
    fi
    
    ct_counter=$((ct_counter + 1))
done

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║              DESPLIEGUE COMPLETADO                    ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "📊 RESUMEN:"
echo "   ✅ Creados:  $CREATED/10 (Tailscale + Mikrotik + LXC LAN)"
echo "   ❌ Fallidos: $FAILED"
echo ""
echo "📋 CONTENEDORES ACTUALES:"
pct list 2>/dev/null || echo "   (sin LXC)"
echo ""
echo "🔧 PRÓXIMOS PASOS:"
echo ""
echo "1️⃣  CONFIGURAR TAILSCALE (100) - DHCP WAN:"
echo "   pct shell 100"
echo "   # Verificar IP asignada:"
echo "   ip addr show eth0"
echo "   # Instalar y configurar Tailscale:"
echo "   apt update && apt install -y tailscale"
echo "   tailscale up"
echo ""
echo "2️⃣  CREAR/CONFIGURAR MIKROTIK (101):"
echo "   a) Crear VM manualmente con ISO RouterOS"
echo "   b) Interfaces:"
echo "      - ether1: Conectada a $BRIDGE_WAN (DHCP WAN)"
echo "      - ether2: Conectada a $BRIDGE_LAN (192.168.14.1 Gateway)"
echo "   c) Configurar IP en Mikrotik:"
echo "      - ether1: /ip address add address=0.0.0.0/0 interface=ether1"
echo "               /ip dhcp-client add interface=ether1"
echo "      - ether2: /ip address add address=192.168.14.1/24 interface=ether2"
echo "   d) Configurar routing/NAT si necesitas acceso a internet desde LAN"
echo ""
echo "3️⃣  VERIFICAR LXC LAN (102-109) - DHCP WAN:"
echo "   pct exec 102 ip addr show eth0"
echo "   pct exec 102 ip route show"
echo "   pct exec 102 ping -c 4 192.168.14.1"
echo ""
echo "4️⃣  COMUNICACIÓN ENTRE CONTENEDORES LAN:"
echo "   pct exec 102 ping -c 4 192.168.14.11"
echo "   pct exec 102 ping -c 4 192.168.14.15"
echo ""
echo "5️⃣  PARA INTERNET EN LAN (si quieres salida a WAN):"
echo "   Configurar en Mikrotik (101):"
echo "   /ip firewall nat add chain=srcnat out-interface=ether1 action=masquerade"
echo "   /ip dns set servers=1.1.1.1,8.8.8.8 allow-remote-requests=yes"
echo ""
echo "📌 RESUMEN FINAL ARQUITECTURA:"
echo "┌─────────────────────────────────────────┐"
echo "│ vmbr0 (DHCP WAN)                        │"
echo "│  ├─ 100 (Tailscale LXC)                 │"
echo "│  └─ 101 (Mikrotik VM eth0)              │"
echo "│                                         │"
echo "│ vmbr1 (LAN Estático)                    │"
echo "│  ├─ 101 (Mikrotik VM eth1) 192.168.14.1 │"
echo "│  ├─ 102 (web1)         192.168.14.10    │"
echo "│  ├─ 103 (web2)         192.168.14.11    │"
echo "│  ├─ 104 (web3)         192.168.14.12    │"
echo "│  ├─ 105 (db1)          192.168.14.13    │"
echo "│  ├─ 106 (db2)          192.168.14.14    │"
echo "│  ├─ 107 (cache1)       192.168.14.15    │"
echo "│  ├─ 108 (api1)         192.168.14.16    │"
echo "│  └─ 109 (monitor)      192.168.14.17    │"
echo "└─────────────────────────────────────────┘"
echo ""