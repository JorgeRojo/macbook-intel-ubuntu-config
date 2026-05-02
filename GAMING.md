# Gaming con eGPU: PRIME Render Offload

Cómo usar la NVIDIA RTX 3070 (eGPU) para jugar en Ubuntu 24.04 con Steam/Proton.

---

## Cómo funciona

La RTX 3070 no puede manejar un monitor directamente (limitación del firmware Apple TB3). En su lugar, usamos **PRIME render offload**:

1. La RTX 3070 renderiza los frames del juego
2. Los frames se envían a la AMD Radeon Pro 555X vía PCIe/TB3
3. La AMD muestra la imagen en el monitor

Esto añade algo de latencia (~1-2ms) pero permite usar toda la potencia de la RTX 3070.

---

## Verificar que PRIME offload funciona

```bash
# OpenGL (debe decir NVIDIA)
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia glxinfo | grep "OpenGL renderer"
# → OpenGL renderer string: NVIDIA GeForce RTX 3070/PCIe/SSE2

# Vulkan (debe listar la NVIDIA)
vulkaninfo --summary | grep deviceName
# → NVIDIA GeForce RTX 3070
# → AMD Radeon RX Series (RADV POLARIS11)
# → Intel(R) UHD Graphics 630
```

Si `nvidia-smi` no funciona, la eGPU no está conectada o el driver no cargó.

---

## Configurar juegos en Steam

### Opciones de lanzamiento (obligatorio)

En Steam → Biblioteca → clic derecho en el juego → **Propiedades** → **Opciones de lanzamiento**:

```
DXVK_FILTER_DEVICE_NAME="RTX 3070" __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only %command%
```

### Con MangoHud (FPS overlay)

```bash
sudo apt install mangohud
```

```
MANGOHUD=1 DXVK_FILTER_DEVICE_NAME="RTX 3070" __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only mangohud %command%
```

---

## Explicación de cada variable

| Variable | Función |
|---|---|
| `DXVK_FILTER_DEVICE_NAME="RTX 3070"` | Fuerza a DXVK (Proton) a usar la NVIDIA. **Obligatorio** porque Vulkan enumera la AMD como GPU0 |
| `__NV_PRIME_RENDER_OFFLOAD=1` | Activa PRIME render offload para OpenGL |
| `__GLX_VENDOR_LIBRARY_NAME=nvidia` | Usa la librería GLX de NVIDIA en vez de Mesa |
| `__VK_LAYER_NV_optimus=NVIDIA_only` | Capa Vulkan que selecciona NVIDIA |
| `MANGOHUD=1` | Activa el overlay de MangoHud |
| `mangohud` (antes de `%command%`) | Wrapper que inyecta el overlay |

---

## Por qué los scripts bash NO funcionan

Steam lanza los juegos de Proton como subprocesos internos. Las variables de entorno del proceso padre de Steam **no se propagan** al juego dentro de Proton.

```bash
# ESTO NO FUNCIONA:
__NV_PRIME_RENDER_OFFLOAD=1 steam -applaunch 1627720
```

La única forma de pasar variables al juego es mediante las **Launch Options dentro de Steam**, que se inyectan directamente en el entorno del proceso del juego.

---

## Verificar que el juego usa la NVIDIA

Mientras el juego está corriendo:

```bash
nvidia-smi
```

Debe aparecer un proceso del juego en la lista de procesos GPU:

```
+-----------------------------------------------+
| Processes:                                    |
|  GPU   PID   Type   Process name   GPU Memory |
|    0   12345  C+G   .../LiesofP.exe    2048MiB|
+-----------------------------------------------+
```

Si no aparece, el juego está usando la AMD.

---

## Juegos nativos Linux (no Proton)

Para juegos nativos que usan OpenGL:

```
__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia %command%
```

Para juegos nativos que usan Vulkan:

```
__NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only %command%
```

---

## Rendimiento esperado

Con PRIME render offload hay una pequeña penalización vs display directo (~5-10%), pero la RTX 3070 sigue siendo mucho más potente que la AMD 555X.

Ejemplo con Lies of P (1080p, ajustes altos):
- AMD 555X: injugable (~5 FPS)
- RTX 3070 vía PRIME: 60+ FPS

---

## Problemas comunes

### El juego arranca pero usa la AMD

→ Falta `DXVK_FILTER_DEVICE_NAME="RTX 3070"` en las Launch Options.

### MangoHud no muestra overlay

→ Verificar que `mangohud` está antes de `%command%` y que `MANGOHUD=1` está presente.

### nvidia-smi dice "No devices found"

→ La eGPU no está conectada, el enclosure está apagado, o el driver no cargó. Verificar `lspci | grep -i nvidia`.

### El juego crashea al iniciar

→ Probar sin `DXVK_FILTER_DEVICE_NAME` para ver si es un problema de la GPU o del juego. Algunos juegos necesitan Proton Experimental.
