# Sesión 4 - Fix nvidia-modeset timeout (2 Mayo 2026, 00:35-00:58)

## Problema

Con los BARs correctamente asignados (gracias a `pci=realloc,hpmmioprefsize=2G`), el driver NVIDIA carga pero `nvidia-modeset` entra en un loop infinito de timeout:

```
nvidia-modeset: ERROR: GPU:0: Error while waiting for GPU progress: 0x0000c67d:0 2:0:72:56
```

Esto bloquea el arranque normal (GDM no puede iniciar → pantalla negra).

## Causa raíz

`nvidia-modeset` intenta inicializar el **display engine** de la GPU (para manejar salidas de vídeo). Sobre Thunderbolt 3, esta inicialización falla con timeout porque:
- La latencia del enlace TB3 es demasiado alta para las operaciones de modeset
- El display engine no puede comunicarse correctamente a través del túnel PCIe de Thunderbolt

Este es un problema conocido documentado en:
- NVIDIA Forums: múltiples reportes de `0x0000c67d` con eGPUs
- GitHub issue Dunedan/mbp-2016-linux#60: mismo error BAR1=0M en MacBook + TB3
- NVIDIA Blog "Accelerating ML with eGPU": configuración funcional sin modeset

## Intentos fallidos

1. **Cambiar de nvidia-open a nvidia-closed (propietario)** → mismo error
2. **Desactivar power management** (`NVreg_DynamicPowerManagement=0x00`) → sin efecto
3. **Quitar `nvidia-drm.modeset=1` de GRUB** → sin efecto (modeset se carga igualmente)
4. **`blacklist nvidia_modeset`** simple → no funciona, las dependencias lo cargan igual

## Solución aplicada

Bloqueo absoluto de nvidia-modeset y nvidia-drm usando `install /bin/false`:

```bash
cat << 'EOF' | sudo tee /etc/modprobe.d/nvidia-blacklist.conf
# Prevent nvidia-modeset from loading - causes timeout on eGPU over Thunderbolt
blacklist nvidia_drm
blacklist nvidia_modeset
install nvidia_drm /bin/false
install nvidia_modeset /bin/false
EOF
sudo update-initramfs -u -k 6.11.0-19-generic
```

### Por qué funciona:
- `blacklist` solo previene la carga automática por udev
- `install /bin/false` intercepta CUALQUIER intento de carga (incluso dependencias) y lo reemplaza por `/bin/false` (no-op)
- Solo el módulo `nvidia` base se cargará → suficiente para nvidia-smi y CUDA
- El display usará i915 (Intel UHD 630) o amdgpu (Radeon Pro 555X)

## Implicaciones

- ✅ nvidia-smi y CUDA funcionarán (compute)
- ✅ El arranque no se bloqueará
- ❌ No habrá salida de vídeo desde la eGPU (no hay modeset)
- La pantalla del MacBook usará las GPUs internas

## Cambio de driver: open → closed

También se cambió de `nvidia-driver-595-open` a `nvidia-driver-595` (propietario cerrado):
```bash
sudo apt install nvidia-driver-595
```

## Pendiente
- Reiniciar y verificar que nvidia-smi funciona en modo compute
