# Guía Completa: Configuración MacBook Pro 2018 (T2) + eGPU en Linux Mint (Kernel 7.0)

Esta guía documenta los pasos realizados para poner a punto un MacBook Pro 15" (2018) con chip T2, funcionando con una eGPU NVIDIA RTX 4070 Ti bajo el Kernel **7.0.1-1-t2-noble** (versión verificada).

---

## 1. Firmware WiFi (Chip BCM4364)
El WiFi no funciona de serie porque requiere firmware propietario de Apple.

```bash
sudo apt install dmg2img apple-firmware-script -y
sudo get-apple-firmware get_from_online
# Seleccionar opción 7 (Sonoma) para mayor estabilidad en chips BCM4364.
```

---

## 2. Soporte T2 (Teclado y Audio)
Instalación del módulo puente `apple-bce`:

```bash
sudo apt install apple-bce
# Asegurar carga al arranque
echo "apple-bce" | sudo tee /etc/modules-load.d/t2.conf
```

---

## 3. Touch Bar (Parches para Kernel 7.0)
Los drivers de la Touch Bar requieren parches manuales para ser compatibles con la arquitectura de timers del Kernel 7.0.

### Compilación:
1. Descargar fuentes de `hid-appletb-kbd.c` y `hid-appletb-bl.c`.
2. **Parche crítico (Timer)**: En `hid-appletb-kbd.c`, cambiar:
   - *De:* `struct appletb_kbd *kbd = from_timer(kbd, t, inactivity_timer);`
   - *A:* `struct appletb_kbd *kbd = container_of(t, struct appletb_kbd, inactivity_timer);`
3. Compilar e instalar (usar la versión del kernel actual):
```bash
KVER=7.0.1-1-t2-noble make
sudo cp *.ko /lib/modules/7.0.1-1-t2-noble/updates/dkms/
sudo depmod -a 7.0.1-1-t2-noble
```

---

## 4. eGPU NVIDIA RTX 4070 Ti (Kernel Surgery)
El driver oficial NVIDIA 595 falla al compilar en Kernel 7.0 por errores de `objtool`. Aplicamos una "cirugía" al código del driver.

### Paso A: Parchear Kbuild/Makefile
```bash
cd /usr/src/nvidia-595.58.03/
sudo sed -i '1i OBJECT_FILES_NON_STANDARD := y' Kbuild
sudo sed -i '1i OBJECT_FILES_NON_STANDARD := y' Makefile
sudo sed -i '1i OBJECT_FILES_NON_STANDARD_nvidia.o := y' Makefile
```

### Paso B: Modificar DKMS
Para saltar el error de "naked returns":
```bash
sudo sed -i 's/CONFIG_X86_KERNEL_IBT=/CONFIG_X86_KERNEL_IBT= CONFIG_OBJTOOL=n CONFIG_OBJTOOL_WERROR=n/g' /usr/src/nvidia-595.58.03/dkms.conf
```

### Paso C: Compilación e instalación
```bash
sudo dkms build nvidia/595.58.03 -k 7.0.1-1-t2-noble
sudo dkms install nvidia/595.58.03 -k 7.0.1-1-t2-noble
```

---

## 6. Configuración de GRUB y Optimización eGPU (FINAL)
Tras pruebas exhaustivas, se confirma que el modelo MacBook Pro 2018 (T2) tiene una limitación de hardware en el ancho de banda del BAR (256MB) que impide el modo "Direct Display" estable en Kernel 7.0. La solución definitiva es el **Modo PRIME Offload**.

### Editar `/etc/default/grub`:
```text
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash pci=realloc,assign-busses,use_crs,hp_mmio_window,hpmmioprefsize=32G,hpmemsize=256M pcie_aspm=off ibt=off pm_async=off intel_iommu=on iommu=pt"
```

### Desactivar Modeset (OBLIGATORIO para estabilidad):
```bash
echo "options nvidia_drm modeset=0" | sudo tee /etc/modprobe.d/nvidia-modeset.conf
sudo update-grub
sudo update-initramfs -u -k 7.0.1-1-t2-noble
```

---

## 7. Lanzador de Steam Optimizado
Para evitar cuelgues al abrir Steam y aplicar la potencia de la RTX 4070 Ti de forma global, se recomienda usar un lanzador personalizado en el escritorio (`Steam_eGPU.desktop` incluido en este repo).

**Comando del lanzador:**
```bash
bash -c "killall -9 steam 2>/dev/null; __NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only DXVK_FILTER_DEVICE_NAME='RTX 4070 Ti' VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.json steam"
```

---

## 8. Uso en Gaming (Steam)
Si no usas el lanzador anterior, añade esto manualmente a cada juego en **Opciones de lanzamiento**:

```text
__NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only DXVK_FILTER_DEVICE_NAME="RTX 4070 Ti" %command%
```

---

## Verificación final
- `nvidia-smi`: Debe mostrar la RTX 4070 Ti con driver 595.x.
- `vulkaninfo --summary`: Debe responder (usando el ICD de la Radeon para la interfaz).
- `uname -r`: 7.0.1-1-t2-noble.

**Documento actualizado por Gemini CLI - 6 de Mayo de 2026**
