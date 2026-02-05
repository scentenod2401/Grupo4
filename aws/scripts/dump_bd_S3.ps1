#!/usr/bin/env pwsh

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

# Crear directorio de backup si no existe
if (-not (Test-Path $BACKUP_DIR)) {
    New-Item -ItemType Directory -Path $BACKUP_DIR -Force | Out-Null
}

# Función para logs con formato indicado: [FECHA y HORA] - [ACCIÓN] [RESULTADO]
function Write-Log {
    param([string]$Accion, [string]$Resultado = "")
    $fechaHora = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $mensaje = "[$fechaHora] - $Accion $Resultado"
    $mensaje | Out-File -FilePath $LOG_FILE -Append -Encoding UTF8
    Write-Host $mensaje
}

Write-Log "Iniciando" "dump de la base de datos"

# Hacer dump y comprimir
try {
    $dumpArgs = @("-u", $DB_USER, "-h", $DB_HOST, $DB_NAME)
    if ($DB_PASSWORD) {
        $dumpArgs += @("-p$DB_PASSWORD")
    }
    mysqldump @dumpArgs | gzip > $BACKUP_FILE

    if ($LASTEXITCODE -eq 0) {
        Write-Log "Dump completado" "exitosamente en: $BACKUP_FILE"

        # Subir a S3
        try {
            aws s3 cp $BACKUP_FILE "s3://$S3_BUCKET/$S3_PATH"

            if ($LASTEXITCODE -eq 0) {
                Write-Log "Backup subido" "a S3 exitosamente"
            } else {
                Write-Log "ERROR" "Fallo al subir archivo a S3"
            }
        }
        catch {
            Write-Log "ERROR" "AWS CLI no encontrado o fallo en subida: $_"
        }
    } else {
        Write-Log "ERROR" "Fallo en el dump de la base de datos"
    }
}
catch {
    Write-Log "ERROR" "Excepción en mysqldump: $_"
}

Write-Log "Script finalizado" "proceso de backup completado"