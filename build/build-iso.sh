#!/bin/bash
# Собирает загрузочный ISO из rootfs.
# LUNA_ARCH: x86_64 → syslinux (BIOS) | aarch64 → GRUB (UEFI)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LUNA_ARCH="${LUNA_ARCH:-x86_64}"
LUNA_VERSION="$(grep '^LUNA_VERSION=' "$ROOT/overlay/etc/luna-release" | cut -d= -f2)"
WORKDIR="$ROOT/work/${LUNA_ARCH}"
ROOTFS="$WORKDIR/rootfs"
ISODIR="$WORKDIR/isodir"
ISO="$ROOT/out/luna-${LUNA_VERSION}-${LUNA_ARCH}.iso"
REPO_KEY="$ROOT/build/keys/luna-repo.rsa"

prepare_alpine_iso_tree() {
    local apk_arch modloop_staging kernel_cmdline apks_dir

    apk_arch="$(chroot "$ROOTFS" apk --print-arch)"
    apks_dir="$ISODIR/apks/$apk_arch"

    echo "==> Создаём modloop-virt"
    modloop_staging="$WORKDIR/modloop-staging"
    rm -rf "$modloop_staging"
    mkdir -p "$modloop_staging"
    cp -a "$ROOTFS/lib/modules" "$modloop_staging/modules"
    mksquashfs "$modloop_staging" "$ISODIR/boot/modloop-virt" \
        -comp xz -b 131072 -noappend

    echo "==> Скачиваем APK-пакеты ($apk_arch)"
    mkdir -p "$apks_dir"
    touch "$ISODIR/apks/.boot_repository"
    apk fetch --root "$ROOTFS" -R \
        --repositories-file /etc/apk/repositories \
        -o "$apks_dir" \
        $(apk info --root "$ROOTFS" -q | sort -u)

    echo "==> Создаём и подписываем APKINDEX.tar.gz"
    rm -f "$apks_dir/APKINDEX.tar.gz"
    (cd "$apks_dir" && apk index -o APKINDEX.tar.gz ./*.apk)
    if [ ! -f "$REPO_KEY" ]; then
        echo "ERROR: ключ $REPO_KEY не найден"
        exit 1
    fi
    abuild-sign -k "$REPO_KEY" -p luna@local.rsa.pub "$apks_dir/APKINDEX.tar.gz"

    echo "==> Создаём localhost.apkovl.tar.gz (авто-находится initramfs)"
    apkovl_dir="$WORKDIR/apkovl"
    rm -rf "$apkovl_dir"
    mkdir -p "$apkovl_dir/root" "$apkovl_dir/home/luna"
    chmod 700 "$apkovl_dir/root"
    chown 1000:1000 "$apkovl_dir/home/luna" 2>/dev/null || true
    cp -a "$ROOTFS/etc" "$apkovl_dir/"
    if [ -d "$ROOTFS/usr/local" ]; then
        mkdir -p "$apkovl_dir/usr"
        cp -a "$ROOTFS/usr/local" "$apkovl_dir/usr/"
    fi
    if [ -d "$ROOTFS/usr/share/luna" ]; then
        mkdir -p "$apkovl_dir/usr/share"
        cp -a "$ROOTFS/usr/share/luna" "$apkovl_dir/usr/share/"
    fi
    if [ -d "$ROOTFS/home/luna" ]; then
        cp -a "$ROOTFS/home/luna/." "$apkovl_dir/home/luna/" 2>/dev/null || true
    fi
    # Не копируем online-репозитории: при наличии сети в VM apk тянет
    # чужой индекс и падает с "package mentioned in index not found".
    rm -f "$apkovl_dir/etc/apk/repositories"
    tar -C "$apkovl_dir" -czf "$ISODIR/localhost.apkovl.tar.gz" etc root home usr

    if [ -f "$ROOTFS/etc/alpine-release" ]; then
        cp "$ROOTFS/etc/alpine-release" "$ISODIR/.alpine-release"
    fi

    case "$LUNA_ARCH" in
        aarch64)
            kernel_cmdline="modules=loop,squashfs,sd-mod,usb-storage,iso9660,sr-mod,virtio_net,virtio_pci,virtio_mmio quiet console=tty0 modloop=none ip=off"
            ;;
        x86_64)
            kernel_cmdline="modules=loop,squashfs,sd-mod,usb-storage,iso9660,sr-mod,virtio_net,virtio_pci quiet console=tty0 console=ttyS0,115200 modloop=none ip=off"
            ;;
    esac

    export LUNA_KERNEL_CMDLINE="$kernel_cmdline"
}

"$ROOT/build/build-rootfs.sh"

echo "==> Собираем ISO ($LUNA_ARCH): $ISO"

rm -rf "$ISODIR"
mkdir -p "$ISODIR/boot" "$ROOT/out"

cp "$ROOTFS/boot/vmlinuz-virt" "$ISODIR/boot/"
cp "$ROOTFS/boot/initramfs-virt" "$ISODIR/boot/"

prepare_alpine_iso_tree

case "$LUNA_ARCH" in
    x86_64)
        mkdir -p "$ISODIR/boot/syslinux"
        cp /usr/share/syslinux/isolinux.bin "$ISODIR/boot/syslinux/"
        cp /usr/share/syslinux/ldlinux.c32 "$ISODIR/boot/syslinux/"

        cat > "$ISODIR/boot/syslinux/syslinux.cfg" <<EOF
TIMEOUT 30
DEFAULT luna

LABEL luna
  KERNEL /boot/vmlinuz-virt
  INITRD /boot/initramfs-virt
  APPEND ${LUNA_KERNEL_CMDLINE}
EOF

        xorriso -as mkisofs \
            -o "$ISO" \
            -b boot/syslinux/isolinux.bin \
            -c boot/syslinux/boot.cat \
            -no-emul-boot -boot-load-size 4 -boot-info-table \
            -J -R -l "$ISODIR"
        ;;
    aarch64)
        mkdir -p "$ISODIR/boot/grub" "$ISODIR/EFI/BOOT"

        cat > "$ISODIR/boot/grub/grub.cfg" <<EOF
set timeout=3
menuentry "Luna" {
  linux /boot/vmlinuz-virt ${LUNA_KERNEL_CMDLINE}
  initrd /boot/initramfs-virt
}
EOF

        grub-mkimage \
            -o "$ISODIR/EFI/BOOT/BOOTAA64.EFI" \
            -O arm64-efi \
            -p /boot/grub \
            iso9660 part_gpt part_msdos normal linux echo all_video fat ext2 configfile

        EFIIMG="$WORKDIR/efiboot.img"
        rm -f "$EFIIMG"
        dd if=/dev/zero of="$EFIIMG" bs=1M count=4 status=none
        mkfs.vfat -F 12 -n EFI "$EFIIMG"
        mmd -i "$EFIIMG" ::EFI ::EFI/BOOT
        mcopy -i "$EFIIMG" "$ISODIR/EFI/BOOT/BOOTAA64.EFI" ::EFI/BOOT/BOOTAA64.EFI

        xorriso -as mkisofs \
            -o "$ISO" \
            -R -J -l \
            -eltorito-alt-boot \
            -e efiboot.img \
            -no-emul-boot \
            -isohybrid-gpt-basdat \
            -V LUNA \
            -graft-points \
                "/=$ISODIR" \
                "/efiboot.img=$EFIIMG"
        ;;
    *)
        echo "Неизвестная архитектура: $LUNA_ARCH"
        exit 1
        ;;
esac

if [ "$LUNA_ARCH" = "x86_64" ]; then
    cp "$ISO" "$ROOT/out/luna-${LUNA_VERSION}.iso"
fi

echo "==> ISO готов: $ISO ($(du -h "$ISO" | cut -f1))"
