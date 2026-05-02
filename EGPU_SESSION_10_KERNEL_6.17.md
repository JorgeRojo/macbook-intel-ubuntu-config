# Sesión 10 - Migración a Kernel 6.17.0-23-generic (2 Mayo 2026, 03:30-03:37)

## Pasos ejecutados

### 1. Instalar kernel + NVIDIA precompilado
```bash
sudo apt install linux-image-6.17.0-23-generic linux-headers-6.17.0-23-generic linux-modules-nvidia-595-6.17.0-23-generic -y
```

### 2. apple-bce
Se compiló automáticamente vía DKMS durante la instalación del kernel. No requirió acción manual.

### 3. hid-appletb-kbd y hid-appletb-bl
NO están incluidos en el kernel 6.17 genérico de Ubuntu (no habilitados en su config).

Se descargaron las fuentes del tag v6.17 del kernel mainline:
```bash
cd ~/appletb-build
wget https://raw.githubusercontent.com/torvalds/linux/v6.17/drivers/hid/hid-appletb-kbd.c
wget https://raw.githubusercontent.com/torvalds/linux/v6.17/drivers/hid/hid-appletb-bl.c
wget https://raw.githubusercontent.com/torvalds/linux/v6.17/drivers/hid/hid-ids.h
```

Compilaron **sin parches** (las APIs que parcheamos para 6.11 ya existen nativamente en 6.17):
```bash
make KVER=6.17.0-23-generic
```

Instalación:
```bash
sudo cp ~/appletb-build/*.ko /lib/modules/6.17.0-23-generic/updates/dkms/
sudo depmod -a 6.17.0-23-generic
```

### 4. GRUB actualizado
```bash
sudo update-grub
```

## Módulos instalados en 6.17.0-23-generic

| Módulo | Origen |
|---|---|
| nvidia.ko.zst | linux-modules-nvidia-595-6.17.0-23-generic (precompilado) |
| nvidia-modeset.ko.zst | precompilado |
| nvidia-drm.ko.zst | precompilado |
| nvidia-uvm.ko.zst | precompilado |
| nvidia-peermem.ko.zst | precompilado |
| apple-bce.ko.zst | DKMS (automático) |
| hid-appletb-kbd.ko | compilado manualmente (sin parches) |
| hid-appletb-bl.ko | compilado manualmente (sin parches) |

## Configuración (sin cambios respecto a 6.11)
- GRUB: `pci=realloc,hpmmioprefsize=2G ibt=off`
- modprobe: `nvidia_drm modeset=1`
- modules-load: `apple-bce`, `hid-appletb-bl`, `hid-appletb-kbd`
- Xorg nvidia: desactivado

## Pendiente
- Reiniciar y verificar funcionamiento completo
- Si estable, eliminar kernel 6.11
