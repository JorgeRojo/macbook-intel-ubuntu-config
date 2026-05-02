# Sesión 7 - Fix arranque: GRUB_DEFAULT y Xorg (2 Mayo 2026, 01:55-02:06)

## Problemas encontrados

### 1. GRUB_DEFAULT apuntaba a entrada inexistente
Al borrar el kernel 6.18-t2, la posición `1>4` dejó de existir. GRUB caía a recovery.
**Fix:** `GRUB_DEFAULT=0` (primera entrada = Ubuntu normal con 6.11).

### 2. Xorg forzaba nvidia como driver de display
`/usr/share/X11/xorg.conf.d/10-nvidia.conf` hacía que GDM intentara usar nvidia para display. Con `modeset=0`, nvidia-drm no registra dispositivo DRM → pantalla negra.
**Fix:** Renombrar archivos:
```bash
sudo mv /usr/share/X11/xorg.conf.d/10-nvidia.conf /usr/share/X11/xorg.conf.d/10-nvidia.conf.disabled
sudo mv /usr/share/X11/xorg.conf.d/11-nvidia-offload.conf /usr/share/X11/xorg.conf.d/11-nvidia-offload.conf.disabled
```

### 3. Conflicto en opciones modprobe
`nvidia-graphics-drivers-kms.conf` y `nvidia-egpu.conf` tenían valores contradictorios para `NVreg_PreserveVideoMemoryAllocations`. Se unificó a `=0`.

### 4. Driver 535 incompatible con kernel 6.11
El driver 535 da `RmInitAdapter failed! (0x22:0x40:774)` en kernels >6.4 con GPUs Ampere. Se volvió al 595.

## Configuración final

### /etc/default/grub
```
GRUB_DEFAULT=0
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash pci=realloc,hpmmioprefsize=2G ibt=off"
GRUB_CMDLINE_LINUX="pm_async=off intel_iommu=on iommu=pt"
```

### /etc/modprobe.d/nvidia-graphics-drivers-kms.conf
```
options nvidia_drm modeset=0
```

### /etc/modprobe.d/nvidia-egpu.conf
```
options nvidia NVreg_DynamicPowerManagement=0x00
options nvidia NVreg_PreserveVideoMemoryAllocations=0
```

### Xorg
- `/usr/share/X11/xorg.conf.d/10-nvidia.conf.disabled`
- `/usr/share/X11/xorg.conf.d/11-nvidia-offload.conf.disabled`

## Nota importante
Si se actualiza el paquete `nvidia-driver-*`, puede:
1. Restaurar `10-nvidia.conf` → pantalla negra
2. Restaurar `modeset=1` en kms.conf → cuelgue al arranque
3. Cambiar GRUB_DEFAULT → arranque incorrecto

Hay que vigilar estos archivos tras cada `apt upgrade`.
