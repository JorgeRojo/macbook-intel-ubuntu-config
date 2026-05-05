# Guía de instalación paso a paso

Guía completa para configurar Ubuntu 24.04 en MacBook Pro 2018 (T2) con eGPU NVIDIA RTX 3070.

**Tiempo estimado:** 1-2 horas (sin contar descargas)

**Requisitos previos:**
- Ubuntu 24.04 instalado (usar ISO de [T2Linux](https://wiki.t2linux.org/distributions/ubuntu/installation/))
- Conexión a internet (ethernet o WiFi temporal)
- Ratón USB externo (el trackpad no funciona hasta el paso 5)

---

## Paso 1: Kernel 6.11 genérico

```bash
sudo apt install linux-image-6.11.0-19-generic linux-headers-6.11.0-19-generic
sudo reboot
```

> Seleccionar este kernel en GRUB si hay otros instalados.

---

## Paso 2: Soporte T2 (teclado + audio)

El módulo `apple-bce` proporciona teclado, audio y la interfaz USB virtual del trackpad.

```bash
sudo apt install apple-bce
sudo dkms build apple-bce/0.2 -k 6.11.0-19-generic
sudo dkms install apple-bce/0.2 -k 6.11.0-19-generic
echo "apple-bce" | sudo tee /etc/modules-load.d/t2.conf
```

---

## Paso 3: Touch Bar

Los módulos `hid-appletb-kbd` y `hid-appletb-bl` no existen en el kernel 6.11. Hay que compilarlos desde el source de v6.17 con parches de compatibilidad.

```bash
mkdir -p ~/appletb-build && cd ~/appletb-build

# Descargar fuentes
wget -q https://raw.githubusercontent.com/torvalds/linux/v6.17/drivers/hid/hid-appletb-kbd.c
wget -q https://raw.githubusercontent.com/torvalds/linux/v6.17/drivers/hid/hid-appletb-bl.c
wget -q https://raw.githubusercontent.com/torvalds/linux/v6.11/drivers/hid/hid-ids.h
```

Crear `Makefile`:

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

### Parches de compatibilidad

**En ambos archivos** (`hid-appletb-kbd.c` y `hid-appletb-bl.c`), después de `#include "hid-ids.h"`, añadir:

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

**En ambos archivos**, aplicar estos reemplazos:
- `hid_find_field(` → `appletb_find_field(`

**Solo en `hid-appletb-kbd.c`:**
- `timer_container_of(kbd, t, inactivity_timer)` → `from_timer(kbd, t, inactivity_timer)`
- `secs_to_jiffies(x)` → `msecs_to_jiffies(1000 * x)` (3 ocurrencias)

### Compilar e instalar

```bash
make
sudo cp *.ko /lib/modules/6.11.0-19-generic/updates/dkms/
sudo depmod -a
printf "hid-appletb-bl\nhid-appletb-kbd\n" | sudo tee /etc/modules-load.d/appletb.conf
```

---

## Paso 4: Trackpad

El kernel 6.11 genérico ignora la interfaz del trackpad T2. Necesitamos tres módulos parcheados:

1. **hid.ko** — sin los T2 en `hid_mouse_ignore_list` (para que se cree el dispositivo HID del trackpad)
2. **hid-apple-t2.ko** — con `APPLE_IGNORE_MOUSE` (libera la interfaz mouse para magicmouse)
3. **hid-magicmouse-t2.ko** — con soporte trackpad T2

```bash
mkdir -p ~/trackpad-build && cd ~/trackpad-build
```

### 4.1 Descargar fuentes

```bash
# Archivos HID del kernel 6.11
for f in hid-core.c hid-input.c hid-quirks.c hidraw.c hid-debug.c hid-apple.c hid-ids.h; do
  wget -q "https://raw.githubusercontent.com/torvalds/linux/v6.11/drivers/hid/$f"
done

# hid-magicmouse parcheado (desde kernel 7.0.3 + parches T2)
git clone --depth 1 https://github.com/t2linux/linux-t2-patches.git /tmp/linux-t2-patches
git clone --depth 1 --branch v7.0.3 https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git /tmp/linux-stable

cd /tmp/linux-stable
patch -p1 < /tmp/linux-t2-patches/4001-asahi-trackpad.patch
patch -p1 < /tmp/linux-t2-patches/4004-HID-magicmouse-Add-support-for-trackpads-found-on-T2.patch
patch -p1 < /tmp/linux-t2-patches/4005-HID-magicmouse-fix-regression-breaking-support-for-M.patch

cp /tmp/linux-stable/drivers/hid/hid-magicmouse.c ~/trackpad-build/
cd ~/trackpad-build
```

### 4.2 Parchar hid-quirks.c

Eliminar los dispositivos T2 de `hid_mouse_ignore_list` (buscar la segunda aparición de `WELLSPRINGT2` en el archivo — la que está dentro de `hid_mouse_ignore_list`). Eliminar esas 8 líneas. **No tocar** las que están en `hid_have_special_driver`.

### 4.3 Parchar hid-apple.c

En `apple_probe()`, después de `unsigned long quirks = id->driver_data;`, añadir:

```c
if (quirks & APPLE_IGNORE_MOUSE && hdev->type == HID_TYPE_USBMOUSE)
    return -ENODEV;
```

En la tabla `apple_devices[]`, añadir `| APPLE_IGNORE_MOUSE` a los `driver_data` de todos los `WELLSPRINGT2_*`.

### 4.4 Parchar hid-magicmouse.c

Después de `#include "hid-ids.h"`, añadir:

```c
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

Reemplazos:
- `timer_container_of(msc, t, battery_timer)` → `from_timer(msc, t, battery_timer)`
- `secs_to_jiffies(X)` → `msecs_to_jiffies(X * 1000)`
- `static const __u8 *magicmouse_report_fixup` → `static __u8 *magicmouse_report_fixup`

### 4.5 Parchar hid-ids.h

Añadir al final:

```c
#define USB_DEVICE_ID_APPLE_WELLSPRINGT2_J680_ALT 0x0278
#define USB_DEVICE_ID_APPLE_MAGICMOUSE2_USBC 0x0323
#define USB_DEVICE_ID_APPLE_MAGICTRACKPAD2_USBC 0x0324
#define SPI_DEVICE_ID_APPLE_MACBOOK_PRO13_2020 0xF340
#define SPI_DEVICE_ID_APPLE_MACBOOK_PRO14_2021 0xF341
#define SPI_DEVICE_ID_APPLE_MACBOOK_PRO16_2021 0xF342
```

> Los SPI IDs usan 0xF3xx para evitar conflicto con J152F (0x0340). No importa — nunca se usan en hardware Intel.

### 4.6 Makefile

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

### 4.7 Compilar e instalar

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

# Configurar carga de módulos
cat << 'EOF' | sudo tee /etc/modprobe.d/trackpad-t2.conf
blacklist hid_apple
install hid_apple /sbin/modprobe hid_apple_t2
EOF

printf "hid-apple-t2\nhid-magicmouse-t2\n" | sudo tee /etc/modules-load.d/trackpad-t2.conf
sudo update-initramfs -u -k 6.11.0-19-generic
```

---

## Paso 5: Driver NVIDIA 595

```bash
sudo apt install nvidia-driver-595
```

Cuando pregunte sobre `nvidia-graphics-drivers-kms.conf`, aceptar la versión del paquete.

```bash
# Forzar modeset=1
sudo sed -i 's|modeset=0|modeset=1|g' /etc/modprobe.d/nvidia-graphics-drivers-kms.conf

# Opciones para eGPU
cat << 'EOF' | sudo tee /etc/modprobe.d/nvidia-egpu.conf
options nvidia NVreg_DynamicPowerManagement=0x00
options nvidia NVreg_PreserveVideoMemoryAllocations=0
EOF

# Desactivar Xorg nvidia (causa pantalla negra)
sudo mv /usr/share/X11/xorg.conf.d/10-nvidia.conf /usr/share/X11/xorg.conf.d/10-nvidia.conf.disabled 2>/dev/null
sudo mv /usr/share/X11/xorg.conf.d/11-nvidia-offload.conf /usr/share/X11/xorg.conf.d/11-nvidia-offload.conf.disabled 2>/dev/null
```

---

## Paso 6: GRUB

```bash
sudo sed -i 's|GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT="quiet splash pci=assign-busses,realloc,hpmmioprefsize=8G,hpmemsize=256M pcie_aspm=off ibt=off"|' /etc/default/grub
sudo sed -i 's|GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX="pm_async=off intel_iommu=on iommu=pt"|' /etc/default/grub
sudo update-grub
```

Parámetros explicados:
- `pci=assign-busses,realloc` — Fuerza al kernel a reasignar los recursos PCI, vital si el firmware del Mac reserva poco espacio.
- `hpmmioprefsize=8G` — Reserva 8GB para la eGPU (necesario para RTX serie 4000).
- `pcie_aspm=off` — Evita cuelgues de sincronización ("GPU progress") desactivando ahorro de energía.
- `ibt=off` — Desactiva Indirect Branch Tracking (incompatible con NVIDIA).
- `intel_iommu=on iommu=pt` — IOMMU en passthrough para eGPU.
- `pm_async=off` — Evita race conditions al inicializar TB3.

---

## Paso 7: WiFi

```bash
sudo apt install apple-firmware-script dmg2img -y
sudo get-apple-firmware get_from_online
# Seleccionar opción 7 (Sonoma) — descarga ~600MB
```

---

## Paso 8: Gestos del trackpad

### Gestos nativos (GNOME 46 Wayland)

```bash
# Natural scrolling (como Mac)
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll true
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
gsettings set org.gnome.desktop.peripherals.touchpad two-finger-scrolling-enabled true
gsettings set org.gnome.desktop.peripherals.touchpad speed 0.3
```

Gestos disponibles sin configuración extra:
- 2 dedos scroll → scroll (natural, como Mac)
- 2 dedos tap → clic derecho
- 3 dedos izq/der → cambiar workspace
- 3 dedos arriba → vista de actividades
- 3 dedos abajo → app grid

### Swipe atrás/adelante en Chrome

Chrome necesita un flag para activar el gesto de 2 dedos horizontal (atrás/adelante):

```bash
cp /usr/share/applications/google-chrome.desktop ~/.local/share/applications/google-chrome.desktop
sed -i 's|Exec=/usr/bin/google-chrome-stable|Exec=/usr/bin/google-chrome-stable --enable-features=TouchpadOverscrollHistoryNavigation|g' \
  ~/.local/share/applications/google-chrome.desktop
```

Reiniciar Chrome completamente para que aplique.

> En Firefox funciona de serie sin configuración extra.

---

## Paso 9: Tienda de aplicaciones

```bash
sudo snap install snap-store
```

---

## Paso 10: Steam y gaming

```bash
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install steam mangohud vulkan-tools libvulkan1 libvulkan1:i386 \
  mesa-vulkan-drivers mesa-vulkan-drivers:i386 gamemode lib32gcc-s1 -y
```

En cada juego → Propiedades → Opciones de lanzamiento:

```
DXVK_FILTER_DEVICE_NAME="RTX 3070" __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only %command%
```

> `DXVK_FILTER_DEVICE_NAME` es obligatorio porque Vulkan enumera la AMD como GPU0.

---

## Paso 11: Reiniciar y verificar

```bash
sudo update-initramfs -u -k 6.11.0-19-generic
sudo reboot
```

### Verificación post-arranque

```bash
uname -r                              # → 6.11.0-19-generic
nvidia-smi                            # → RTX 3070 visible
lsmod | grep apple_bce                # → cargado
lsmod | grep hid_appletb              # → cargado
lsmod | grep hid_magicmouse_t2        # → cargado

# Probar PRIME offload
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia glxinfo | grep "OpenGL renderer"
# → NVIDIA GeForce RTX 3070/PCIe/SSE2

# Probar Vulkan
vulkaninfo --summary | grep deviceName
# → NVIDIA GeForce RTX 3070 (debe aparecer)
```

---

## Recuperación

### Si el trackpad no funciona tras reiniciar

Desde recovery mode o con ratón USB:
```bash
sudo cp /lib/modules/6.11.0-19-generic/kernel/drivers/hid/hid.ko.zst.orig \
        /lib/modules/6.11.0-19-generic/kernel/drivers/hid/hid.ko.zst
sudo rm /etc/modprobe.d/trackpad-t2.conf /etc/modules-load.d/trackpad-t2.conf
sudo update-initramfs -u -k 6.11.0-19-generic
sudo reboot
```

### Si pantalla negra al arrancar (nvidia-modeset timeout)

Reiniciar de nuevo (suele funcionar al segundo intento). Si persiste:
```bash
# Desde recovery mode
sudo sed -i 's|modeset=1|modeset=0|' /etc/modprobe.d/nvidia-graphics-drivers-kms.conf
sudo update-initramfs -u -k 6.11.0-19-generic
sudo reboot
# Luego volver a poner modeset=1 y reiniciar
```

### Si se actualiza nvidia-driver

Verificar después de cada actualización:
```bash
cat /etc/modprobe.d/nvidia-graphics-drivers-kms.conf  # → modeset=1
ls /usr/share/X11/xorg.conf.d/10-nvidia.conf          # → NO debe existir (solo .disabled)
```

---

## Anexo: Compilación NVIDIA en Kernel 7.0 (T2)

Si usas un kernel **7.0.x-t2-noble** o superior, el driver oficial fallará al compilar debido a errores de \`objtool\` (naked returns / MITIGATION_RETHUNK). Sigue estos pasos para parchearlo manualmente:

### 1. Preparar el driver
Instala el driver (fallará la configuración inicial, es normal):
\`\`\`bash
sudo apt install nvidia-driver-595
\`\`\`

### 2. Parchear Kbuild y Makefile
Debemos decirles a los scripts de compilación de NVIDIA que ignoren las validaciones de \`objtool\` que el kernel 7.0 impone de forma estricta.

\`\`\`bash
# Entrar al directorio del source (ajustar versión si cambia)
cd /usr/src/nvidia-595.58.03/

# Insertar bypass en Kbuild y Makefile
sudo sed -i '1i OBJECT_FILES_NON_STANDARD := y' Kbuild
sudo sed -i '1i OBJECT_FILES_NON_STANDARD := y' Makefile
sudo sed -i '1i OBJECT_FILES_NON_STANDARD_nvidia.o := y' Makefile
\`\`\`

### 3. Modificar DKMS para desactivar Objtool
Editamos el archivo de configuración de DKMS para pasar flags adicionales al compilador:

\`\`\`bash
sudo sed -i 's/CONFIG_X86_KERNEL_IBT=/CONFIG_X86_KERNEL_IBT= CONFIG_OBJTOOL=n CONFIG_OBJTOOL_WERROR=n/g' dkms.conf
\`\`\`

### 4. Compilar e Instalar
Ahora forzamos la reconstrucción del módulo para el kernel 7.0 (sustituye el nombre del kernel si es necesario):

\`\`\`bash
sudo dkms build nvidia/595.58.03 -k 7.0.3-1-t2-noble
sudo dkms install nvidia/595.58.03 -k 7.0.3-1-t2-noble
sudo update-initramfs -u -k 7.0.3-1-t2-noble
\`\`\`

### 5. Reiniciar
Una vez instalado, reinicia. Al arrancar, verifica con:
\`\`\`bash
nvidia-smi
\`\`\`

### 6. Touch Bar en Kernel 7.0+
En kernels modernos como el 7.0, el macro \`timer_container_of\` o \`from_timer\` puede fallar si no se usa correctamente. La solución que aplicamos fue:

1. **Parche de Timer**: Cambiar la inicialización del timer en \`hid-appletb-kbd.c\`:
   - Buscar: \`struct appletb_kbd *kbd = from_timer(kbd, t, inactivity_timer);\`
   - Cambiar por: \`struct appletb_kbd *kbd = container_of(t, struct appletb_kbd, inactivity_timer);\`

2. **Helper de búsqueda**: Asegurarse de incluir la función \`appletb_find_field\` (incluida en el paso 3 de esta guía) y realizar el reemplazo de \`hid_find_field\` por \`appletb_find_field\`.

---

**Nota sobre el Trackpad:** En Kernel 7.0, los parches actuales de \`hid-core.c\` entran en conflicto con la nueva arquitectura del sistema HID de Linux. Se recomienda usar los drivers genéricos o esperar a una actualización oficial de los parches T2 para esta versión del kernel.
