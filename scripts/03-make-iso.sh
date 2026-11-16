#!/bin/bash
# Step 3: assemble the hybrid, UEFI-bootable ISO (Secure Boot capable: Ubuntu shim + signed GRUB + signed kernel).
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd); SRC=$(dirname "$HERE"); WORK=${WORK:-$SRC/work}
ROOT=$WORK/rootfs
ISO=$WORK/iso
EFI=$WORK/efi
OUT=$WORK/out
NAME=${NAME:-pearyos-1.0-amd64}
LABEL=PEARYOS_1_0

if grep -q "$ROOT" /proc/mounts; then echo "ERROR: something is still mounted under $ROOT"; exit 1; fi
rm -rf "$ISO" "$EFI"
mkdir -p "$ISO/casper" "$ISO/boot/grub/fonts" "$ISO/.disk" "$EFI" "$OUT"

# --- kernel + initramfs -------------------------------------------------------
KV=$(ls "$ROOT"/boot/vmlinuz-* | sed 's/.*vmlinuz-//' | sort -V | tail -1)
echo "kernel: $KV"
cp -L "$ROOT/boot/vmlinuz-$KV" "$ISO/casper/vmlinuz"
cp -L "$ROOT/boot/initrd.img-$KV" "$ISO/casper/initrd"

# --- root filesystem image ----------------------------------------------------
echo "== mksquashfs =="
mksquashfs "$ROOT" "$ISO/casper/filesystem.squashfs" \
  -comp zstd -Xcompression-level 15 -b 1M -processors 2 -noappend -no-progress \
  -wildcards -e 'boot/initrd.img-*' -e 'boot/vmlinuz-*'
printf '%s' "$(du -sx --block-size=1 "$ROOT" | cut -f1)" > "$ISO/casper/filesystem.size"
chroot "$ROOT" dpkg-query -W --showformat='${Package}\t${Version}\n' > "$ISO/casper/filesystem.manifest"

echo "PearyOS 1.0 \"noble\" - Release amd64 ($(date +%Y%m%d))" > "$ISO/.disk/info"
cp /usr/share/grub/unicode.pf2 "$ISO/boot/grub/fonts/unicode.pf2"
cp "$SRC/boot/iso-grub.cfg" "$ISO/boot/grub/grub.cfg"

# --- EFI system partition image ----------------------------------------------
cp /usr/lib/shim/shimx64.efi.signed "$EFI/BOOTX64.EFI"
cp /usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed "$EFI/grubx64.efi"
cp /usr/lib/shim/mmx64.efi "$EFI/mmx64.efi"

# Also place the EFI loaders in the ISO9660 tree itself. Firmware boots from the ESP image below,
# but USB writers that copy the ISO's files onto a FAT32 stick (Rufus "ISO mode", etc.) need them here.
mkdir -p "$ISO/EFI/boot" "$ISO/EFI/ubuntu"
cp "$EFI/BOOTX64.EFI" "$ISO/EFI/boot/bootx64.efi"
cp "$EFI/grubx64.efi" "$ISO/EFI/boot/grubx64.efi"
cp "$EFI/mmx64.efi" "$ISO/EFI/boot/mmx64.efi"
cp "$SRC/boot/efi-stub.cfg" "$ISO/EFI/boot/grub.cfg"
cp "$SRC/boot/efi-stub.cfg" "$ISO/EFI/ubuntu/grub.cfg"

IMG=$EFI/efi.img
truncate -s 16M "$IMG"
mkfs.vfat -F 16 -n PEARYOS_EFI "$IMG" >/dev/null
mmd -i "$IMG" ::/EFI ::/EFI/BOOT ::/EFI/ubuntu ::/boot ::/boot/grub
mcopy -i "$IMG" "$EFI/BOOTX64.EFI" ::/EFI/BOOT/BOOTX64.EFI
mcopy -i "$IMG" "$EFI/grubx64.efi" ::/EFI/BOOT/grubx64.efi
mcopy -i "$IMG" "$EFI/mmx64.efi" ::/EFI/BOOT/mmx64.efi
# Signed GRUB's built-in prefix is /EFI/ubuntu; the stub hands over to the real menu on the ISO.
mcopy -i "$IMG" "$SRC/boot/efi-stub.cfg" ::/EFI/ubuntu/grub.cfg
mcopy -i "$IMG" "$SRC/boot/efi-stub.cfg" ::/EFI/BOOT/grub.cfg
mcopy -i "$IMG" "$SRC/boot/efi-stub.cfg" ::/boot/grub/grub.cfg
echo "== ESP contents =="; mdir -/ -i "$IMG" ::

# --- hybrid ISO (CD/DVD + raw USB write) ---------------------------------------
rm -f "$OUT/$NAME.iso"
xorriso -as mkisofs \
  -iso-level 3 -full-iso9660-filenames -joliet -joliet-long -rational-rock \
  -volid "$LABEL" -appid "PearyOS" -publisher "PearyOS live ISO" -preparer "xorriso" \
  -partition_offset 16 \
  -append_partition 2 C12A7328-F81F-11D2-BA4B-00A0C93EC93B "$IMG" \
  -appended_part_as_gpt \
  -iso_mbr_part_type EBD0A0A2-B9E5-4433-87C0-68B6B72699C7 \
  -e --interval:appended_partition_2:all:: -no-emul-boot \
  -isohybrid-gpt-basdat \
  -o "$OUT/$NAME.iso" "$ISO"

echo "== El Torito / partition report =="
xorriso -indev "$OUT/$NAME.iso" -report_el_torito plain -report_system_area plain 2>&1 | grep -v '^xorriso' | head -30
(cd "$OUT" && sha256sum "$NAME.iso" > "$NAME.iso.sha256")
ls -lh "$OUT"
echo "ISO BUILD COMPLETE"
