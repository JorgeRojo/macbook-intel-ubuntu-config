# Guía de Instalación Completa: eGPU NVIDIA RTX 3070 en MacBook Pro T2 + Ubuntu 24.04

## Hardware
- MacBook Pro 15,1 (2018, 15") — Intel i7-8750H, 16GB RAM
- Chip T2 (Apple iBridge)
- Thunderbolt 3: Intel Titan Ridge (JHL7540)
- eGPU: NVIDIA RTX 3070 (ZOTAC, GA104) vía enclosure Thunderbolt 3
- WiFi: Broadcom BCM4364 (requiere firmware de macOS)
- dGPU interna: AMD Radeon Pro 555X

## Kernel objetivo: 6.11.0-19-generic (Ubuntu genérico)

### ¿Por qué este kernel?
- Los kernels T2 (6.18, 7.0) tienen headers incompletos → NVIDIA no compila
- El kernel 7.0-t2 tiene API incompatible con NVIDIA 595 (strlcpy eliminado, objtool)
- El kernel 6.11 genérico es estable y NVIDIA compila sin parches

---

## Paso 1: Instalar kernel 6.11 genérico

```bash
sudo apt install linux-image-6.11.0-19-generic linux-headers-6.11.0-19-generic
```

## Paso 2: Instalar apple-bce (soporte T2 para teclado/trackpad)

```bash
sudo apt install apple-bce
sudo dkms build apple-bce/0.2 -k 6.11.0-19-generic
sudo dkms install apple-bce/0.2 -k 6.11.0-19-generic
```

Configurar carga automática:
```bash
echo "apple-bce" | sudo tee /etc/modules-load.d/t2.conf
```

## Paso 3: Compilar módulos hid-appletb (touchbar)

Estos módulos no existen en el kernel 6.11 (se añadieron al mainline después). Hay que compilarlos manualmente.

### 3.1 Descargar fuentes

```bash
mkdir -p ~/appletb-build && cd ~/appletb-build
wget https://raw.githubusercontent.com/torvalds/linux/master/drivers/hid/hid-appletb-kbd.c
wget https://raw.githubusercontent.com/torvalds/linux/master/drivers/hid/hid-appletb-bl.c
wget https://raw.githubusercontent.com/torvalds/linux/v6.11/drivers/hid/hid-ids.h
```

### 3.2 Parchear para compatibilidad con kernel 6.11

**En `hid-appletb-kbd.c`:**

1. Después de `#include "hid-ids.h"`, añadir la función helper:
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

**En `hid-appletb-bl.c`:**

1. Añadir la misma función `appletb_find_field` después de `#include "hid-ids.h"`
2. Reemplazar `hid_find_field(` → `appletb_find_field(` (2 ocurrencias)

### 3.3 Makefile

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

### 3.4 Compilar e instalar

```bash
cd ~/appletb-build
make KVER=6.11.0-19-generic
sudo cp *.ko /lib/modules/6.11.0-19-generic/updates/dkms/
sudo depmod -a 6.11.0-19-generic
```

Configurar carga automática:
```bash
echo -e "hid-appletb-bl\nhid-appletb-kbd" | sudo tee /etc/modules-load.d/appletb.conf
```

## Paso 4: Compilar driver NVIDIA 595

```bash
sudo apt install nvidia-dkms-595
sudo dkms build nvidia/595.58.03 -k 6.11.0-19-generic
sudo dkms install nvidia/595.58.03 -k 6.11.0-19-generic
```

## Paso 5: Configurar NVIDIA para eGPU Thunderbolt

```bash
cat << 'EOF' | sudo tee /etc/modprobe.d/nvidia-egpu.conf
options nvidia NVreg_DynamicPowerManagement=0x00
options nvidia NVreg_PreserveVideoMemoryAllocations=0
EOF
sudo update-initramfs -u -k 6.11.0-19-generic
```

## Paso 6: Configurar GRUB

```bash
# Parámetros de kernel
sudo sed -i 's|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT="quiet splash pci=realloc,hpmmioprefsize=2G ibt=off"|' /etc/default/grub

# Apuntar al kernel 6.11 (posición 1>4 en el submenú Advanced)
# NOTA: verificar posición con grep "menuentry" /boot/grub/grub.cfg
sudo sed -i 's|^GRUB_DEFAULT=.*|GRUB_DEFAULT="1>4"|' /etc/default/grub

sudo update-grub
```

### Parámetros GRUB explicados:
- `pci=realloc` — reasigna recursos PCI, necesario para eGPU en Mac
- `hpmmioprefsize=2G` — reserva espacio MMIO prefetchable para BAR1 (256MB) de la GPU
- `ibt=off` — desactiva Indirect Branch Tracking (conflicto con módulos NVIDIA en Intel)
- `pm_async=off intel_iommu=on iommu=pt` — en GRUB_CMDLINE_LINUX (siempre activos)

### Parámetros que NO funcionaron:
- `pcie_ports=native` — **impide el arranque** en este Mac
- `pci=assign-busses,hpbussize=0x33` — **impide el arranque** en este Mac
- `nvidia-drm.modeset=1` — causa timeout "Error while waiting for GPU progress" con eGPU TB3

## Paso 7: Reiniciar y verificar

```bash
sudo reboot
```

Verificaciones:
```bash
uname -r                    # 6.11.0-19-generic
nvidia-smi                  # Debe mostrar RTX 3070
lsmod | grep apple_bce      # Debe estar cargado
lsmod | grep hid_appletb    # Debe estar cargado
xinput list                 # Teclado/trackpad internos
```

---

## Estado actual (2 Mayo 2026)

### Funciona:
- ✅ Kernel 6.11 arranca correctamente
- ✅ apple-bce cargado (teclado/trackpad)
- ✅ hid-appletb-kbd cargado (touchbar)
- ✅ NVIDIA driver carga y reconoce la GPU
- ✅ BARs asignados correctamente (BAR0=16M, BAR1=256M, BAR3=32M)

### Pendiente de verificar:
- ⚠️ nvidia-smi — último intento dio timeout en nvidia-modeset (se aplicó fix de power management, pendiente reinicio)
- ❌ WiFi — requiere firmware extraído de macOS

---

## Notas sobre WiFi (BCM4364)

El hardware es detectado pero requiere firmware propietario de Apple:
1. Montar partición de macOS
2. Extraer firmware de `/usr/share/firmware/wifi/`
3. Copiar a `/lib/firmware/brcm/brcmfmac4364-pcie.*`

Ver: https://wiki.t2linux.org/guides/wifi/

---

## Archivos modificados

| Archivo | Propósito |
|---|---|
| `/etc/default/grub` | Kernel por defecto y parámetros de arranque |
| `/etc/modules-load.d/t2.conf` | Carga apple-bce |
| `/etc/modules-load.d/appletb.conf` | Carga hid-appletb-bl y hid-appletb-kbd |
| `/etc/modprobe.d/nvidia-egpu.conf` | Desactiva power management NVIDIA |
| `/lib/modules/6.11.0-19-generic/updates/dkms/` | Módulos compilados |

## Código fuente de parches

Los archivos fuente parcheados están en `~/appletb-build/`.
