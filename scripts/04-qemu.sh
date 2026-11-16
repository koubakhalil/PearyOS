#!/bin/bash
# Boots the ISO under QEMU with UEFI firmware (OVMF), a virtual Intel Ethernet card and a VGA display.
# usage: 04-qemu.sh <iso> <cd|usb> <secureboot 0|1> <tag>
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); SRC=$(dirname "$HERE"); WORK=${WORK:-$SRC/work}
ISO=$1; MODE=$2; SB=$3; TAG=$4
W=$WORK/qemu-$TAG
rm -rf "$W"; mkdir -p "$W"

if [ "$SB" = 1 ]; then
  CODE=/usr/share/OVMF/OVMF_CODE_4M.secboot.fd
  VARS=/usr/share/OVMF/OVMF_VARS_4M.ms.fd
  MACHINE="q35,smm=on"
  EXTRA=(-global driver=cfi.pflash01,property=secure,value=on -global ICH9-LPC.disable_s3=1)
else
  CODE=/usr/share/OVMF/OVMF_CODE_4M.fd
  VARS=/usr/share/OVMF/OVMF_VARS_4M.fd
  MACHINE="q35"
  EXTRA=()
fi
cp "$VARS" "$W/vars.fd"

if [ "$MODE" = cd ]; then
  MEDIA=(-cdrom "$ISO")
else
  MEDIA=(-drive "file=$ISO,if=none,id=usbstick,format=raw,readonly=on" -device qemu-xhci -device "usb-storage,drive=usbstick,bootindex=1")
fi

setsid nohup qemu-system-x86_64 -name "pearyos-$TAG" -machine "$MACHINE" -accel tcg,thread=multi -cpu max \
  -smp ${QEMU_SMP:-2} -m ${QEMU_MEM:-3072} "${EXTRA[@]}" \
  -drive "if=pflash,format=raw,readonly=on,file=$CODE" -drive "if=pflash,format=raw,file=$W/vars.fd" \
  "${MEDIA[@]}" \
  -device e1000e,netdev=n0 -netdev user,id=n0 \
  -vga std -display none \
  -monitor "unix:$W/mon.sock,server,nowait" -serial "file:$W/serial.log" \
  -smbios type=11,value=io.systemd.credential:pearyos.selftest=1 \
  -no-reboot > "$W/qemu.log" 2>&1 < /dev/null &
echo $! > "$W/pid"
echo "started qemu pid $(cat "$W/pid") in $W"
