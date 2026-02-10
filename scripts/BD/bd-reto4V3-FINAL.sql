-- ==========================================================
-- SCRIPT FINAL OPTIMIZADO: SISTEMA DE SEGURIDAD Y ALERTAS
-- COMPATIBLE CON: MariaDB / MySQL (Workbench)
-- ==========================================================

-- 1. CREACIÓN DE TABLAS (CON COLACIÓN UNIFICADA)
-- ----------------------------------------------------------

CREATE TABLE IF NOT EXISTS usuarios (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    nombre VARCHAR(100),
    apellidos VARCHAR(150),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_ultima_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    ultimo_acceso TIMESTAMP NULL,
    intentos_fallidos TINYINT UNSIGNED DEFAULT 0,
    bloqueado_hasta TIMESTAMP NULL,
    activo BOOLEAN DEFAULT TRUE,
    INDEX idx_email (email),
    INDEX idx_bloqueo_optimizado (bloqueado_hasta, activo) -- Optimización de rendimiento
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci; [cite: 1]

CREATE TABLE IF NOT EXISTS sesiones (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    usuario_id INT UNSIGNED NOT NULL,
    token_sesion VARCHAR(255) NOT NULL UNIQUE,
    ip_address VARCHAR(45),
    user_agent VARCHAR(255),
    fecha_inicio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_expiracion TIMESTAMP NOT NULL,
    activa BOOLEAN DEFAULT TRUE,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
    INDEX idx_token_rapido (token_sesion, activa) -- Optimización para validación de sesiones
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci; [cite: 2]

CREATE TABLE IF NOT EXISTS log_autenticacion (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    usuario_id INT UNSIGNED NULL,
    email_intento VARCHAR(255),
    resultado ENUM('exito', 'fallo_password', 'fallo_usuario', 'bloqueado', 'intento_en_bloqueo') NOT NULL,
    ip_address VARCHAR(45),
    user_agent VARCHAR(255),
    fecha_intento TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_fecha (fecha_intento),
    INDEX idx_usuario_resultado (usuario_id, resultado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci; [cite: 3]

-- NUEVA TABLA: Alertas de Seguridad Proactivas
CREATE TABLE IF NOT EXISTS alertas_seguridad (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    usuario_id INT UNSIGNED NOT NULL,
    tipo_alerta VARCHAR(50) DEFAULT 'BLOQUEO_CUENTA',
    mensaje TEXT,
    fecha_alerta TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    leida BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
    INDEX idx_alertas_no_leidas (leida)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- 2. PROCEDIMIENTO ALMACENADO (CON CORRECCIÓN DE COLACIÓN)
-- ----------------------------------------------------------

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_login$$

CREATE PROCEDURE sp_login(
    IN p_email VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    IN p_ip VARCHAR(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    IN p_user_agent VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
    OUT p_resultado VARCHAR(50),
    OUT p_usuario_id INT
)
BEGIN
    DECLARE v_id INT;
    DECLARE v_bloqueo TIMESTAMP;
    DECLARE v_activo BOOLEAN;
    DECLARE v_intentos INT;

    -- Buscar usuario
    SELECT id, bloqueado_hasta, activo INTO v_id, v_bloqueo, v_activo 
    FROM usuarios WHERE email = p_email LIMIT 1; [cite: 5]
    
    SET p_usuario_id = v_id; [cite: 6]

    -- Lógica de validación
    IF v_id IS NULL THEN
        SET p_resultado = 'USUARIO_NO_EXISTE'; [cite: 6]
        INSERT INTO log_autenticacion (email_intento, resultado, ip_address, user_agent)
        VALUES (p_email, 'fallo_usuario', p_ip, p_user_agent); [cite: 7]

    ELSEIF v_activo = FALSE THEN
        SET p_resultado = 'USUARIO_INACTIVO'; [cite: 8]

    ELSEIF v_bloqueo IS NOT NULL AND v_bloqueo > NOW() THEN
        SET p_resultado = 'CUENTA_BLOQUEADA'; [cite: 9]
        INSERT INTO log_autenticacion (usuario_id, email_intento, resultado, ip_address, user_agent)
        VALUES (v_id, p_email, 'intento_en_bloqueo', p_ip, p_user_agent); [cite: 10]

    ELSE
        -- Registro de intento fallido
        INSERT INTO log_autenticacion (usuario_id, email_intento, resultado, ip_address, user_agent)
        VALUES (v_id, p_email, 'fallo_password', p_ip, p_user_agent); [cite: 11]

        -- Conteo de fallos en los últimos 15 min
        SELECT COUNT(*) INTO v_intentos 
        FROM log_autenticacion 
        WHERE usuario_id = v_id 
          AND resultado = 'fallo_password' 
          AND fecha_intento >= DATE_SUB(NOW(), INTERVAL 15 MINUTE); [cite: 12]

        -- Aplicar bloqueo y GENERAR ALERTA si llega a 5 fallos
        IF v_intentos >= 5 THEN
            UPDATE usuarios 
            SET bloqueado_hasta = DATE_ADD(NOW(), INTERVAL 30 MINUTE),
                intentos_fallidos = v_intentos
            WHERE id = v_id; [cite: 13]

            -- Inserción de Alerta Proactiva (Mejora añadida)
            INSERT INTO alertas_seguridad (usuario_id, mensaje)
            VALUES (v_id, CONCAT('Alerta: Cuenta bloqueada por 5 fallos. IP detectada: ', p_ip));

            SET p_resultado = 'BLOQUEO_RECIEN_ACTIVADO'; [cite: 14]
        ELSE
            UPDATE usuarios SET intentos_fallidos = v_intentos WHERE id = v_id; [cite: 14]
            SET p_resultado = CONCAT('FALLO_NUMERO_', v_intentos); [cite: 15]
        END IF;
    END IF;
END$$

DELIMITER ;


-- 3. EVENTO DE MANTENIMIENTO
-- ----------------------------------------------------------

SET GLOBAL event_scheduler = ON;

CREATE EVENT IF NOT EXISTS limpiar_logs_viejos
ON SCHEDULE EVERY 1 DAY
DO
  DELETE FROM log_autenticacion WHERE fecha_intento < DATE_SUB(NOW(), INTERVAL 30 DAY); [cite: 16]