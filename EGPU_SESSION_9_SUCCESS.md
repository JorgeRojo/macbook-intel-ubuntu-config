# Sesión 9 - ¡ÉXITO! PRIME Render Offload funcionando (2 Mayo 2026, 02:49-03:04)

## Resultado final ✅

La RTX 3070 renderiza vía PRIME offload y muestra la imagen en el monitor externo conectado al Mac.

```
OpenGL vendor string: NVIDIA Corporation
OpenGL renderer string: NVIDIA GeForce RTX 3070/PCIe/SSE2
```

## Qué fue diferente

El problema del timeout de `nvidia-modeset` era **intermitente**. En algunos arranques funciona y en otros no. La clave fue:

1. Mantener `modeset=1` en `/etc/modprobe.d/nvidia-graphics-drivers-kms.conf`
2. NO poner `nvidia-drm.modeset=1` en GRUB (el modprobe.d es suficiente)
3. El monitor externo va conectado a un puerto del Mac (usa AMD Radeon), no a la caja eGPU
4. La RTX 3070 renderiza vía PRIME offload

## Configuración final que funciona

### /etc/modprobe.d/nvidia-graphics-drivers-kms.conf
```
options nvidia_drm modeset=1
```

### /etc/modprobe.d/nvidia-egpu.conf
```
options nvidia NVreg_DynamicPowerManagement=0x00
options nvidia NVreg_PreserveVideoMemoryAllocations=0
```

### /etc/default/grub
```
GRUB_DEFAULT=0
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash pci=realloc,hpmmioprefsize=2G ibt=off"
GRUB_CMDLINE_LINUX="pm_async=off intel_iommu=on iommu=pt"
```

### Xorg
- `/usr/share/X11/xorg.conf.d/10-nvidia.conf.disabled` (desactivado)

## Cómo jugar con la eGPU

### Comando genérico:
```bash
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia programa
```

### En Steam (Launch Options del juego):
```
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only %command%
```

### Verificar que funciona:
```bash
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia glxinfo | grep "OpenGL renderer"
# Debe decir: NVIDIA GeForce RTX 3070
```

## Nota sobre estabilidad

El arranque con `modeset=1` puede fallar ocasionalmente (timeout de nvidia-modeset sobre Thunderbolt). Si el sistema se cuelga al arrancar:
1. Reiniciar en recovery
2. `sudo sed -i 's|modeset=1|modeset=0|' /etc/modprobe.d/nvidia-graphics-drivers-kms.conf`
3. `sudo update-initramfs -u -k 6.11.0-19-generic && sudo reboot`
4. Volver a poner `modeset=1` y reiniciar de nuevo (suele funcionar al segundo intento)

## Topología de display

```
Monitor externo (3440x1440) ← DisplayPort → Puerto USB-C del Mac → AMD Radeon Pro 555X
                                                                          ↑
                                                              PRIME render offload
                                                                          ↑
                                                              NVIDIA RTX 3070 (eGPU vía TB3)
```
