#!/bin/bash

BASE=109
CLONE1=200
CLONE2=201
CPU_UP=2.0
CPU_DOWN=1.5

cpu=$(pct exec $BASE -- cat /proc/loadavg | awk '{print $1}')
echo "[$(date)] CPU: $cpu"

exists_200=0
exists_201=0

pct list | grep -q "^200 " && exists_200=1
pct list | grep -q "^201 " && exists_201=1

total=$((1 + exists_200 + exists_201))
echo "[$(date)] Total instancias: $total"

if (( $(echo "$cpu > $CPU_UP" | bc -l) )); then
    if [ $total -lt 3 ]; then
        # Crear snapshot nueva
        TIMESTAMP=$(date +%s)
        pct snapshot $BASE "base-$TIMESTAMP"
        
        if [ $exists_200 -eq 0 ]; then
            echo "[$(date)] CREANDO clon 200..."
            pct clone $BASE $CLONE1 -snapname "base-$TIMESTAMP"
            pct set $CLONE1 -hostname web-autoescalado-200
            pct set $CLONE1 -net0 name=eth0,bridge=vmbr1,ip=192.168.14.200/24,gw=192.168.14.1
            pct start $CLONE1
            echo "[$(date)] ✓ Clon 200 creado"
        elif [ $exists_201 -eq 0 ]; then
            echo "[$(date)] CREANDO clon 201..."
            pct clone $BASE $CLONE2 -snapname "base-$TIMESTAMP"
            pct set $CLONE2 -hostname web-autoescalado-201
            pct set $CLONE1 -net0 name=eth0,bridge=vmbr1,ip=192.168.14.201/24,gw=192.168.14.1
            pct start $CLONE2
            echo "[$(date)] ✓ Clon 201 creado"
        fi
    fi
fi

if (( $(echo "$cpu < $CPU_DOWN" | bc -l) )); then
    if [ $total -gt 1 ]; then
        if [ $exists_201 -eq 1 ]; then
            echo "[$(date)] ELIMINANDO clon 201..."
            pct stop $CLONE2 2>/dev/null
            pct destroy $CLONE2 --purge 1
            echo "[$(date)] ✓ Clon 201 eliminado"
            
            # Borrar TODAS las snapshots - PARSING CORRECTO
            pct listsnapshot $BASE 2>/dev/null | grep "base-" | awk '{print $2}' | while read snap; do
                if [ -n "$snap" ]; then
                    echo "[$(date)] Borrando snapshot: $snap"
                    pct delsnapshot $BASE "$snap" 2>/dev/null
                    if [ $? -eq 0 ]; then
                        echo "[$(date)] ✓ Snapshot $snap eliminado"
                    else
                        echo "[$(date)] ✗ Error al eliminar snapshot $snap"
                    fi
                fi
            done
            echo "[$(date)] Limpieza de snapshots completada"
            
        elif [ $exists_200 -eq 1 ]; then
            echo "[$(date)] ELIMINANDO clon 200..."
            pct stop $CLONE1 2>/dev/null
            pct destroy $CLONE1 --purge 1
            echo "[$(date)] ✓ Clon 200 eliminado"
            
            # Borrar TODAS las snapshots - PARSING CORRECTO
            pct listsnapshot $BASE 2>/dev/null | grep "base-" | awk '{print $2}' | while read snap; do
                if [ -n "$snap" ]; then
                    echo "[$(date)] Borrando snapshot: $snap"
                    pct delsnapshot $BASE "$snap" 2>/dev/null
                    if [ $? -eq 0 ]; then
                        echo "[$(date)] ✓ Snapshot $snap eliminado"
                    else
                        echo "[$(date)] ✗ Error al eliminar snapshot $snap"
                    fi
                fi
            done
            echo "[$(date)] Limpieza de snapshots completada"
        fi
    fi
fi