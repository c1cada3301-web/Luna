#!/bin/bash
# Собирает rootfs — корневую файловую систему Luna.
# LUNA_ARCH: x86_64 (default) | aarch64

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LUNA_ARCH="${LUNA_ARCH:-x86_64}"
WORKDIR="$ROOT/work/${LUNA_ARCH}"
ROOTFS="$WORKDIR/rootfs"

echo "==> Создаём rootfs ($LUNA_ARCH) в $ROOTFS"

rm -rf "$ROOTFS"
mkdir -p "$ROOTFS/etc/apk/keys"

cp -a /etc/apk/keys/. "$ROOTFS/etc/apk/keys/"
cp /etc/apk/repositories "$ROOTFS/etc/apk/repositories"

apk add --root "$ROOTFS" --initdb --repositories-file /etc/apk/repositories

apk add --root "$ROOTFS" --repositories-file /etc/apk/repositories \
    alpine-base \
    alpine-conf \
    alpine-release \
    busybox-openrc \
    openrc \
    agetty \
    linux-virt \
    mkinitfs \
    tzdata

if [ -f "$ROOT/build/packages.txt" ]; then
    grep -v '^#' "$ROOT/build/packages.txt" | grep -v '^[[:space:]]*$' | while read -r pkg; do
        echo "    + $pkg"
        apk add --root "$ROOTFS" --repositories-file /etc/apk/repositories "$pkg"
    done
fi

cp -a "$ROOT/overlay/." "$ROOTFS/"
chmod +x "$ROOTFS"/etc/local.d/*.start 2>/dev/null || true

configure_inittab() {
    # Только tty1 — serial-консоли добавит initramfs (setup_inittab_console),
    # если устройство реально доступно (stty), без спама в VirtualBox.
    cat > "$ROOTFS/etc/inittab" <<'EOF'
# /etc/inittab — Luna (OpenRC + agetty)

::sysinit:/sbin/openrc sysinit
::sysinit:/sbin/openrc boot
::wait:/sbin/openrc default

tty1::respawn:/sbin/agetty --noclear 38400 tty1 linux

::ctrlaltdel:/sbin/reboot
::shutdown:/sbin/openrc shutdown
EOF
}

configure_inittab

chroot "$ROOTFS" /bin/sh <<'CHROOT'
setup-timezone -i UTC
passwd -d root >/dev/null 2>&1 || true

# Пользователь luna + sudo (wheel)
addgroup -g 1000 wheel 2>/dev/null || true
if ! id luna >/dev/null 2>&1; then
	adduser -D -u 1000 -G wheel -h /home/luna -s /bin/bash luna
fi
passwd -d luna >/dev/null 2>&1 || true
chown luna:wheel /home/luna 2>/dev/null || true
install -d -m 750 /etc/sudoers.d
echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

rc-update add devfs sysinit
rc-update add dmesg sysinit
rc-update add mdev sysinit
rc-update add hwdrivers sysinit
rc-update add sysctl sysinit
rc-update add hostname boot
rc-update add networking boot
rc-update add bootmisc boot
rc-update add syslog boot
rc-update add local boot
rc-update add sshd default
rc-update add mount-ro shutdown
rc-update add killprocs shutdown
rc-update add savecache shutdown
CHROOT

KV="$(ls "$ROOTFS/lib/modules")"
echo "==> Генерируем initramfs для ядра $KV"
mkinitfs -b "$ROOTFS" -k "$KV"

echo "==> Rootfs готов: $ROOTFS"
