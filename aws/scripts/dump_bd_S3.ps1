#!/usr/bin/env pwsh
<<<<<<< HEAD

$DB_USER     = "root"
$DB_PASSWORD = ""
$DB_HOST     = ""
$S3_BUCKET   = "grupo4-steven-454134285476-us-east-1"
$S3_PATH     = "backups/wordpress/"
$BACKUP_DIR  = "/home/backup"
$TIMESTAMP   = (Get-Date -Format "yyyyMMdd_HHmmss")
$BACKUP_FILE = "$BACKUP_DIR/backup_2bd_${TIMESTAMP}.sql.gz"
$LOG_FILE    = "/var/log/backup-bd.log"
=======
#@@@@ssdsdsd
# Variables
$DB_USER = "root" # Usuario BD
$DB_PASSWORD = "" # Contraseña BD
$DB_NAME = "wordpress" # Nombre de la BD
$DB_HOST = "" # Host BD
$S3_BUCKET = "grupo4-steven-454134285476-us-east-1" # Nombre del bucket S3 (sin s3://)
$S3_PATH = "backups/wordpress/" # Ruta en S3
$BACKUP_DIR = "/home/backup" # Ruta local para backup
$TIMESTAMP = (Get-Date -Format "yyyyMMdd_HHmmss") # Timestamp para nombre de archivo
$BACKUP_FILE = "$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.sql.gz" # Archivo comprimido
$LOG_FILE = "/var/log/backup-bd.log" # Archivo de log
>>>>>>> 0ca1b68de6ae31f471048f5a9aca69990d54eb23

New-Item -ItemType Directory -Path $BACKUP_DIR -Force -ErrorAction SilentlyContinue

function Write-Log {
    param([string]$Accion, [string]$Resultado = "")
    $fechaHora = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $mensaje   = "[$fechaHora] - $Accion $Resultado"
    Add-Content -Path $LOG_FILE -Value $mensaje -Encoding UTF8
    Write-Host $mensaje
}

Write-Log "Iniciando" "sistema_login + wordpress_empresa"

try {
    if ($DB_PASSWORD) {
        mysqldump --databases sistema_login wordpress_empresa -u $DB_USER -p$DB_PASSWORD -h $DB_HOST | gzip > $BACKUP_FILE
    } else {
        mysqldump --databases sistema_login wordpress_empresa -u $DB_USER -h $DB_HOST | gzip > $BACKUP_FILE
    }

    if ($LASTEXITCODE -eq 0 -and (Test-Path $BACKUP_FILE)) {
        Write-Log "Dump OK" "Backup creado en: $BACKUP_FILE"

        try {
            aws s3 cp $BACKUP_FILE "s3://$S3_BUCKET/$S3_PATH"
            if ($LASTEXITCODE -eq 0) {
                Write-Log "S3 OK" "Backup subido a S3 correctamente"
            } else {
                Write-Log "ERROR S3" "Fallo al subir el backup a S3"
            }
        }
        catch {
            Write-Log "ERROR S3" "Excepci  n al subir a S3: $_"
        }
    } else {
        Write-Log "ERROR" "Fallo en el dump o no se cre   el archivo"
    }
}
catch {
    Write-Log "ERROR" "Excepci  n en mysqldump: $_"
}