<script>
window.addEventListener('load', function() {
    const paragraphs = document.querySelectorAll('.elementor-widget-text-editor p');

    paragraphs.forEach((p) => {
        // Guardamos el HTML original (con las negritas <strong>)
        const content = p.innerHTML;
        p.innerHTML = ''; 
        p.style.minHeight = '150px'; // Reserva espacio para evitar saltos
        p.style.visibility = 'visible';

        let cursor = 0;
        let currentHTML = "";

        function type() {
            if (cursor < content.length) {
                // Si detectamos una etiqueta HTML (como <strong>), la escribimos de golpe
                if (content.charAt(cursor) === '<') {
                    let tag = content.substring(cursor, content.indexOf('>', cursor) + 1);
                    currentHTML += tag;
                    cursor += tag.length;
                } else {
                    // Si es una letra normal, la añadimos poco a poco
                    currentHTML += content.charAt(cursor);
                    cursor++;
                }
                
                p.innerHTML = currentHTML;
                // VELOCIDAD: 30ms para un efecto más legible y "lujoso"
                setTimeout(type, 30); 
            }
        }

        // Retraso inicial para que de tiempo a ver la animación al cargar
        setTimeout(type, 800);
    });
});
</script>