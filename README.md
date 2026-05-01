# MacBook Intel Ubuntu Config

Installation guides for Ubuntu on MacBooks with Intel chipset and T2 chip.

## Hardware

- MacBook Pro 15,1 (2018, 15") — Intel i7-8750H
- Apple T2 Security Chip
- eGPU: NVIDIA RTX 3070 via Thunderbolt 3

## Documentación

| Documento | Descripción |
|---|---|
| [EGPU_INSTALL_GUIDE.md](EGPU_INSTALL_GUIDE.md) | Guía completa paso a paso para reproducir la instalación desde cero |
| [EGPU_SETUP_SUMMARY.md](EGPU_SETUP_SUMMARY.md) | Resumen de la configuración final |
| [EGPU_TECHNICAL_DETAILS.md](EGPU_TECHNICAL_DETAILS.md) | Parches de código y detalles técnicos |
| [EGPU_SESSION_2_FIX.md](EGPU_SESSION_2_FIX.md) | Log de la segunda sesión de correcciones |
| [EGPU_TROUBLESHOOTING_HISTORY.md](EGPU_TROUBLESHOOTING_HISTORY.md) | Historial cronológico de intentos y errores |

## Estado

- ✅ Ubuntu 24.04 con kernel 6.11.0-19-generic
- ✅ Teclado/trackpad internos (apple-bce via DKMS)
- ✅ Touch Bar (hid-appletb-kbd/bl compilados manualmente)
- ✅ NVIDIA driver 595.58.03 compilado e instalado
- ✅ nvidia-smi — RTX 3070 funcionando (compute/CUDA)
- ❌ WiFi — requiere firmware extraído de macOS
- ❌ Display desde eGPU — nvidia-modeset incompatible con TB3 (display usa GPUs internas)
