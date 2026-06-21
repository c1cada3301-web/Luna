#!/bin/bash
# Собирает загрузочный ISO из rootfs (вызывает build-rootfs.sh)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROOTFS="$ROOT/work/rootfs"
ISODIR="$ROOT/work/isodir"
ISO="$ROOT/out/luna-0.1.0.iso"

"$ROOT/build/build-rootfs.sh"

echo "==> Собираем ISO: $ISO"

rm -rf "$ISODIR"
mkdir -p "$ISODIR/boot/syslinux" "$ROOT/out"

cp "$ROOTFS/boot/vmlinuz-virt" "$ISODIR/boot/"
cp "$ROOTFS/boot/initramfs-virt" "$ISODIR/boot/"

cp /usr/share/syslinux/isolinux.bin "$ISODIR/boot/syslinux/"
cp /usr/share/syslinux/ldlinux.c32 "$ISODIR/boot/syslinux/"

cat > "$ISODIR/boot/syslinux/syslinux.cfg" <<'EOF'
TIMEOUT 30
DEFAULT luna

LABEL luna
  KERNEL /boot/vmlinuz-virt
  INITRD /boot/initramfs-virt
  APPEND quiet modules=loop,squashfs,sd-mod,usb-storage
EOF

xorriso -as mkisofs \
    -o "$ISO" \
    -b boot/syslinux/isolinux.bin \
    -c boot/syslinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -J -R -l "$ISODIR"

echo "==> ISO готов: $ISO ($(du -h "$ISO" | cut -f1))"
