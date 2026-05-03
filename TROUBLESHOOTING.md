# Troubleshooting

Problemas conocidos y soluciones para Ubuntu 24.04 en MacBook Pro 2018 con eGPU NVIDIA.

---

## El cursor del ratón desaparece

**Causa:** Glitch del compositor GNOME Wayland con el renderer Vulkan.

**Fix rápido:** Pulsar `Ctrl+Alt+F4` y luego `Ctrl+Alt+F2` (cambia a TTY y vuelve).

**Fix permanente:**
```bash
echo "GSK_RENDERER=gl" | sudo tee -a /etc/environment
```
Reiniciar sesión para aplicar.

---

## Pantalla negra al arrancar

**Causa:** nvidia-modeset timeout (`0x0000c67d`) al inicializar la eGPU sobre Thunderbolt 3.

**Solución:** Reiniciar. Suele funcionar al segundo intento. Es intermitente.

**Si persiste:**
```bash
# Desde recovery mode (GRUB → Advanced → recovery)
sudo sed -i 's|modeset=1|modeset=0|' /etc/modprobe.d/nvidia-graphics-drivers-kms.conf
sudo update-initramfs -u -k 6.11.0-19-generic
sudo reboot
```
Luego volver a poner `modeset=1` y reiniciar.

---

## El juego no usa la NVIDIA (usa AMD integrada)

**Causa:** Vulkan enumera la AMD Radeon Pro 555X como GPU0. DXVK/Proton la elige por defecto.

**Solución:** Añadir `DXVK_FILTER_DEVICE_NAME="RTX 3070"` a las Launch Options de Steam:
```
DXVK_FILTER_DEVICE_NAME="RTX 3070" __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only %command%
```

**Verificar:** Mientras el juego corre, ejecutar `nvidia-smi`. El proceso del juego debe aparecer.

---

## Scripts bash no pasan variables a los juegos

**Causa:** Steam/Proton no hereda variables de entorno del proceso padre. Cuando lanzas Steam con variables, estas no llegan al juego dentro de Proton.

**Solución:** Usar exclusivamente las Launch Options dentro de Steam (Propiedades → Opciones de lanzamiento). No hay alternativa funcional desde scripts.

---

## Trackpad no funciona

**Causa:** El kernel genérico tiene los MacBook T2 en `hid_mouse_ignore_list`, lo que impide crear el dispositivo HID del trackpad.

**Solución:** Seguir el Paso 4 de [INSTALL.md](INSTALL.md) (compilar hid.ko parcheado + hid-magicmouse-t2).

**Verificar:**
```bash
xinput list | grep -i pointer    # Debe mostrar un pointer además del virtual
lsmod | grep hid_magicmouse_t2  # Debe estar cargado
```

---

## Monitor no detectado / resolución incorrecta

**Causa:** El monitor debe ir conectado a un puerto USB-C del Mac (no a la caja eGPU). La AMD Radeon Pro 555X maneja el display.

**Limitaciones:**
- Máximo 3440x1440@60Hz por USB-C
- 5120x2160 requiere DP 1.4 que la AMD 555X no soporta por este puerto

---

## nvidia-smi no funciona / "No devices found"

**Verificar:**
```bash
lspci | grep -i nvidia          # ¿Aparece la RTX 3070?
lsmod | grep nvidia             # ¿Módulos cargados?
sudo dmesg | grep -i nvidia     # ¿Errores?
```

**Posibles causas:**
- eGPU no conectada o enclosure apagado
- Falta `pci=realloc,hpmmioprefsize=2G` en GRUB
- Driver NVIDIA no instalado o DKMS falló

---

## WiFi no funciona tras instalar firmware

**Verificar:**
```bash
sudo dmesg | grep brcmfmac      # ¿Errores de firmware?
ls /lib/firmware/brcm/brcmfmac*  # ¿Archivos presentes?
```

Si no hay firmware, repetir:
```bash
sudo get-apple-firmware get_from_online  # Opción 7 (Sonoma)
sudo reboot
```

---

## Teclado no funciona tras reiniciar

**Causa:** `apple-bce` no se cargó.

```bash
sudo modprobe apple_bce
# Si funciona, verificar:
cat /etc/modules-load.d/t2.conf  # Debe contener "apple-bce"
```

---

## Touch Bar muestra solo ESC

**Causa:** Módulos `hid-appletb-kbd` / `hid-appletb-bl` no cargados.

```bash
sudo modprobe hid_appletb_kbd
sudo modprobe hid_appletb_bl
# Si funciona, verificar:
cat /etc/modules-load.d/appletb.conf
```

---

## Después de actualizar nvidia-driver

Las actualizaciones de NVIDIA pueden sobreescribir configuraciones:

```bash
# Verificar modeset
cat /etc/modprobe.d/nvidia-graphics-drivers-kms.conf
# Debe decir: options nvidia_drm modeset=1

# Verificar que Xorg nvidia sigue desactivado
ls /usr/share/X11/xorg.conf.d/10-nvidia.conf 2>/dev/null && \
  echo "¡PELIGRO! Renombrar a .disabled" || echo "OK"

# Regenerar initramfs
sudo update-initramfs -u -k $(uname -r)
```

---

## Kernels que NO funcionan

| Kernel | Problema |
|---|---|
| >6.11 (6.17, 6.18) | nvidia-modeset timeout → pantalla negra |
| <6.4 con driver 595 | Driver incompatible |

**Quedarse en 6.11.0-19-generic.**

---

## Drivers NVIDIA que NO funcionan

| Driver | Problema |
|---|---|
| nvidia-535 | `RmInitAdapter failed` en kernel >6.4 con Ampere |
| nvidia-595-open | Timeout de modeset sobre TB3 (DMA failure) |

**Usar nvidia-driver-595 (propietario, no open).**

---

## Display desde la caja eGPU (NO funciona)

Intentamos:
- Parchear nvidia-open (timeout 5s→60s) — sigue fallando
- Diferentes configuraciones de Xorg — no detecta outputs
- Kernel 6.17 con mejor soporte TB3 — pantalla negra

**Conclusión:** Es una limitación del firmware Apple TB3. El controlador Thunderbolt del MacBook no permite DMA bidireccional completo para el display engine de NVIDIA. Solo funciona PRIME render offload (la GPU renderiza pero no maneja el display).
