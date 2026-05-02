# Ubuntu 24.04 en MacBook Pro 2018 con eGPU NVIDIA

Guía completa para instalar y configurar Ubuntu 24.04 en un MacBook Pro con chip T2, incluyendo eGPU NVIDIA para gaming vía Thunderbolt 3.

## Hardware probado

| Componente | Modelo |
|---|---|
| Portátil | MacBook Pro 15,1 (2018, 15") |
| CPU | Intel Core i7-8750H |
| Chip seguridad | Apple T2 |
| GPU interna | AMD Radeon Pro 555X |
| eGPU | NVIDIA RTX 3070 (Thunderbolt 3) |
| WiFi | Broadcom BCM4364 |

## Qué funciona

| Componente | Estado | Driver |
|---|---|---|
| Teclado interno | ✅ | apple-bce (DKMS) |
| Trackpad multitouch | ✅ | hid-magicmouse-t2 (compilado) |
| Touch Bar | ✅ | hid-appletb-kbd/bl (compilado) |
| WiFi | ✅ | brcmfmac (firmware Sonoma) |
| eGPU NVIDIA | ✅ | nvidia-driver-595 + PRIME offload |
| Monitor externo | ✅ | AMD 555X vía USB-C (3440x1440) |
| Steam/Proton gaming | ✅ | DXVK → RTX 3070 |
| Audio | ✅ | apple-bce |

## Qué NO funciona

- Display directo desde la caja eGPU (limitación firmware Apple TB3)
- Kernels >6.11 con NVIDIA modeset (pantalla negra)
- Driver NVIDIA 535 o nvidia-open (incompatibles)

## Arquitectura

```
┌─────────────────────────────────────────────────────────┐
│ Monitor externo (3440x1440)                             │
│     ↕ DisplayPort                                       │
│ Puerto USB-C del Mac → AMD Radeon Pro 555X (display)    │
│                              ↑                          │
│                    PRIME render offload                  │
│                              ↑                          │
│ Thunderbolt 3 → RTX 3070 eGPU (renderizado 3D)         │
└─────────────────────────────────────────────────────────┘
```

El monitor va conectado al Mac, NO a la caja eGPU. La RTX 3070 renderiza y envía los frames a la AMD vía PRIME offload.

## Quick Start

Si ya tienes Ubuntu instalado y quieres ir directo a la configuración, sigue [INSTALL.md](INSTALL.md).

Si tienes problemas, consulta [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Gaming con eGPU

En Steam → Propiedades del juego → **Opciones de lanzamiento**:

```
DXVK_FILTER_DEVICE_NAME="RTX 3070" __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only %command%
```

Con FPS overlay (MangoHud):
```
MANGOHUD=1 DXVK_FILTER_DEVICE_NAME="RTX 3070" __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only mangohud %command%
```

> **Importante:** `DXVK_FILTER_DEVICE_NAME` es obligatorio porque Vulkan enumera la AMD como GPU0. Sin esto, Proton usa la AMD integrada.

> **Nota:** Las Launch Options se configuran dentro de Steam. Los scripts bash no funcionan porque Steam/Proton no hereda variables de entorno del proceso padre.

## Configuración del sistema

```bash
# Kernel
uname -r  →  6.11.0-19-generic

# GRUB (/etc/default/grub)
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash pci=realloc,hpmmioprefsize=2G ibt=off"
GRUB_CMDLINE_LINUX="pm_async=off intel_iommu=on iommu=pt"

# NVIDIA (/etc/modprobe.d/)
options nvidia_drm modeset=1
options nvidia NVreg_DynamicPowerManagement=0x00
options nvidia NVreg_PreserveVideoMemoryAllocations=0

# Xorg nvidia configs → DESACTIVADOS (.disabled)

# Módulos al arranque (/etc/modules-load.d/)
apple-bce
hid-appletb-bl, hid-appletb-kbd
hid-apple-t2, hid-magicmouse-t2
```

## Licencia

Este proyecto es documentación libre. Úsala, modifícala, compártela.
