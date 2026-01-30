#!/usr/bin/env pwsh

# Variables
$DB_USER = "root" # Usuario BD
$DB_PASSWORD = "" # Contraseña BD
$DB_NAME = "wordpress" # Nombre de la BD
$DB_HOST = "" # Host BD
$S3_BUCKET = "grupo4-steven-454134285476-us-east-1" # Enlace del S3
$S3_PATH = "backups/wordpress/" # Ruta donde se guardara la copia comprimida de la DB en el S3
$BACKUP_DIR = "/home/backup" # Ruta donde se guardará localmente el archivo comprimido
$TIMESTAMP = (Get-Date -Format "yyyyMMdd_HHmmss") # Fecha y hora actual
$BACKUP_FILE = "$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.sql.gz" # Ruta del archivo final comprimido 
$LOG_FILE = "/var/log/backup-bd.log" # Archivo log

# Creación del directorio de backup, en caso de ya existir no lo creará
if (-not (Test-Path $BACKUP_DIR)) {
    mkdir -p $BACKUP_DIR
}

# Función para logs
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $log_message = "$timestamp - $Message"
    
    
    $log_message | Out-File -FilePath $LOG_FILE -Append
    
    
    Write-Host $log_message
}

Write-Log "Iniciando dump..."

# Hacer dump desde local y comprimir
try {
    if ($DB_PASSWORD) {
        mysqldump -u $DB_USER -p"$DB_PASSWORD" -h $DB_HOST $DB_NAME | gzip > $BACKUP_FILE
    } else {
        mysqldump -u $DB_USER -h $DB_HOST $DB_NAME | gzip > $BACKUP_FILE
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Log "Dump completado: $BACKUP_FILE"
        
        # Subir a S3 mediante AWSCli
        try {
            aws s3 cp $BACKUP_FILE "s3://$S3_BUCKET/$S3_PATH"
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Backup subido a S3 exitosamente"
            } else {
                Write-Log "ERROR: Fallo al subir a S3"
            }
        }
        catch {
            Write-Log "ERROR: AWS CLI no encontrado o error en la subida: $_"
        }
    } else {
        Write-Log "ERROR: Fallo en el dump de la base de datos"
    }
}
catch {
    Write-Log "ERROR: Fallo en mysqldump: $_"
}