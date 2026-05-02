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

## 5. Instalar driver NVIDIA 595 propietario

```bash
sudo apt install nvidia-driver-595
```

Cuando pregunte sobre `nvidia-graphics-drivers-kms.conf`, aceptar la versión del paquete (Y).

Luego configurar modeset:

```bash
sudo sed -i 's|modeset=0|modeset=1|g' /etc/modprobe.d/nvidia-graphics-drivers-kms.conf
```

## 6. Configurar opciones NVIDIA para eGPU

```bash
cat << 'EOF' | sudo tee /etc/modprobe.d/nvidia-egpu.conf
options nvidia NVreg_DynamicPowerManagement=0x00
options nvidia NVreg_PreserveVideoMemoryAllocations=0
EOF
```

## 7. Desactivar Xorg nvidia (evita pantalla negra)

```bash
sudo mv /usr/share/X11/xorg.conf.d/10-nvidia.conf /usr/share/X11/xorg.conf.d/10-nvidia.conf.disabled
sudo mv /usr/share/X11/xorg.conf.d/11-nvidia-offload.conf /usr/share/X11/xorg.conf.d/11-nvidia-offload.conf.disabled 2>/dev/null
```

## 8. Configurar GRUB

```bash
sudo sed -i 's|GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT="quiet splash pci=realloc,hpmmioprefsize=2G ibt=off"|' /etc/default/grub
```

Verificar que GRUB_DEFAULT apunta al kernel 6.11 (si es el único kernel, `GRUB_DEFAULT=0` funciona):

```bash
sudo sed -i 's|GRUB_DEFAULT=.*|GRUB_DEFAULT=0|' /etc/default/grub
sudo update-grub
```

## 9. Actualizar initramfs y reiniciar

```bash
sudo update-initramfs -u -k 6.11.0-19-generic
sudo reboot
```

## 10. Verificación post-arranque

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

## 11. Instalar Steam y gaming

```bash
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install steam vulkan-tools libvulkan1 libvulkan1:i386 mesa-vulkan-drivers mesa-vulkan-drivers:i386 gamemode lib32gcc-s1 glmark2 -y
```

En Steam → Propiedades del juego → Launch Options:

```
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only DXVK_HUD=fps %command%
```

## 12. WiFi

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
