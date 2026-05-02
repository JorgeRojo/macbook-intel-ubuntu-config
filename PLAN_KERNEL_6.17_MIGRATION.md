# Plan de Migración a Kernel 6.17.0-23-generic

## Objetivo
Migrar de kernel 6.11.0-19-generic a 6.17.0-23-generic manteniendo toda la funcionalidad actual:
- eGPU NVIDIA RTX 3070 (compute + PRIME render offload)
- Teclado/trackpad internos (apple-bce)
- Touch Bar (hid-appletb-kbd/bl)
- Monitor externo vía AMD Radeon

## Ventajas del kernel 6.17
- NVIDIA 595 precompilado (sin DKMS, sin riesgo de fallos de compilación)
- hid-appletb-kbd probablemente incluido nativamente (se añadió al mainline post-6.11)
- Mejor soporte Thunderbolt y PCIe hotplug
- Parches de seguridad y rendimiento más recientes

## Requisitos previos
- Internet activo (para descargar paquetes)
- Kernel 6.11 se mantiene como respaldo

---

## Paso 1: Instalar kernel y módulos NVIDIA precompilados

```bash
sudo apt install \
  linux-image-6.17.0-23-generic \
  linux-headers-6.17.0-23-generic \
  linux-modules-nvidia-595-6.17.0-23-generic \
  -y
```

Esto instala:
- Kernel 6.17.0-23
- Headers (necesarios para DKMS de apple-bce)
- Módulos NVIDIA 595 precompilados (nvidia.ko, nvidia-modeset.ko, nvidia-drm.ko, nvidia-uvm.ko)

## Paso 2: Compilar apple-bce para el nuevo kernel

```bash
sudo dkms build apple-bce/0.2 -k 6.17.0-23-generic
sudo dkms install apple-bce/0.2 -k 6.17.0-23-generic
```

## Paso 3: Verificar hid-appletb-kbd

```bash
find /lib/modules/6.17.0-23-generic -name "hid-appletb*"
```

**Si los archivos existen** (esperado):
- No hay que hacer nada, están incluidos en el kernel
- Eliminar `/etc/modules-load.d/appletb.conf` (ya no es necesario)

**Si NO existen** (improbable):
- Compilar desde ~/appletb-build con `make KVER=6.17.0-23-generic`
- Puede requerir nuevos parches si la API cambió
- Copiar .ko a `/lib/modules/6.17.0-23-generic/updates/dkms/`
- `sudo depmod -a 6.17.0-23-generic`

## Paso 4: Verificar configuración existente

Estos archivos aplican a todos los kernels, no necesitan cambios:

### /etc/default/grub
```
GRUB_DEFAULT=0
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash pci=realloc,hpmmioprefsize=2G ibt=off"
GRUB_CMDLINE_LINUX="pm_async=off intel_iommu=on iommu=pt"
```
GRUB_DEFAULT=0 seleccionará automáticamente el kernel más reciente (6.17).

### /etc/modprobe.d/nvidia-graphics-drivers-kms.conf
```
options nvidia_drm modeset=1
```

### /etc/modprobe.d/nvidia-egpu.conf
```
options nvidia NVreg_DynamicPowerManagement=0x00
options nvidia NVreg_PreserveVideoMemoryAllocations=0
```

### /etc/modules-load.d/t2.conf
```
apple-bce
```

### /usr/share/X11/xorg.conf.d/10-nvidia.conf.disabled
Debe seguir desactivado.

## Paso 5: Actualizar GRUB

```bash
sudo update-grub
```

Verificar que el kernel 6.17 aparece como primera entrada.

## Paso 6: Reiniciar

```bash
sudo reboot
```

## Paso 7: Verificación post-arranque

```bash
# Kernel correcto
uname -r
# Esperado: 6.17.0-23-generic

# NVIDIA funciona
nvidia-smi
# Esperado: RTX 3070 visible

# Apple hardware
lsmod | grep apple_bce
# Esperado: cargado

# Touch Bar
lsmod | grep hid_appletb
# Esperado: cargado

# PRIME render offload
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia glxinfo | grep "OpenGL renderer"
# Esperado: NVIDIA GeForce RTX 3070

# Monitor externo
xrandr | grep " connected"
# Esperado: eDP + DisplayPort-X connected
```

## Paso 8: Limpieza (opcional, después de verificar estabilidad)

Si todo funciona tras varios reinicios:
```bash
sudo apt purge linux-image-6.11.0-19-generic linux-headers-6.11.0-19-generic -y
sudo update-grub
```

---

## Rollback si falla

En GRUB al arrancar: Advanced options → Ubuntu, with Linux 6.11.0-19-generic

O desde recovery del 6.17:
```bash
sudo sed -i 's|GRUB_DEFAULT=.*|GRUB_DEFAULT="1>2"|' /etc/default/grub
sudo update-grub
sudo reboot
```

---

## Posibles problemas

| Problema | Solución |
|---|---|
| apple-bce no compila | Verificar headers: `ls /lib/modules/6.17.0-23-generic/build/Makefile` |
| hid-appletb no existe | Compilar desde ~/appletb-build (puede necesitar ajustes) |
| nvidia-smi falla | Verificar que linux-modules-nvidia-595-6.17.0-23-generic se instaló |
| Pantalla negra al arrancar | Mismo problema de modeset — revertir a 6.11 |
| BAR1 = 0M | Verificar que `pci=realloc,hpmmioprefsize=2G` está en cmdline |

---

## Notas

- Los módulos NVIDIA precompilados (`linux-modules-nvidia-595-*`) no usan DKMS — se instalan directamente en `/lib/modules/`. Esto es más fiable que DKMS.
- Si se actualiza el kernel (ej: 6.17.0-24), habrá que instalar el nuevo paquete `linux-modules-nvidia-595-6.17.0-24-generic` también.
- El kernel 6.11 se mantiene como respaldo hasta confirmar estabilidad.
