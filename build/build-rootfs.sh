#!/bin/bash
# Собирает rootfs — корневую файловую систему Luna.
# Результат: work/rootfs/ (нужен build-iso.sh для упаковки в ISO)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROOTFS="$ROOT/work/rootfs"

echo "==> Создаём rootfs в $ROOTFS"

rm -rf "$ROOTFS"
mkdir -p "$ROOTFS/etc/apk/keys"

# Ключи и репозитории — без них apk выдаст UNTRUSTED signature
cp -a /etc/apk/keys/. "$ROOTFS/etc/apk/keys/"
cp /etc/apk/repositories "$ROOTFS/etc/apk/repositories"

# Инициализация базы пакетов внутри будущей ОС
apk add --root "$ROOTFS" --initdb --repositories-file /etc/apk/repositories

# Базовые пакеты: скелет системы, init, login, ядро
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

# Дополнительные пакеты из packages.txt
if [ -f "$ROOT/build/packages.txt" ]; then
    grep -v '^#' "$ROOT/build/packages.txt" | grep -v '^[[:space:]]*$' | while read -r pkg; do
        echo "    + $pkg"
        apk add --root "$ROOTFS" --repositories-file /etc/apk/repositories "$pkg"
    done
fi

# Брендинг Luna: hostname, motd, issue, luna-release
cp -a "$ROOT/overlay/." "$ROOTFS/"

# Настройка внутри будущей ОС
chroot "$ROOTFS" /bin/sh <<'CHROOT'
setup-timezone -i UTC

rc-update add devfs sysinit
rc-update add dmesg sysinit
rc-update add mdev sysinit
rc-update add hwdrivers sysinit
rc-update add modloop sysinit
rc-update add sysctl sysinit
rc-update add hostname boot
rc-update add bootmisc boot
rc-update add syslog boot
rc-update add mount-ro shutdown
rc-update add killprocs shutdown
rc-update add savecache shutdown

if [ -f /etc/init.d/agetty ]; then
    rc-update add agetty default
fi
CHROOT

KV="$(ls "$ROOTFS/lib/modules")"
echo "==> Генерируем initramfs для ядра $KV"
mkinitfs -b "$ROOTFS" -k "$KV"

echo "==> Rootfs готов: $ROOTFS"
