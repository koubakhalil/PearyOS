#!/bin/bash
# Step 2: install and configure everything inside the rootfs (packages, PearyOS overlay, generated assets).
# Runs the setup in a PRIVATE mount namespace so no mounts can leak onto the host even if this gets killed.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); SRC=$(dirname "$HERE"); WORK=${WORK:-$SRC/work}
ROOT=$WORK/rootfs
[ "$(id -u)" = 0 ] || { echo "run as root"; exit 1; }
[ -e "$ROOT/etc/os-release" ] || { echo "run 01-bootstrap.sh first"; exit 1; }

# ---- stage the overlay + generated assets -------------------------------------------------------------
STAGE=$WORK/stage
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -a "$SRC/overlay/." "$STAGE/"
python3 -I "$HERE/make-assets.py" "$STAGE/usr/share/backgrounds/pearyos/pearyos-default.jpg"
mkdir -p "$STAGE/usr/share/icons/hicolor/scalable/apps"
cp "$SRC/assets/pearyos-logo.svg" "$STAGE/usr/share/icons/hicolor/scalable/apps/pearyos-logo.svg"
for s in 16 22 24 32 48 64 96 128 256; do
  mkdir -p "$STAGE/usr/share/icons/hicolor/${s}x${s}/apps"
  rsvg-convert -w "$s" -h "$s" "$SRC/assets/pearyos-logo.svg" -o "$STAGE/usr/share/icons/hicolor/${s}x${s}/apps/pearyos-logo.png"
done

install -m 0755 "$HERE/chroot-setup.sh" "$ROOT/root/chroot-setup.sh"
rm -rf "$ROOT/root/overlay"; mkdir -p "$ROOT/root/overlay"
cp -a "$STAGE/." "$ROOT/root/overlay/"

echo "host resolv.conf:"; cat /etc/resolv.conf
exec unshare -m bash -euo pipefail -c '
  R="$0"
  mount -t proc proc "$R/proc"
  mount -t sysfs sysfs "$R/sys"
  mount -t devpts devpts "$R/dev/pts"
  mount -t tmpfs tmpfs "$R/dev/shm"
  mount -t tmpfs tmpfs "$R/run"
  rm -f "$R/etc/resolv.conf"
  cp -L /etc/resolv.conf "$R/etc/resolv.conf"
  chroot "$R" /root/chroot-setup.sh
' "$ROOT"
