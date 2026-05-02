# Guía: eGPU NVIDIA RTX 3070 en MacBook Pro T2 (2018) con Ubuntu 24.04

## Hardware

- MacBook Pro 15,1 (2018, 15") — Intel i7-8750H, 16GB RAM
- Apple T2 Security Chip
- eGPU: NVIDIA RTX 3070 (o similar Ampere/Turing) en enclosure Thunderbolt 3
- Monitor externo conectado a un puerto USB-C/TB3 del Mac (NO a la caja eGPU)

## Resultado final

- Juegos acelerados con RTX 3070 vía PRIME render offload
- Monitor externo funcionando (vía AMD Radeon Pro 555X interna)
- Teclado, trackpad y Touch Bar del Mac funcionando
- Steam + Proton para juegos de Windows
- nvidia-smi y CUDA operativos

---

## 1. Instalar Ubuntu 24.04

Usar la ISO de T2Linux: https://wiki.t2linux.org/distributions/ubuntu/installation/

Esto instala Ubuntu con soporte básico para el chip T2.

## 2. Instalar kernel 6.11 genérico

```bash
sudo apt install linux-image-6.11.0-19-generic linux-headers-6.11.0-19-generic
```

Este kernel es estable y compatible con NVIDIA 595.

## 3. Instalar soporte T2 (apple-bce)

```bash
sudo apt install apple-bce
sudo dkms build apple-bce/0.2 -k 6.11.0-19-generic
sudo dkms install apple-bce/0.2 -k 6.11.0-19-generic
echo "apple-bce" | sudo tee /etc/modules-load.d/t2.conf
```

## 4. Compilar módulos Touch Bar

Descargar fuentes del kernel mainline (tag v6.17 o master):

```bash
mkdir -p ~/appletb-build && cd ~/appletb-build
wget https://raw.githubusercontent.com/torvalds/linux/v6.17/drivers/hid/hid-appletb-kbd.c
wget https://raw.githubusercontent.com/torvalds/linux/v6.17/drivers/hid/hid-appletb-bl.c
wget https://raw.githubusercontent.com/torvalds/linux/v6.11/drivers/hid/hid-ids.h
```

Crear Makefile:

```makefile
KVER ?= 6.11.0-19-generic
KDIR := /lib/modules/$(KVER)/build

obj-m += hid-appletb-kbd.o
obj-m += hid-appletb-bl.o

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
```

Parchear para compatibilidad con kernel 6.11 (3 cambios en cada archivo):

**hid-appletb-kbd.c:**
1. Después de `#include "hid-ids.h"`, añadir:
```c
static struct hid_field *appletb_find_field(struct hid_device *hdev, unsigned int type,
					    unsigned int application, unsigned int usage)
{
	struct hid_report_enum *re = &hdev->report_enum[type];
	struct hid_report *report;
	struct hid_field *field;
	int i, j;

	list_for_each_entry(report, &re->report_list, list) {
		if (report->application != application)
			continue;
		for (i = 0; i < report->maxfield; i++) {
			field = report->field[i];
			for (j = 0; j < field->maxusage; j++) {
				if (field->usage[j].hid == usage)
					return field;
			}
		}
	}
	return NULL;
}
```
2. Reemplazar `timer_container_of(kbd, t, inactivity_timer)` → `from_timer(kbd, t, inactivity_timer)`
3. Reemplazar `secs_to_jiffies(x)` → `msecs_to_jiffies(1000 * x)` (3 ocurrencias)
4. Reemplazar `hid_find_field(` → `appletb_find_field(`

**hid-appletb-bl.c:**
1. Añadir la misma función `appletb_find_field` después de `#include "hid-ids.h"`
2. Reemplazar `hid_find_field(` → `appletb_find_field(` (2 ocurrencias)

Compilar e instalar:

```bash
make KVER=6.11.0-19-generic
sudo cp *.ko /lib/modules/6.11.0-19-generic/updates/dkms/
sudo depmod -a 6.11.0-19-generic
printf "hid-appletb-bl\nhid-appletb-kbd\n" | sudo tee /etc/modules-load.d/appletb.conf
```

## 5. Compilar driver del Trackpad (hid-magicmouse T2)

El kernel 6.11 genérico ignora la interfaz del trackpad de los MacBook T2. Necesitamos:
1. Recompilar `hid.ko` eliminando los T2 de `hid_mouse_ignore_list`
2. Compilar `hid-apple` parcheado con `APPLE_IGNORE_MOUSE` para que libere la interfaz del mouse
3. Compilar `hid-magicmouse` parcheado con soporte T2

```bash
mkdir -p ~/trackpad-build && cd ~/trackpad-build
```

### Descargar fuentes

```bash
# Kernel 6.11 (hid-core, hid-input, hid-quirks, hidraw, hid-debug, hid-apple)
for f in hid-core.c hid-input.c hid-quirks.c hidraw.c hid-debug.c hid-apple.c hid-ids.h; do
  wget -q "https://raw.githubusercontent.com/torvalds/linux/v6.11/drivers/hid/$f" -O "$f"
done

# hid-magicmouse del kernel 7.0.3 (base para los parches T2)
wget -q "https://raw.githubusercontent.com/torvalds/linux/v7.0.3/drivers/hid/hid-magicmouse.c" -O hid-magicmouse.c
```

### Aplicar parches T2 a hid-magicmouse

```bash
git clone --depth 1 https://github.com/t2linux/linux-t2-patches.git /tmp/linux-t2-patches

# Primero aplicar el parche base asahi-trackpad al source 7.0.3 completo
# (necesario para que el parche 4004 aplique)
# Alternativa: descargar el kernel 7.0.3 completo y aplicar los parches ahí:
cd /tmp && git clone --depth 1 --branch v7.0.3 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
cd /tmp/linux-stable
patch -p1 < /tmp/linux-t2-patches/4001-asahi-trackpad.patch
patch -p1 < /tmp/linux-t2-patches/4004-HID-magicmouse-Add-support-for-trackpads-found-on-T2.patch
patch -p1 < /tmp/linux-t2-patches/4005-HID-magicmouse-fix-regression-breaking-support-for-M.patch

# Copiar el hid-magicmouse parcheado
cp /tmp/linux-stable/drivers/hid/hid-magicmouse.c ~/trackpad-build/
```

### Parchar hid-apple.c (añadir APPLE_IGNORE_MOUSE)

En `hid-apple.c`, en la función `apple_probe`, después de `unsigned long quirks = id->driver_data;`:

```c
if (quirks & APPLE_IGNORE_MOUSE && hdev->type == HID_TYPE_USBMOUSE)
    return -ENODEV;
```

Y añadir `| APPLE_IGNORE_MOUSE` a los `driver_data` de todos los dispositivos `WELLSPRINGT2_*`.

### Parchar hid-quirks.c (eliminar T2 de hid_mouse_ignore_list)

Eliminar las líneas con `WELLSPRINGT2` de la lista `hid_mouse_ignore_list` (mantener las de `hid_have_special_driver`).

### Parchar hid-magicmouse.c para kernel 6.11

Añadir al inicio (después de `#include "hid-ids.h"`):

```c
/* Compat defines for kernel 6.11 */
#ifndef HID_TYPE_SPI_MOUSE
#define HID_TYPE_SPI_MOUSE 0xFF
#endif
#ifndef SPI_VENDOR_ID_APPLE
#define SPI_VENDOR_ID_APPLE 0x05AC
#endif
#ifndef HOST_VENDOR_ID_APPLE
#define HOST_VENDOR_ID_APPLE 0x05AC
#endif
#ifndef BUS_HOST
#define BUS_HOST 0x19
#endif
#ifndef BUS_SPI
#define BUS_SPI 0x1C
#endif
#ifndef HID_SPI_DEVICE
#define HID_SPI_DEVICE(ven, dev) HID_DEVICE(0x1C, HID_GROUP_ANY, ven, dev)
#endif
```

Reemplazar `timer_container_of(msc, t, battery_timer)` → `from_timer(msc, t, battery_timer)`

Reemplazar `secs_to_jiffies(X)` → `msecs_to_jiffies(X * 1000)`

Cambiar `static const __u8 *magicmouse_report_fixup` → `static __u8 *magicmouse_report_fixup`

### Parchar hid-ids.h (añadir IDs que faltan)

```c
#define USB_DEVICE_ID_APPLE_WELLSPRINGT2_J680_ALT 0x0278
#define USB_DEVICE_ID_APPLE_MAGICMOUSE2_USBC 0x0323
#define USB_DEVICE_ID_APPLE_MAGICTRACKPAD2_USBC 0x0324
#define SPI_DEVICE_ID_APPLE_MACBOOK_PRO13_2020 0xF340
#define SPI_DEVICE_ID_APPLE_MACBOOK_PRO14_2021 0xF341
#define SPI_DEVICE_ID_APPLE_MACBOOK_PRO16_2021 0xF342
```

(Los SPI IDs usan 0xF3xx para evitar conflicto con J152F=0x0340; no importa, nunca se usan en hardware Intel)

### Makefile

```makefile
KVER ?= $(shell uname -r)
KDIR ?= /lib/modules/$(KVER)/build
ccflags-y += -I$(src)

obj-m += hid.o
obj-m += hid-apple-t2.o
obj-m += hid-magicmouse-t2.o

hid-y := hid-core.o hid-input.o hid-quirks.o hidraw.o hid-debug.o
hid-apple-t2-y := hid-apple.o
hid-magicmouse-t2-y := hid-magicmouse.o

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules
clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
```

### Compilar e instalar

```bash
make

# Backup del hid.ko original
sudo cp /lib/modules/6.11.0-19-generic/kernel/drivers/hid/hid.ko.zst \
        /lib/modules/6.11.0-19-generic/kernel/drivers/hid/hid.ko.zst.orig

# Instalar hid.ko parcheado
zstd hid.ko -o hid.ko.zst --force
sudo cp hid.ko.zst /lib/modules/6.11.0-19-generic/kernel/drivers/hid/hid.ko.zst

# Instalar módulos del trackpad
sudo cp hid-apple-t2.ko hid-magicmouse-t2.ko /lib/modules/6.11.0-19-generic/updates/dkms/
sudo depmod -a
```

### Configurar carga de módulos

```bash
# Blacklistear hid-apple original, usar el parcheado
cat << 'EOF' | sudo tee /etc/modprobe.d/trackpad-t2.conf
blacklist hid_apple
install hid_apple /sbin/modprobe hid_apple_t2
EOF

# Cargar módulos al boot
printf "hid-apple-t2\nhid-magicmouse-t2\n" | sudo tee /etc/modules-load.d/trackpad-t2.conf

sudo update-initramfs -u -k 6.11.0-19-generic
```

### Recuperación si falla

Si el sistema no arranca correctamente, desde recovery mode o live USB:
```bash
sudo cp /lib/modules/6.11.0-19-generic/kernel/drivers/hid/hid.ko.zst.orig \
        /lib/modules/6.11.0-19-generic/kernel/drivers/hid/hid.ko.zst
sudo rm /etc/modprobe.d/trackpad-t2.conf /etc/modules-load.d/trackpad-t2.conf
sudo update-initramfs -u -k 6.11.0-19-generic
```

## 6. Instalar driver NVIDIA 595 propietario

```bash
sudo apt install nvidia-driver-595
```

Cuando pregunte sobre `nvidia-graphics-drivers-kms.conf`, aceptar la versión del paquete (Y).

Luego configurar modeset:

```bash
sudo sed -i 's|modeset=0|modeset=1|g' /etc/modprobe.d/nvidia-graphics-drivers-kms.conf
```

## 7. Configurar opciones NVIDIA para eGPU

```bash
cat << 'EOF' | sudo tee /etc/modprobe.d/nvidia-egpu.conf
options nvidia NVreg_DynamicPowerManagement=0x00
options nvidia NVreg_PreserveVideoMemoryAllocations=0
EOF
```

## 8. Desactivar Xorg nvidia (evita pantalla negra)

```bash
sudo mv /usr/share/X11/xorg.conf.d/10-nvidia.conf /usr/share/X11/xorg.conf.d/10-nvidia.conf.disabled
sudo mv /usr/share/X11/xorg.conf.d/11-nvidia-offload.conf /usr/share/X11/xorg.conf.d/11-nvidia-offload.conf.disabled 2>/dev/null
```

## 9. Configurar GRUB

```bash
sudo sed -i 's|GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT="quiet splash pci=realloc,hpmmioprefsize=2G ibt=off"|' /etc/default/grub
```

Verificar que GRUB_DEFAULT apunta al kernel 6.11 (si es el único kernel, `GRUB_DEFAULT=0` funciona):

```bash
sudo sed -i 's|GRUB_DEFAULT=.*|GRUB_DEFAULT=0|' /etc/default/grub
sudo update-grub
```

## 10. Actualizar initramfs y reiniciar

```bash
sudo update-initramfs -u -k 6.11.0-19-generic
sudo reboot
```

## 11. Verificación post-arranque

```bash
uname -r                          # 6.11.0-19-generic
nvidia-smi                        # RTX 3070 visible
lsmod | grep apple_bce            # cargado
lsmod | grep hid_appletb          # cargado
xrandr | grep " connected"        # eDP + monitor externo
```

Probar PRIME render offload:

```bash
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia glxinfo | grep "OpenGL renderer"
# Debe decir: NVIDIA GeForce RTX 3070/PCIe/SSE2
```

## 12. Instalar Steam y gaming

```bash
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install steam vulkan-tools libvulkan1 libvulkan1:i386 mesa-vulkan-drivers mesa-vulkan-drivers:i386 gamemode lib32gcc-s1 glmark2 -y
```

En Steam → Propiedades del juego → Launch Options:

```
DXVK_FILTER_DEVICE_NAME="RTX 3070" __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only %command%
```

`DXVK_FILTER_DEVICE_NAME` es necesario porque Vulkan enumera la AMD como GPU0.

Con MangoHud FPS (`sudo apt install mangohud`):
```
MANGOHUD=1 DXVK_FILTER_DEVICE_NAME="RTX 3070" __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only mangohud %command%
```

## 13. WiFi

```bash
sudo apt install apple-firmware-script dmg2img -y
sudo get-apple-firmware get_from_online
# Seleccionar opción 7 (Sonoma) - descarga ~600MB
sudo reboot
```

WiFi Broadcom BCM4364 funciona tras reiniciar. Conectar vía NetworkManager.

---

## Topología de display

```
Monitor externo ← DisplayPort → Puerto USB-C del Mac → AMD Radeon Pro 555X (display)
                                                              ↑
                                                    PRIME render offload
                                                              ↑
                                                    RTX 3070 (eGPU vía TB3) → renderizado
```

El monitor NO va conectado a la caja eGPU. Va a un puerto del Mac.

---

## Notas de estabilidad

- El arranque con `modeset=1` puede fallar ocasionalmente (pantalla negra). Un segundo reinicio suele funcionar.
- Si falla consistentemente, desde recovery: `sudo sed -i 's|modeset=1|modeset=0|' /etc/modprobe.d/nvidia-graphics-drivers-kms.conf && sudo reboot`
- Luego volver a poner `modeset=1` y reiniciar.
- Si se actualiza `nvidia-driver-*`, verificar que `10-nvidia.conf` sigue desactivado y `modeset=1` no se sobreescribió.

## Lo que NO funciona

- Display directo desde la caja eGPU (nvidia-modeset timeout sobre TB3)
- Kernels >6.11 con NVIDIA modeset (pantalla negra al arrancar)
- Driver NVIDIA 535 (incompatible con kernel >6.4 en GPUs Ampere)
- Driver NVIDIA 595-open (timeout de modeset)
