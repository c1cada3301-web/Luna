#!/usr/bin/env bash
# E2E: live ISO → luna install → reboot from disk (QEMU aarch64)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="${1:-aarch64}"
LUNA_VERSION="$(grep '^LUNA_VERSION=' "$ROOT/overlay/etc/luna-release" | cut -d= -f2)"
ISO="$ROOT/out/luna-${LUNA_VERSION}-${ARCH}.iso"
DISK="$ROOT/out/luna-test-disk.qcow2"
LOG="$ROOT/out/test-install.log"
PASS_ROOT="lunatest-root"
PASS_LUNA="lunatest-luna"

[ -f "$ISO" ] || { echo "ISO missing: $ISO — run: docker compose run --rm luna-build-aarch64"; exit 1; }
[ "$ARCH" = "aarch64" ] || { echo "Only aarch64 supported for now"; exit 1; }

EFI=""
for candidate in \
	/opt/homebrew/share/qemu/edk2-aarch64-code.fd \
	/usr/local/share/qemu/edk2-aarch64-code.fd; do
	[ -f "$candidate" ] && EFI="$candidate" && break
done
[ -n "$EFI" ] || { echo "UEFI firmware not found (brew install qemu)"; exit 1; }

qemu-img create -f qcow2 "$DISK" 8G >/dev/null

export ISO DISK LOG PASS_ROOT PASS_LUNA EFI

echo "==> Phase 1: live boot + luna install"
echo "    ISO:  $ISO"
echo "    Disk: $DISK"
echo "    Log:  $LOG"
: > "$LOG"

/usr/bin/expect -f - <<'EXPECT' | tee -a "$LOG"
set timeout 900
log_user 1

set iso $env(ISO)
set disk $env(DISK)
set pass_root $env(PASS_ROOT)
set pass_luna $env(PASS_LUNA)
set efi $env(EFI)

spawn qemu-system-aarch64 -M virt -cpu max -m 2048 -smp 2 -accel hvf \
	-bios $efi -cdrom $iso \
	-drive if=none,file=$disk,format=qcow2,id=hd0 \
	-device virtio-blk-device,drive=hd0 \
	-netdev user,id=net0,hostfwd=tcp::2223-:22 \
	-device virtio-net-device,netdev=net0 \
	-nographic

expect {
	timeout { puts "\nFAIL: boot timeout"; exit 1 }
	"login:" { send "root\r" }
}

expect {
	timeout { puts "\nFAIL: shell timeout"; exit 1 }
	-re "# |\\$ " {}
}

send "luna version\r"
expect -re "Luna 0\\.6\\.[0-9]+"

send "lsblk -dpno NAME,TYPE | grep disk\r"
expect -re "vda"

send "export LUNA_INSTALL_DISK=/dev/vda LUNA_INSTALL_HOSTNAME=luna-test LUNA_INSTALL_ROOT_PASS=$pass_root LUNA_INSTALL_LUNA_PASS=$pass_luna\r"
send "bash /usr/share/luna/luna-install.sh\r"

expect {
	timeout { puts "\nFAIL: install timeout (15 min)"; exit 1 }
	"Installation complete" {}
}

send "poweroff\r"
expect eof
EXPECT

echo ""
echo "==> Phase 2: boot from disk (no ISO)"

/usr/bin/expect -f - <<'EXPECT2' | tee -a "$LOG"
set timeout 300
set disk $env(DISK)
set pass_luna $env(PASS_LUNA)
set efi $env(EFI)

spawn qemu-system-aarch64 -M virt -cpu max -m 2048 -smp 2 -accel hvf \
	-bios $efi \
	-drive if=none,file=$disk,format=qcow2,id=hd0 \
	-device virtio-blk-device,drive=hd0 \
	-netdev user,id=net0 \
	-device virtio-net-device,netdev=net0 \
	-nographic

expect {
	timeout { puts "\nFAIL: disk boot timeout"; exit 1 }
	"login:" { send "luna\r" }
}

expect "Password:"
send "$pass_luna\r"

expect {
	timeout { puts "\nFAIL: login timeout"; exit 1 }
	-re "# |\\$ " {}
}

send "luna status\r"
expect {
	timeout { puts "\nFAIL: luna status timeout"; exit 1 }
	"installed (disk)" { puts "\nOK: boot mode = installed (disk)" }
	"live (ISO)" { puts "\nFAIL: still live"; exit 1 }
}

send "luna version\r"
expect -re "Luna 0\\.6\\.[0-9]+"

send "poweroff\r"
expect eof
EXPECT2

echo ""
echo "==> E2E install test PASSED"
