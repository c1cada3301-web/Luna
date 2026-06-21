#!/bin/bash
# Тест ISO в QEMU.
# Использование: ./scripts/test-qemu.sh [x86_64|aarch64]

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="${1:-}"

if [ -z "$ARCH" ]; then
    case "$(uname -m)" in
        arm64|aarch64) ARCH=aarch64 ;;
        *) ARCH=x86_64 ;;
    esac
fi

ISO="$ROOT/out/luna-0.1.0-${ARCH}.iso"

if [ ! -f "$ISO" ]; then
    echo "ISO не найден: $ISO"
    echo "Собери: docker compose run --rm luna-build-${ARCH}"
    exit 1
fi

echo "Загружаем $ISO в QEMU ($ARCH)"
echo "Выход: Ctrl+A, затем X"

case "$ARCH" in
    x86_64)
        qemu-system-x86_64 \
            -machine q35 \
            -cpu qemu64 \
            -m 1024 \
            -cdrom "$ISO" \
            -boot d \
            -serial stdio \
            -display none
        ;;
    aarch64)
        EFI=""
        for candidate in \
            /opt/homebrew/share/qemu/edk2-aarch64-code.fd \
            /usr/local/share/qemu/edk2-aarch64-code.fd \
            /opt/homebrew/share/edk2-aarch64-code.fd; do
            if [ -f "$candidate" ]; then
                EFI="$candidate"
                break
            fi
        done

        if [ -z "$EFI" ]; then
            echo "Не найден UEFI firmware для QEMU (edk2-aarch64-code.fd)."
            echo "Установи: brew install qemu"
            exit 1
        fi

        qemu-system-aarch64 \
            -M virt \
            -cpu cortex-a72 \
            -m 1024 \
            -bios "$EFI" \
            -cdrom "$ISO" \
            -device virtio-gpu-pci \
            -device virtio-keyboard-device \
            -device virtio-tablet-device \
            -display cocoa
        ;;
    *)
        echo "Неизвестная архитектура: $ARCH"
        exit 1
        ;;
esac
