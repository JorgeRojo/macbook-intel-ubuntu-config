# Resumen de Configuración eGPU - MacBook Pro T2

Este documento resume la configuración final necesaria para hacer funcionar una eGPU NVIDIA (RTX 3070) en un MacBook Pro con chip T2 bajo Ubuntu 24.04.

## Estado Final de la Solución
Para resolver el conflicto entre el hardware propietario de Apple (Chip T2) y los controladores de NVIDIA, se optó por la siguiente configuración:

*   **Núcleo (Kernel):** Linux 6.11.0-19-generic.
    *   *Razón:* Es una versión estable donde los drivers de NVIDIA compilan sin errores de seguridad avanzados (como los del Kernel 7.0).
*   **Soporte T2:** Driver `apple-bce` instalado manualmente vía DKMS.
    *   *Resultado:* El teclado y trackpad del portátil funcionan correctamente en este kernel genérico.
*   **Driver Gráfico:** NVIDIA 535/595 Propietario.
    *   *Estado:* Compilado y firmado para el Kernel 6.11.
*   **Gestión de Arranque:** GRUB configurado para usar el Kernel 6.11 por defecto.

## Cómo verificar el funcionamiento
Tras reiniciar en el Kernel 6.11, ejecuta:
```bash
nvidia-smi
```
Deberías ver la tabla de procesos de la NVIDIA GeForce RTX 3070.

## Notas sobre el Wi-Fi
El hardware de red es detectado, pero requiere la extracción manual del firmware de Apple desde una partición de macOS para activarse completamente.
