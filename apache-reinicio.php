<?php
define('ZABBIX_URL', 'http://192.168.14.13/api_jsonrpc.php');
define('ZABBIX_TOKEN', 'c95d6243e2fc1647d32b807267568fd63220360c8166ebf7bc8502d99dea4872');
define('ZABBIX_HOST', 'Zabbix-server');
define('APACHE_SCRIPT_ID', '4');

function restart_apache_handler() {
    if ( ! current_user_can('edit_pages') ) {
    	wp_send_json_error(array('message' => 'No tienes permisos'));
    	wp_die();
	}
    $host_request = array(
        'jsonrpc' => '2.0',
        'method' => 'host.get',
        'params' => array(
            'output' => array('hostid'),
            'filter' => array('host' => array(ZABBIX_HOST))
        ),
        'id' => 1
    );
    $response = wp_remote_post(ZABBIX_URL, array(
        'headers' => array(
            'Content-Type' => 'application/json-rpc',
            'Authorization' => 'Bearer ' . ZABBIX_TOKEN
        ),
        'body' => json_encode($host_request),
        'timeout' => 15,
        'sslverify' => false
    ));
    if (is_wp_error($response)) {
        wp_send_json_error(array('message' => 'Error conectando a Zabbix'));
        wp_die();
    }
	
	if (is_wp_error($response2)) {
    error_log('Error de Zabbix: ' . $response2->get_error_message()); // ESTO ESCRIBE EL ERROR REAL
    wp_send_json_error(array('message' => 'Error ejecutando script'));
    wp_die();
}
    $body = wp_remote_retrieve_body($response);
    $data = json_decode($body, true);
    if (isset($data['error']) || empty($data['result'])) {
        wp_send_json_error(array('message' => 'Error obteniendo host'));
        wp_die();
    }
    $hostid = $data['result'][0]['hostid'];
    $script_request = array(
        'jsonrpc' => '2.0',
        'method' => 'script.execute',
        'params' => array(
            'scriptid' => APACHE_SCRIPT_ID,
            'hostid' => $hostid
        ),
        'id' => 2
    );
    $response2 = wp_remote_post(ZABBIX_URL, array(
        'headers' => array(
            'Content-Type' => 'application/json-rpc',
            'Authorization' => 'Bearer ' . ZABBIX_TOKEN
        ),
        'body' => json_encode($script_request),
        'timeout' => 30,
        'sslverify' => false
    ));
    if (is_wp_error($response2)) {
        wp_send_json_error(array('message' => 'Error ejecutando script'));
        wp_die();
    }
    $body2 = wp_remote_retrieve_body($response2);
    $data2 = json_decode($body2, true);
    if (isset($data2['error'])) {
        wp_send_json_error(array('message' => $data2['error']['message']));
        wp_die();
    }
    wp_send_json_success(array('message' => 'Apache reiniciado correctamente'));
    wp_die();
}
add_action('wp_ajax_restart_apache', 'restart_apache_handler');

function get_apache_status() {
    // Intentar obtener desde caché (válido por 10 segundos)
    $cached = get_transient('apache_status_cache');
    if ($cached !== false) {
        return $cached;
    }
    
    // Si no hay caché, hacer la petición a Zabbix
    $trigger_request = array(
        'jsonrpc' => '2.0',
        'method' => 'trigger.get',
        'params' => array(
            'output' => array('triggerid', 'value', 'description'),
            'selectHosts' => array('name'),
            'search' => array('description' => 'Apache: Process is not running')
        ),
        'id' => 1
    );
    
    $response = wp_remote_post(ZABBIX_URL, array(
        'headers' => array(
            'Content-Type' => 'application/json-rpc',
            'Authorization' => 'Bearer ' . ZABBIX_TOKEN
        ),
        'body' => json_encode($trigger_request),
        'timeout' => 5,  // Reducido a 5 segundos
        'sslverify' => false
    ));
    
    if (is_wp_error($response)) {
        $result = array('status' => 'error', 'message' => 'Error de conexión');
    } else {
        $body = wp_remote_retrieve_body($response);
        $data = json_decode($body, true);
        
        if (isset($data['error'])) {
            $result = array('status' => 'error', 'message' => $data['error']['message']);
        } else {
            $triggers = $data['result'] ?? array();
            
            if (empty($triggers)) {
                $result = array('status' => 'unknown', 'message' => 'No hay triggers');
            } else {
                $found_problem = false;
                foreach ($triggers as $trigger) {
                    if ($trigger['value'] == '1') {
                        $result = array('status' => 'down', 'message' => $trigger['description']);
                        $found_problem = true;
                        break;
                    }
                }
                if (!$found_problem) {
                    $result = array('status' => 'up', 'message' => 'Funcionando correctamente');
                }
            }
        }
    }
    
    // Guardar en caché por 10 segundos
    set_transient('apache_status_cache', $result, 10);
    
    return $result;
}


