# Historial de Intentos y Errores (Log de Investigación)

Cronología de las pruebas realizadas durante la sesión de configuración del 1 de Mayo de 2026.

### Intento 1: Kernel 7.0.3-t2 + NVIDIA 595-Open
*   **Resultado:** ERROR.
*   **Causa:** El Kernel 7.0 introdujo cambios masivos en la API (eliminación de `strlcpy`) y una seguridad extrema en `objtool` que impide cargar los binarios cerrados de NVIDIA. Los parches manuales no fueron suficientes para saltar el muro de seguridad.

### Intento 2: Kernel 6.11 Genérico (Primer intento)
*   **Resultado:** ERROR de Hardware.
*   **Causa:** NVIDIA funcionaba, pero el teclado, el ratón y el Wi-Fi desaparecieron porque este kernel no tiene los parches del chip Apple T2.

### Intento 3: Kernel 6.18-t2
*   **Resultado:** ERROR de Arranque.
*   **Causa:** Bloqueo total (Black Screen/Hang) al iniciar. Incompatibilidad específica de esta versión con el puente PCIe o el driver de pantalla de este MacBook concreto.

### Intento 4: Kernel 6.11 Genérico + apple-bce Manual
*   **Resultado:** ÉXITO TÉCNICO.
*   **Causa:** Al inyectar el driver `apple-bce` (soporte de Apple) dentro de un kernel genérico estable (6.11), logramos que el hardware de Apple funcione mientras mantenemos la compatibilidad nativa con NVIDIA sin necesidad de parches de código complejos.
