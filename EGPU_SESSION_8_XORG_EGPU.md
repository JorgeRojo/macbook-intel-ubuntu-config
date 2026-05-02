# Sesión 8 - Intento display con Xorg eGPU + GDM delay (2 Mayo 2026, 02:25-02:28)

## Estrategia

Usar Xorg configurado explícitamente para la eGPU con `AllowExternalGpus`, modeset=1, y un delay de 15s en GDM para dar tiempo a nvidia a estabilizarse sobre Thunderbolt.

## Cambios aplicados

### /etc/X11/xorg.conf.d/20-egpu.conf (nuevo)
```
Section "Device"
    Identifier "eGPU"
    Driver "nvidia"
    BusID "PCI:10:0:0"
    Option "AllowExternalGpus" "True"
    Option "AllowEmptyInitialConfiguration"
EndSection
```

### /usr/share/X11/xorg.conf.d/10-nvidia.conf (restaurado)
Vuelto a activar (necesario para que Xorg use nvidia).

### /etc/modprobe.d/nvidia-graphics-drivers-kms.conf
```
options nvidia_drm modeset=1
```

### /etc/systemd/system/gdm3.service.d/egpu-delay.conf (nuevo)
```
[Service]
ExecStartPre=/bin/sleep 15
```

## Comandos de reversión (si falla el arranque)

Desde recovery:
```bash
sudo sed -i 's|modeset=1|modeset=0|' /etc/modprobe.d/nvidia-graphics-drivers-kms.conf
sudo rm /etc/X11/xorg.conf.d/20-egpu.conf
sudo mv /usr/share/X11/xorg.conf.d/10-nvidia.conf /usr/share/X11/xorg.conf.d/10-nvidia.conf.disabled
sudo rm /etc/systemd/system/gdm3.service.d/egpu-delay.conf
sudo update-initramfs -u -k 6.11.0-19-generic
sudo reboot
```

## Pendiente
- Reiniciar y verificar si el monitor externo recibe señal
