#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ISO="$ROOT/out/luna-0.1.0.iso"

if [ ! -f "$ISO" ]; then
    echo "ISO не найден: $ISO"
    echo "Сначала: docker compose run --rm luna-build"
    exit 1
fi

echo "Загружаем $ISO в QEMU (Ctrl+A, затем X — выход)"

qemu-system-x86_64 \
    -machine q35 \
    -cpu qemu64 \
    -m 1024 \
    -cdrom "$ISO" \
    -boot d \
    -serial stdio \
    -display none
