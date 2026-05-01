# Sesión 3 - Driver NVIDIA Open vs Closed (2 Mayo 2026, 00:20-00:47)

## Problema encontrado

Tras arrancar correctamente en kernel 6.11 con los BARs asignados (BAR0=16M, BAR1=256M, BAR3=32M), el driver NVIDIA cargaba pero `nvidia-smi` fallaba con:

```
nvidia-modeset: ERROR: GPU:0: Error while waiting for GPU progress: 0x0000c67d:0 2:0:72:56
```

El error se repetía cada 5 segundos indefinidamente.

## Diagnóstico

1. El driver instalado era `nvidia-dkms-595-open` (NVIDIA Open Kernel Module)
2. Los BARs estaban correctamente asignados — el problema NO era de recursos PCI
3. El error `0x0000c67d` indica timeout en la comunicación GPU ↔ driver vía nvidia-modeset
4. El driver open tiene problemas conocidos con eGPUs Thunderbolt

## Intentos fallidos

### Desactivar power management
```bash
# /etc/modprobe.d/nvidia-egpu.conf
options nvidia NVreg_DynamicPowerManagement=0x00
options nvidia NVreg_PreserveVideoMemoryAllocations=0
```
Resultado: sin efecto.

### Quitar nvidia-drm.modeset=1 de GRUB
Resultado: sin efecto.

### Blacklistear nvidia-modeset y nvidia-drm
```bash
# /etc/modprobe.d/nvidia-nomodeset.conf
blacklist nvidia_modeset
blacklist nvidia_drm
```
Resultado: sin efecto — los módulos se cargaban igualmente vía dependencias.

## Solución aplicada: cambiar a driver propietario cerrado

```bash
sudo apt install nvidia-driver-595
```

Esto reemplaza `nvidia-dkms-595-open` por `nvidia-dkms-595` (cerrado/propietario) y instala todas las librerías userspace necesarias.

El driver cerrado se compiló automáticamente para kernel 6.11 vía DKMS.

### Limpieza posterior
Se eliminó el blacklist innecesario:
```bash
sudo rm /etc/modprobe.d/nvidia-nomodeset.conf
sudo update-initramfs -u -k 6.11.0-19-generic
```

## Kernel 7.0.3-t2 eliminado
Ya no es necesario. Se intentó purgar pero ya no estaba instalado (probablemente eliminado por dependencias al cambiar driver).

## Estado actual

### Parámetros GRUB finales:
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash pci=realloc,hpmmioprefsize=2G ibt=off"
GRUB_CMDLINE_LINUX="pm_async=off intel_iommu=on iommu=pt"
```

### Archivos de configuración:
- `/etc/modprobe.d/nvidia-egpu.conf` — power management desactivado
- `/etc/modules-load.d/t2.conf` — apple-bce
- `/etc/modules-load.d/appletb.conf` — hid-appletb-bl, hid-appletb-kbd

### Pendiente:
- Reiniciar y verificar si nvidia-smi funciona con el driver cerrado
