# Sesión 2 - Correcciones aplicadas (1 Mayo 2026, ~22:25-22:47)

## Diagnóstico inicial

Al verificar el sistema, se encontró que:
1. El kernel activo era `7.0.3-1-t2-noble` (incompatible con NVIDIA)
2. GRUB apuntaba al 6.11 pero no lo arrancaba (formato de `GRUB_DEFAULT` no funcionaba)
3. El driver NVIDIA 595.58.03 estaba en DKMS como `added` — nunca compilado
4. El kernel 6.11 no tenía los módulos `hid-appletb-kbd` ni `hid-appletb-bl` (solo existen en kernels T2)

## Acciones realizadas

### 1. Compilar e instalar NVIDIA 595 para kernel 6.11
```bash
sudo dkms build nvidia/595.58.03 -k 6.11.0-19-generic
sudo dkms install nvidia/595.58.03 -k 6.11.0-19-generic
```
Resultado: 5 módulos compilados, firmados e instalados en `/lib/modules/6.11.0-19-generic/updates/dkms/`.

### 2. Corregir GRUB_DEFAULT
El formato con ID de submenú no funcionaba. Se cambió a formato numérico:
```bash
sudo sed -i 's|^GRUB_DEFAULT=.*|GRUB_DEFAULT="1>4"|' /etc/default/grub
sudo update-grub
```
`1>4` = submenú "Advanced options" → entrada 5ª (6.11.0-19-generic).

### 3. Intento fallido: compilar NVIDIA para kernel 6.18-t2
Los headers del paquete `linux-headers-6.18.26-1-t2-noble` están incompletos (falta `.config`, `Kbuild`, y la mayoría del árbol de build). DKMS no puede compilar módulos para ese kernel.

### 4. Compilar módulos hid-appletb para kernel 6.11
Los módulos `hid-appletb-kbd` y `hid-appletb-bl` se añadieron al kernel mainline después de 6.11, así que no existen en el kernel genérico. Se descargaron del mainline y se parchearon para compatibilidad con 6.11:

**Parches aplicados en `hid-appletb-kbd.c`:**
- `timer_container_of()` → `from_timer()` (no existe en 6.11)
- `secs_to_jiffies(x)` → `msecs_to_jiffies(1000 * x)` (no existe en 6.11)
- `hid_find_field()` → implementación local `appletb_find_field()` (no existe en 6.11)

**Parches aplicados en `hid-appletb-bl.c`:**
- `hid_find_field()` → implementación local `appletb_find_field()`

**Compilación:**
```bash
cd /home/jorge/appletb-build
make KVER=6.11.0-19-generic
```

**Instalación:**
```bash
sudo cp /home/jorge/appletb-build/*.ko /lib/modules/6.11.0-19-generic/updates/dkms/
sudo depmod -a 6.11.0-19-generic
```

### 5. Configurar carga automática de módulos
```bash
echo -e "hid-appletb-bl\nhid-appletb-kbd" | sudo tee /etc/modules-load.d/appletb.conf
```

## Estado final del kernel 6.11.0-19-generic

| Módulo | Ubicación | Carga |
|---|---|---|
| apple-bce.ko.zst | updates/dkms/ | /etc/modules-load.d/t2.conf |
| hid-appletb-bl.ko | updates/dkms/ | /etc/modules-load.d/appletb.conf |
| hid-appletb-kbd.ko | updates/dkms/ | /etc/modules-load.d/appletb.conf |
| nvidia.ko.zst | updates/dkms/ | udev (automático) |
| nvidia-modeset.ko.zst | updates/dkms/ | udev |
| nvidia-drm.ko.zst | updates/dkms/ | udev |
| nvidia-uvm.ko.zst | updates/dkms/ | udev |
| nvidia-peermem.ko.zst | updates/dkms/ | udev |

## Siguiente paso
Reiniciar y verificar:
```bash
uname -r          # Debe ser 6.11.0-19-generic
nvidia-smi        # Debe mostrar RTX 3070
xinput list       # Debe mostrar teclado/trackpad internos
```

## Código fuente de los parches
Los archivos fuente parcheados están en `/home/jorge/appletb-build/`.
