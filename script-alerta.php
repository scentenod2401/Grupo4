<?php
add_action('wp_head', function() {
    // Solo enviamos la alerta si el usuario está viendo el panel
    if ( is_user_logged_in() ) {
        
        $webhook_url = "https://discord.com/api/webhooks/1470331443367379108/svLFWBwaRfC3XaioOy2a40qpEKvoNAPHhEPviyCJWnAr7bmrplZOM7LyDP1hFR2vRtTT";

        $json_data = json_encode([
            "username" => "Zero Day Systems Bot",
            "avatar_url" => "https://i.imgur.com/8nNmT6W.png", // Icono profesional
            "embeds" => [
                [
                    "title" => "⚠️ ALERTA CRÍTICA DE INFRAESTRUCTURA",
                    "description" => "Se ha perdido la conexión con los servicios del servidor del cliente.",
                    "color" => 15158332, // Color Rojo
                    "fields" => [
                        ["name" => "Apache", "value" => "❌ INACTIVO", "inline" => true],
                        ["name" => "PHP-FPM", "value" => "❌ DESCONOCIDO", "inline" => true],
                        ["name" => "MySQL", "value" => "❌ DESCONOCIDO", "inline" => true],
                        ["name" => "SSH", "value" => "❌ DESCONOCIDO", "inline" => true]
                    ],
                    "footer" => ["text" => "Estado: Máquina Virtual Offline | ZDS Monitor"]
                ]
            ]
        ], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);

        $ch = curl_init($webhook_url);
        curl_setopt($ch, CURLOPT_HTTPHEADER, array('Content-type: application/json'));
        curl_setopt($ch, CURLOPT_POST, 1);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $json_data);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
        curl_exec($ch);
        curl_close($ch);
    }
});

?>