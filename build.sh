#!/bin/bash
# Builds the PearyOS live ISO from scratch. Run as root on an Ubuntu/Debian host with:
#   debootstrap squashfs-tools xorriso mtools dosfstools grub-efi-amd64-signed shim-signed python3-pil python3-numpy librsvg2-bin
# Output: $WORK/out/pearyos-1.0-amd64.iso (+ .sha256).   WORK=<dir> chooses the build directory (needs ~12 GB free).
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
export WORK=${WORK:-$HERE/work}
bash "$HERE/scripts/01-bootstrap.sh"
bash "$HERE/scripts/02-build-rootfs.sh"
bash "$HERE/scripts/03-make-iso.sh"
