# MacBook Intel Ubuntu Config

Installation guides for Ubuntu on MacBooks with Intel chipset and T2 chip.

## Hardware

- MacBook Pro 15,1 (2018, 15") — Intel i7-8750H
- Apple T2 Security Chip
- eGPU: NVIDIA RTX 3070 via Thunderbolt 3
- Internal dGPU: AMD Radeon Pro 555X
- Monitor: 3440x1440 ultrawide via DisplayPort (conectado al Mac)

## Estado actual ✅

- ✅ Ubuntu 24.04 con kernel 6.11.0-19-generic
- ✅ nvidia-smi — RTX 3070 funcionando (CUDA 13.2)
- ✅ PRIME render offload — juegos acelerados con RTX 3070
- ✅ Monitor externo 3440x1440 (vía AMD Radeon)
- ✅ Teclado/trackpad internos (apple-bce via DKMS)
- ✅ Touch Bar (hid-appletb-kbd/bl compilados manualmente)
- ✅ Steam + Proton instalados
- ❌ WiFi — requiere firmware extraído de macOS (usar `sudo get-apple-firmware get_from_online`)

## Cómo jugar con la eGPU

En Steam → Propiedades del juego → Launch Options:
```
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only DXVK_HUD=fps %command%
```

O usar los scripts:
- `~/LiesOfP.sh` — con eGPU RTX 3070
- `~/LiesOfP_noegpu.sh` — con AMD integrada (para comparar)

## Configuración clave

```bash
# Kernel
6.11.0-19-generic

# GRUB
GRUB_DEFAULT=0
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash pci=realloc,hpmmioprefsize=2G ibt=off"
GRUB_CMDLINE_LINUX="pm_async=off intel_iommu=on iommu=pt"

# /etc/modprobe.d/nvidia-graphics-drivers-kms.conf
options nvidia_drm modeset=1

# /etc/modprobe.d/nvidia-egpu.conf
options nvidia NVreg_DynamicPowerManagement=0x00
options nvidia NVreg_PreserveVideoMemoryAllocations=0

# Xorg nvidia configs DISABLED
/usr/share/X11/xorg.conf.d/10-nvidia.conf.disabled

# Módulos cargados al arranque
/etc/modules-load.d/t2.conf → apple-bce
/etc/modules-load.d/appletb.conf → hid-appletb-bl, hid-appletb-kbd
```

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
| [EGPU_SESSION_8_XORG_EGPU.md](EGPU_SESSION_8_XORG_EGPU.md) | Intento Xorg eGPU con delay |
| [EGPU_SESSION_9_SUCCESS.md](EGPU_SESSION_9_SUCCESS.md) | ¡ÉXITO! PRIME render offload funcionando |
| [EGPU_SESSION_10_KERNEL_6.17.md](EGPU_SESSION_10_KERNEL_6.17.md) | Intento kernel 6.17 (falló - pantalla negra) |
| [PLAN_KERNEL_6.17_MIGRATION.md](PLAN_KERNEL_6.17_MIGRATION.md) | Plan de migración (no viable por modeset) |

## Notas importantes

- **modeset=1 es intermitente**: a veces el arranque falla con pantalla negra. Un segundo reinicio suele funcionar.
- **Kernel 6.17 no funciona**: nvidia-modeset timeout con módulos precompilados. Quedarse en 6.11.
- **Driver 535 no funciona**: incompatible con kernel >6.4 en GPUs Ampere.
- **Si se actualiza nvidia-driver**: verificar que `modeset=1` no se sobreescriba y que `10-nvidia.conf` siga desactivado.
