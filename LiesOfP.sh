#!/bin/bash
# Lies of P - Launch with NVIDIA RTX 3070 eGPU + FPS counter
# NOTE: Set these as Launch Options in Steam instead if this doesn't work:
# __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia __VK_LAYER_NV_optimus=NVIDIA_only DXVK_HUD=devinfo,fps,frametimes %command%

export __NV_PRIME_RENDER_OFFLOAD=1
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export __VK_LAYER_NV_optimus=NVIDIA_only
export DXVK_HUD=devinfo,fps,frametimes

steam steam://rungameid/1627720
