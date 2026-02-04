#!/bin/bash

FECHA=$(date +%F_%H-%M)
BACKUP_DIR=~/backups
BACKUP_FILE=prueba_$FECHA.sql

DB_USER=root
DB_PASS=1234
DB_NAME=prueba_g4

BASTION2_USER=zapy
BASTION2_IP=192.168.56.11
DESTINO=/home/zapy/db_backups

mkdir -p $BACKUP_DIR

# Crear dump REAL
mysqldump -u $DB_USER -p$DB_PASS $DB_NAME > $BACKUP_DIR/$BACKUP_FILE

# Comprobar que NO esté vacío
if [ ! -s "$BACKUP_DIR/$BACKUP_FILE" ]; then
  echo "ERROR: dump vacío" >&2
  exit 1
fi

# Enviar a bastion2
scp $BACKUP_DIR/$BACKUP_FILE $BASTION2_USER@$BASTION2_IP:$DESTINO