# MacBook Intel Ubuntu Config

Installation guides for Ubuntu on MacBooks with Intel chipset and T2 chip.

## Hardware

- MacBook Pro 15,1 (2018, 15") — Intel i7-8750H
- Apple T2 Security Chip
- eGPU: NVIDIA RTX 3070 via Thunderbolt 3
- Internal dGPU: AMD Radeon Pro 555X

## Estado actual ✅

- ✅ Ubuntu 24.04 con kernel 6.11.0-19-generic
- ✅ nvidia-smi — RTX 3070 funcionando (compute/CUDA 13.2)
- ✅ Teclado/trackpad internos (apple-bce via DKMS)
- ✅ Touch Bar (hid-appletb-kbd/bl compilados manualmente)
- ✅ Arranque estable sin pantalla negra
- ❌ Display desde eGPU — nvidia-modeset incompatible con TB3 (pendiente)
- ❌ WiFi — requiere firmware extraído de macOS

## Documentación

| Documento | Descripción |
|---|---|
| [EGPU_INSTALL_GUIDE.md](EGPU_INSTALL_GUIDE.md) | Guía paso a paso para reproducir la instalación |
| [EGPU_SETUP_SUMMARY.md](EGPU_SETUP_SUMMARY.md) | Resumen de la configuración final |
| [EGPU_TECHNICAL_DETAILS.md](EGPU_TECHNICAL_DETAILS.md) | Parches de código y detalles técnicos |
| [EGPU_TROUBLESHOOTING_HISTORY.md](EGPU_TROUBLESHOOTING_HISTORY.md) | Historial de intentos y errores |
| [EGPU_SESSION_2_FIX.md](EGPU_SESSION_2_FIX.md) | Compilación NVIDIA + appletb para kernel 6.11 |
| [EGPU_SESSION_3_DRIVER_CHANGE.md](EGPU_SESSION_3_DRIVER_CHANGE.md) | Cambio de nvidia-open a propietario |
| [EGPU_SESSION_4_MODESET_FIX.md](EGPU_SESSION_4_MODESET_FIX.md) | Fix timeout nvidia-modeset |
| [EGPU_SESSION_5_DISPLAY_ATTEMPT.md](EGPU_SESSION_5_DISPLAY_ATTEMPT.md) | Intento de display desde eGPU |
| [EGPU_SESSION_6_MODESET_ZERO.md](EGPU_SESSION_6_MODESET_ZERO.md) | Fix arranque con modeset=0 |
| [EGPU_SESSION_7_GRUB_XORG_FIX.md](EGPU_SESSION_7_GRUB_XORG_FIX.md) | Fix GRUB_DEFAULT y Xorg nvidia |

## Configuración clave

```bash
# GRUB
GRUB_DEFAULT=0
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash pci=realloc,hpmmioprefsize=2G ibt=off"

# /etc/modprobe.d/nvidia-graphics-drivers-kms.conf
options nvidia_drm modeset=0

# /etc/modprobe.d/nvidia-egpu.conf
options nvidia NVreg_DynamicPowerManagement=0x00
options nvidia NVreg_PreserveVideoMemoryAllocations=0

# Xorg nvidia configs DISABLED (display usa Intel/AMD internos)
/usr/share/X11/xorg.conf.d/10-nvidia.conf.disabled
/usr/share/X11/xorg.conf.d/11-nvidia-offload.conf.disabled
```

## Pendiente

- Activar display externo desde eGPU (requiere resolver timeout de nvidia-modeset sobre TB3)
- WiFi (extraer firmware BCM4364 de macOS)
