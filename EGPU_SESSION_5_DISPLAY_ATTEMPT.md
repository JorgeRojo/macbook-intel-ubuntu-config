# Sesión 5 - Intento de display desde eGPU (2 Mayo 2026, 01:01-01:16)

## Descubrimiento importante

Tras el reinicio exitoso (nvidia-smi funciona), se descubrió que:
- El archivo `/etc/modprobe.d/nvidia-blacklist.conf` ya NO existía (eliminado al reinstalar driver)
- `nvidia_modeset` y `nvidia_drm` **se cargaron correctamente** durante el arranque
- `xrandr --listproviders` muestra la NVIDIA como Provider con 6 salidas (DP-1-1, HDMI-1-1, etc.)
- **Todas las salidas dicen "disconnected"** a pesar de tener monitor conectado por DisplayPort

## Diagnóstico del display

- `nvidia_drm modeset` no estaba activo (`/sys/module/nvidia_drm/parameters/modeset` vacío)
- Sin modeset activo, la GPU no puede manejar salidas de display
- El archivo `/etc/modprobe.d/nvidia-graphics-drivers-kms.conf` tiene `options nvidia_drm modeset=1` pero no se aplicó

## Intento: añadir nvidia-drm.modeset=1 a GRUB

Resultado: **cuelga el arranque** (pantalla negra, igual que antes).

## Conclusión parcial

- Sin `nvidia-drm.modeset=1` en GRUB: el sistema arranca, nvidia-smi funciona, pero no hay display desde eGPU
- Con `nvidia-drm.modeset=1` en GRUB: el sistema se cuelga al arrancar

## Siguiente paso a probar

Carga de modeset con **delay** después del arranque via servicio systemd:
```bash
# /etc/systemd/system/nvidia-modeset-delayed.service
[Unit]
Description=Load nvidia-modeset after boot
After=graphical.target
 
[Service]
Type=oneshot
ExecStartPre=/bin/sleep 30
ExecStart=/sbin/modprobe nvidia_drm modeset=1

[Install]
WantedBy=graphical.target
```

## Estado GRUB actual (limpio)
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash pci=realloc,hpmmioprefsize=2G ibt=off"
```
