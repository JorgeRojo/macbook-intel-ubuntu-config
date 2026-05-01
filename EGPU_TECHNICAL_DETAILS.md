# Detalles Técnicos de la Cirugía del Driver eGPU

Este archivo contiene los parches y comandos técnicos realizados para intentar la compatibilidad con kernels modernos.

## 1. Parches de Código Fuente (NVIDIA)
Se realizaron modificaciones en `/usr/src/nvidia-[version]/` para solucionar incompatibilidades con el Kernel 7.0:

*   **Sustitución de funciones:** `strlcpy` fue eliminada en el Kernel 7.0. Se reemplazó por `strscpy`.
    ```bash
    sudo sed -i 's/strlcpy/strscpy/g' /usr/src/nvidia-[version]/nvidia/*.c
    ```
*   **Bloqueo de Memoria (VMA):** Se definió manualmente la constante `VMA_LOCK_OFFSET` en `nv-mmap.c`.
    ```c
    #ifndef VMA_LOCK_OFFSET
    #define VMA_LOCK_OFFSET (1UL << (64 - 1))
    #endif
    ```

## 2. Bypass de Seguridad (Objtool)
Para evitar el error `MITIGATION_RETHUNK` (naked return), se modificaron los archivos `Kbuild`:
*   Archivo: `nvidia/nvidia.Kbuild` y `nvidia-modeset/nvidia-modeset.Kbuild`
*   Línea añadida: `OBJECT_FILES_NON_STANDARD := y`

## 3. Configuración de GRUB
Parámetros esenciales en `/etc/default/grub`:
`GRUB_CMDLINE_LINUX_DEFAULT="quiet splash pci=realloc nvidia-drm.modeset=1 ibt=off"`

*   `pci=realloc`: Crucial para que el Mac asigne direcciones de memoria a la eGPU.
*   `ibt=off`: Evita bloqueos en el arranque con CPUs Intel modernas.

## 4. Instalación Manual de Soporte T2
En kernels que no son de la serie `-t2`, se debe forzar el soporte del teclado:
```bash
sudo apt install apple-bce
sudo dkms build apple-bce/0.2 -k 6.11.0-19-generic
sudo dkms install apple-bce/0.2 -k 6.11.0-19-generic
```
