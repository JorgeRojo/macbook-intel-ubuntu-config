#!/bin/bash
# Lies of P - Launch with NVIDIA RTX 3070 eGPU + FPS counter
__NV_PRIME_RENDER_OFFLOAD=1 \
__GLX_VENDOR_LIBRARY_NAME=nvidia \
__VK_LAYER_NV_optimus=NVIDIA_only \
DXVK_HUD=fps \
steam steam://rungameid/1627720