// Estilos CSS profesionales
function apache_control_styles() {
    echo '<style>
        .apache-status-container {
            max-width: 700px;
            margin: 20px auto;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
        }
        
        .apache-card {
            background: #ffffff;
            border-radius: 12px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
            padding: 32px;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            border: 1px solid rgba(0, 0, 0, 0.06);
        }
        
        .apache-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 20px rgba(0, 0, 0, 0.12);
        }
        
        .apache-header {
            display: flex;
            align-items: center;
            gap: 16px;
            margin-bottom: 20px;
        }
        
        .apache-icon {
            width: 56px;
            height: 56px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 28px;
            flex-shrink: 0;
            transition: transform 0.2s ease;
        }
        
        .apache-icon.success {
            background: linear-gradient(135deg, #d4edda 0%, #c3e6cb 100%);
            color: #28a745;
        }
        
        .apache-icon.danger {
            background: linear-gradient(135deg, #f8d7da 0%, #f5c6cb 100%);
            color: #dc3545;
        }
        
        .apache-icon.info {
            background: linear-gradient(135deg, #d1ecf1 0%, #bee5eb 100%);
            color: #17a2b8;
        }
        
        .apache-content h2 {
            font-size: 22px;
            font-weight: 600;
            margin: 0 0 4px 0;
            letter-spacing: -0.01em;
        }
        
        .apache-content.success h2 { color: #155724; }
        .apache-content.danger h2 { color: #721c24; }
        .apache-content.info h2 { color: #0c5460; }
        
        .apache-content p {
            font-size: 14px;
            color: #6c757d;
            margin: 0;
            font-weight: 500;
        }
        
        .apache-details {
            background: linear-gradient(135deg, rgba(0, 0, 0, 0.015) 0%, rgba(0, 0, 0, 0.025) 100%);
            border-radius: 8px;
            padding: 16px;
            margin-bottom: 20px;
            border-left: 3px solid;
            font-size: 14px;
            color: #495057;
            line-height: 1.6;
        }
        
        .apache-details.success { 
            border-left-color: #28a745;
            background: linear-gradient(135deg, rgba(40, 167, 69, 0.03) 0%, rgba(40, 167, 69, 0.05) 100%);
        }
        .apache-details.danger { 
            border-left-color: #dc3545;
            background: linear-gradient(135deg, rgba(220, 53, 69, 0.03) 0%, rgba(220, 53, 69, 0.05) 100%);
        }
        .apache-details.info { 
            border-left-color: #17a2b8;
            background: linear-gradient(135deg, rgba(23, 162, 184, 0.03) 0%, rgba(23, 162, 184, 0.05) 100%);
        }
        
        .restart-apache-btn {
            background: linear-gradient(135deg, #dc3545 0%, #c82333 100%);
            color: white;
            border: none;
            padding: 14px 28px;
            border-radius: 8px;
            font-size: 15px;
            font-weight: 600;
            cursor: pointer;
            width: 100%;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
            transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
            box-shadow: 0 2px 8px rgba(220, 53, 69, 0.3);
            position: relative;
            overflow: hidden;
        }
        
        .restart-apache-btn::before {
            content: "";
            position: absolute;
            top: 0;
            left: -100%;
            width: 100%;
            height: 100%;
            background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
            transition: left 0.5s;
        }
        
        .restart-apache-btn:hover:not(:disabled)::before {
            left: 100%;
        }
        
        .restart-apache-btn:hover:not(:disabled) {
            transform: translateY(-1px);
            box-shadow: 0 4px 12px rgba(220, 53, 69, 0.4);
        }
        
        .restart-apache-btn:active:not(:disabled) {
            transform: translateY(0);
        }
        
        .restart-apache-btn:disabled {
            opacity: 0.6;
            cursor: not-allowed;
        }
        
        .restart-message {
            margin-top: 16px;
            padding: 12px 16px;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 500;
            display: none;
            animation: slideDown 0.3s ease;
        }
        
        @keyframes slideDown {
            from {
                opacity: 0;
                transform: translateY(-10px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }
        
        .restart-message.show {
            display: block;
        }
        
        .restart-message.success {
            background: linear-gradient(135deg, #d4edda 0%, #c3e6cb 100%);
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        
        .restart-message.error {
            background: linear-gradient(135deg, #f8d7da 0%, #f5c6cb 100%);
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        
        .restart-message.loading {
            background: linear-gradient(135deg, #fff3cd 0%, #ffeeba 100%);
            color: #856404;
            border: 1px solid #ffeeba;
        }
        
        .apache-footer {
            margin-top: 20px;
            padding-top: 20px;
            border-top: 1px solid rgba(0, 0, 0, 0.06);
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-size: 13px;
            color: #6c757d;
        }
        
        .apache-update {
            display: flex;
            align-items: center;
            gap: 6px;
        }
        
        .apache-refresh {
            display: flex;
            align-items: center;
            gap: 6px;
            opacity: 0.85;
        }
        
        .pulse-dot {
            width: 8px;
            height: 8px;
            background: #17a2b8;
            border-radius: 50%;
            animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
        }
        
        @keyframes pulse {
            0%, 100% { 
                opacity: 1;
                transform: scale(1);
            }
            50% { 
                opacity: 0.3;
                transform: scale(0.95);
            }
        }
        
        .spinner {
            display: inline-block;
            width: 16px;
            height: 16px;
            border: 2px solid rgba(255, 255, 255, 0.3);
            border-top-color: white;
            border-radius: 50%;
            animation: spin 0.8s linear infinite;
        }
        
        @keyframes spin {
            to { transform: rotate(360deg); }
        }
        
        @media (prefers-color-scheme: dark) {
            .apache-card {
                background: #1f2121;
                border-color: rgba(255, 255, 255, 0.1);
            }
            
            .apache-icon.success {
                background: linear-gradient(135deg, rgba(40, 167, 69, 0.15) 0%, rgba(40, 167, 69, 0.2) 100%);
                color: #32b643;
            }
            
            .apache-icon.danger {
                background: linear-gradient(135deg, rgba(220, 53, 69, 0.15) 0%, rgba(220, 53, 69, 0.2) 100%);
                color: #ff5459;
            }
            
            .apache-icon.info {
                background: linear-gradient(135deg, rgba(23, 162, 184, 0.15) 0%, rgba(23, 162, 184, 0.2) 100%);
                color: #3ec1d3;
            }
            
            .apache-content.success h2 { color: #88d498; }
            .apache-content.danger h2 { color: #ff9da0; }
            .apache-content.info h2 { color: #8edbe6; }
            
            .apache-content p,
            .apache-details,
            .apache-footer {
                color: #a7a9a9;
            }
            
            .apache-details.success {
                background: linear-gradient(135deg, rgba(40, 167, 69, 0.08) 0%, rgba(40, 167, 69, 0.12) 100%);
            }
            
            .apache-details.danger {
                background: linear-gradient(135deg, rgba(220, 53, 69, 0.08) 0%, rgba(220, 53, 69, 0.12) 100%);
            }
            
            .apache-details.info {
                background: linear-gradient(135deg, rgba(23, 162, 184, 0.08) 0%, rgba(23, 162, 184, 0.12) 100%);
            }
            
            .restart-message.success {
                background: linear-gradient(135deg, rgba(40, 167, 69, 0.15) 0%, rgba(40, 167, 69, 0.2) 100%);
                color: #88d498;
                border-color: rgba(40, 167, 69, 0.3);
            }
            
            .restart-message.error {
                background: linear-gradient(135deg, rgba(220, 53, 69, 0.15) 0%, rgba(220, 53, 69, 0.2) 100%);
                color: #ff9da0;
                border-color: rgba(220, 53, 69, 0.3);
            }
            
            .restart-message.loading {
                background: linear-gradient(135deg, rgba(255, 193, 7, 0.1) 0%, rgba(255, 193, 7, 0.15) 100%);
                color: #ffc107;
                border-color: rgba(255, 193, 7, 0.3);
            }
        }
        
        @media (max-width: 640px) {
            .apache-card {
                padding: 24px;
                margin: 12px;
            }
            
            .apache-header {
                gap: 12px;
            }
            
            .apache-icon {
                width: 48px;
                height: 48px;
                font-size: 24px;
            }
            
            .apache-content h2 {
                font-size: 18px;
            }
            
            .apache-footer {
                flex-direction: column;
                gap: 12px;
                align-items: flex-start;
            }
        }
    </style>';
}
add_action('wp_head', 'apache_control_styles');

function check_apache_status() {
    $status = get_apache_status();
    $now = date('d/m/Y H:i:s');
    $ajax_url = admin_url('admin-ajax.php');
    
    $html = '<div id="apache-status" class="apache-status-container">';
    
    if ($status['status'] == 'down') {
        $html .= '
        <div class="apache-card">
            <div class="apache-header">
                <div class="apache-icon danger">✕</div>
                <div class="apache-content danger">
                    <h2>Apache - Inactivo</h2>
                    <p>Servicio detenido</p>
                </div>
            </div>
            <div class="apache-details danger">
                El servicio Apache no está respondiendo. Se requiere acción inmediata para restaurar el servicio.
            </div>
            <button class="restart-apache-btn">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <polyline points="23 4 23 10 17 10"></polyline>
                    <path d="M20.49 15a9 9 0 1 1-2.12-9.36L23 10"></path>
                </svg>
                <span>Reiniciar Apache Ahora</span>
            </button>
            <div class="restart-message"></div>
            <div class="apache-footer">
                <div class="apache-update">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <circle cx="12" cy="12" r="10"></circle>
                        <polyline points="12 6 12 12 16 14"></polyline>
                    </svg>
                    <span>Actualizado: ' . $now . '</span>
                </div>
                <div class="apache-refresh">
                    <div class="pulse-dot"></div>
                    <span>Auto-actualización activa</span>
                </div>
            </div>
        </div>';
    } elseif ($status['status'] == 'up') {
        $html .= '
        <div class="apache-card">
            <div class="apache-header">
                <div class="apache-icon success">✓</div>
                <div class="apache-content success">
                    <h2>Apache - Activo</h2>
                    <p>Servicio operativo</p>
                </div>
            </div>
            <div class="apache-details success">
                El servicio Apache está funcionando correctamente. No se requiere ninguna acción.
            </div>
            <div class="apache-footer">
                <div class="apache-update">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <circle cx="12" cy="12" r="10"></circle>
                        <polyline points="12 6 12 12 16 14"></polyline>
                    </svg>
                    <span>Actualizado: ' . $now . '</span>
                </div>
                <div class="apache-refresh">
                    <div class="pulse-dot"></div>
                    <span>Auto-actualización activa</span>
                </div>
            </div>
        </div>';
    } else {
        $html .= '
        <div class="apache-card">
            <div class="apache-header">
                <div class="apache-icon info">ℹ</div>
                <div class="apache-content info">
                    <h2>Apache - Estado Desconocido</h2>
                    <p>Información no disponible</p>
                </div>
            </div>
            <div class="apache-details info">
                No se encontraron triggers configurados en Zabbix para este servicio. Verifica la configuración de monitorización.
            </div>
            <div class="apache-footer">
                <div class="apache-update">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <circle cx="12" cy="12" r="10"></circle>
                        <polyline points="12 6 12 12 16 14"></polyline>
                    </svg>
                    <span>Actualizado: ' . $now . '</span>
                </div>
                <div class="apache-refresh">
                    <div class="pulse-dot"></div>
                    <span>Auto-actualización activa</span>
                </div>
            </div>
        </div>';
    }
    
    $html .= '</div>';
    
    $html .= "
    <script>
    (function() {
        function updateStatus() {
            var container = document.getElementById('apache-status');
            if (!container) return;
            
            fetch(window.location.href)
                .then(response => response.text())
                .then(html => {
                    var parser = new DOMParser();
                    var doc = parser.parseFromString(html, 'text/html');
                    var newContent = doc.getElementById('apache-status');
                    
                    if (newContent) {
                        container.innerHTML = newContent.innerHTML;
                        attachHandlers();
                    }
                });
        }
        
        function attachHandlers() {
            var btn = document.querySelector('#apache-status .restart-apache-btn');
            if (!btn) return;
            
            btn.onclick = function() {
                var messageDiv = document.querySelector('#apache-status .restart-message');
                var btnRef = this;
                
                btnRef.disabled = true;
                btnRef.innerHTML = '<div class=\"spinner\"></div> <span>Ejecutando...</span>';
                
                messageDiv.className = 'restart-message show loading';
                messageDiv.textContent = '⏳ Enviando comando a Zabbix...';
                
                fetch('{$ajax_url}', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
                    body: 'action=restart_apache'
                })
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        messageDiv.className = 'restart-message show success';
                        messageDiv.textContent = '✓ ' + data.data.message;
                        setTimeout(updateStatus, 8000);
                    } else {
                        messageDiv.className = 'restart-message show error';
                        messageDiv.textContent = '✕ ' + data.data.message;
                        btnRef.disabled = false;
                        btnRef.innerHTML = '<svg width=\"18\" height=\"18\" viewBox=\"0 0 24 24\" fill=\"none\" stroke=\"currentColor\" stroke-width=\"2\"><polyline points=\"23 4 23 10 17 10\"></polyline><path d=\"M20.49 15a9 9 0 1 1-2.12-9.36L23 10\"></path></svg><span>Reiniciar Apache Ahora</span>';
                    }
                });
            };
        }
        
        attachHandlers();
        setInterval(updateStatus, 10000);
    })();
    </script>";
    
    return $html;
}

add_shortcode('apache_check', 'check_apache_status');
?>