#!/usr/bin/env bash
#
# setup-and-build.sh — one-shot bring-up for the RK3506 Luckfox Lyra AMP
# (Linux big cores + NuttX on CPU2) from a fresh clone.
#
# What it does, in order:
#   1. init the nuttxos/nuttx + nuttxos/nuttx-apps submodules
#   2. apply the NuttX RK3506 AMP port patches (nuttxos/patches/*.patch)
#   3. reassemble the split buildroot download cache (buildroot/dl)
#   4. select the AMP+NuttX board config (non-interactive lunch)
#   5. build everything (u-boot + kernel + rootfs + amp/NuttX) and pack
#
# After this finishes, flash with:  ./rkbin/tools/upgrade_tool  (see README)
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DEFCONFIG="rk3506b_buildroot_spinand_amp_nuttx_defconfig"
NUTTX_CONFIG="luckfox-lyra-amp:nsh"

log() { echo -e "\n\033[1;32m>>> $*\033[0m"; }

# --- 1. submodules -----------------------------------------------------------
log "1/5 init submodules (nuttxos/nuttx, nuttxos/nuttx-apps)"
git submodule update --init nuttxos/nuttx nuttxos/nuttx-apps

# --- 2. apply NuttX port patches --------------------------------------------
log "2/5 apply NuttX RK3506 AMP port patches"
if [ -f nuttxos/nuttx/arch/arm/src/rk3506/rk3506_boot.c ]; then
	echo "  port already present, skipping git am"
else
	( cd nuttxos/nuttx && git am "$ROOT"/nuttxos/patches/*.patch )
fi

# --- 3. reassemble split dl cache -------------------------------------------
log "3/5 restore split buildroot/dl tarballs"
"$ROOT/tools/restore-dl-splits.sh"

# --- 4. select board config (non-interactive) -------------------------------
log "4/5 lunch $DEFCONFIG"
./build.sh "$DEFCONFIG"

# --- 5. full build ----------------------------------------------------------
log "5/5 build all (u-boot + kernel + rootfs + NuttX amp)"
./build.sh

log "DONE. Firmware in output/firmware/. NuttX amp image built via"
echo "     device/rockchip/common/scripts/mk-amp.sh build_nuttx()."
echo "     Flash: see README (upgrade_tool, erase rootfs before di -rootfs)."
