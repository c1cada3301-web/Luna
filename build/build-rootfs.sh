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
chmod +x "$ROOTFS"/etc/init.d/luna-agent 2>/dev/null || true
chmod +x "$ROOTFS"/usr/local/bin/* 2>/dev/null || true
chmod +x "$ROOTFS"/usr/share/luna/*.sh 2>/dev/null || true

# busybox mdev: @ надёжнее */path (иначе «persistent-storage: not found» при coldplug)
sed -i 's|\*/lib/mdev/persistent-storage|@/lib/mdev/persistent-storage|g' \
	"$ROOTFS/etc/mdev.conf"

# Luna: initramfs только с ISO — без CDN даже если в VM есть сеть
INIT="$ROOTFS/usr/share/mkinitfs/initramfs-init"
awk '
/^apkflags="--initramfs-diskless-boot --progress"$/ {
	print "apkflags=\"--initramfs-diskless-boot --progress --no-network\""
	skip = 1
	next
}
skip && /^if \[ -z "\$MAC_ADDRESS" \]; then$/ { skip = 2; next }
skip == 2 { if (/^fi$/) skip = 0; next }
{ print }
' "$INIT" > "$INIT.luna" && mv "$INIT.luna" "$INIT"

configure_inittab() {
    # Только tty1 — serial-консоли добавит initramfs (setup_inittab_console),
    # если устройство реально доступно (stty), без спама в VirtualBox.
    cat > "$ROOTFS/etc/inittab" <<'EOF'
# /etc/inittab — Luna (OpenRC + agetty)

::sysinit:/sbin/openrc sysinit
::sysinit:/sbin/openrc boot
::wait:/sbin/openrc default

tty1::respawn:/sbin/agetty 38400 tty1 linux

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

# bash + Luna prompt для root и luna
sed -i 's|^root:.*|root:x:0:0:root:/root:/bin/bash|' /etc/passwd
if [ -f /etc/skel/.bashrc ]; then
	cp /etc/skel/.bashrc /root/.bashrc
	cp /etc/skel/.bashrc /home/luna/.bashrc
	chown luna:wheel /home/luna/.bashrc
fi

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

# SSH host keys — иначе sshd при первом boot может долго «висеть» до login
ssh-keygen -A 2>/dev/null || true
CHROOT

KV="$(ls "$ROOTFS/lib/modules")"
echo "==> Генерируем initramfs для ядра $KV"
# -k в mkinitfs = «keep tempdir», не версия ядра; -i = наш пропатченный init
mkinitfs -b "$ROOTFS" -i "$ROOTFS/usr/share/mkinitfs/initramfs-init" "$KV"

echo "==> Rootfs готов: $ROOTFS"
