#!/bin/bash

# Variables
DB_USER="root"
DB_PASSWORD=""
DB_NAME="wordpress"
DB_HOST=""
S3_BUCKET="grupo4-steven-454134285476-us-east-1"
S3_PATH="backups/wordpress/"
BACKUP_DIR="/home/backup"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.sql.gz"

mkdir -p "$BACKUP_DIR"

echo "$(date) - Iniciando dump..." >> /var/log/backup-bd.log

# Hacer dump local
mysqldump -u "$DB_USER" "$DB_NAME" | gzip > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "$(date) - Dump completado: $BACKUP_FILE" >> /var/log/backup-bd.log
    
    # Subir a S3 (requiere AWS CLI v2 instalado)
    aws s3 cp "$BACKUP_FILE" "s3://$S3_BUCKET/$S3_PATH"
    
fi