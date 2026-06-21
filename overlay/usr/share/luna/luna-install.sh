#!/bin/bash
# Luna disk installer — TUI wrapper around setup-alpine (phase 5.1)

set -euo pipefail

LUNA_SHARE="${LUNA_SHARE:-/usr/share/luna}"
SYSROOT="/mnt"
STATE_FILE="/tmp/luna-install.state"
ANSWER_FILE="/tmp/luna-install.answers"

die() {
	printf 'luna install: %s\n' "$1" >&2
	exit 1
}

heading() {
	printf '\n🌙 %s\n' "$1"
	printf '%s\n' "$(printf '%.0s─' {1..50})"
}

is_live() {
	local fstype
	fstype="$(findmnt -no FSTYPE / 2>/dev/null || true)"
	case "$fstype" in
		tmpfs|overlay|aufs) return 0 ;;
	esac
	grep -qE ' / (tmpfs|overlay) ' /proc/mounts 2>/dev/null && return 0
	grep -q modloop /proc/mounts 2>/dev/null && return 0
	return 1
}

has_network() {
	ip -4 -o addr show scope global 2>/dev/null | grep -q inet && return 0
	return 1
}

ensure_install_tools() {
	if command -v lsblk >/dev/null 2>&1 && command -v blkid >/dev/null 2>&1; then
		return 0
	fi
	has_network || die "need util-linux (lsblk) — no network for apk add"
	printf 'Installing util-linux (lsblk, blkid)...\n'
	apk add --quiet util-linux || die "apk add util-linux failed"
}

_disk_size() {
	local dev="$1"
	local sysfs="/sys/block/${dev#/dev/}/size"
	if [ -r "$sysfs" ]; then
		awk '{ printf "%.1fG", ($1 * 512) / (1024 * 1024 * 1024) }' "$sysfs"
	else
		lsblk -dno SIZE "$dev" 2>/dev/null || echo "?"
	fi
}

_disk_model() {
	local dev="$1"
	local sysfs="/sys/block/${dev#/dev/}/device/model"
	local model=""
	if [ -r "$sysfs" ]; then
		model="$(tr -d ' \n' < "$sysfs" 2>/dev/null || true)"
	fi
	if [ -z "$model" ]; then
		model="$(lsblk -dno MODEL "$dev" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)"
	fi
	[ -n "$model" ] && printf '%s' "$model" || printf 'disk'
}

list_block_disks() {
	local dev name
	if command -v lsblk >/dev/null 2>&1; then
		lsblk -dpno NAME,TYPE 2>/dev/null | awk '$2=="disk" {print $1}'
		return
	fi
	for dev in /sys/block/*; do
		name="/dev/$(basename "$dev")"
		case "$name" in
			/dev/loop*|/dev/ram*|/dev/sr*|/dev/nbd*) continue ;;
		esac
		[ -f "$dev/size" ] && printf '%s\n' "$name"
	done
}

list_disk_partitions() {
	local disk="$1" base="${disk#/dev/}" part
	if command -v lsblk >/dev/null 2>&1; then
		lsblk -rno NAME,TYPE "$disk" 2>/dev/null | awk '$2=="part" {print "/dev/"$1}'
		return
	fi
	for part in "/sys/block/$base"/"${base}"*; do
		[ -d "$part" ] || continue
		printf '/dev/%s\n' "$(basename "$part")"
	done
}

part_fstype() {
	local part="$1" fstype=""
	if command -v blkid >/dev/null 2>&1; then
		fstype="$(blkid -o value -s TYPE "$part" 2>/dev/null || true)"
		[ -n "$fstype" ] && { printf '%s' "$fstype"; return 0; }
	fi
	if dumpe2fs "$part" 2>/dev/null | head -1 | grep -qi ext; then
		printf 'ext4'
		return 0
	fi
	return 1
}

list_disks() {
	local name size model
	while IFS= read -r name; do
		[ -n "$name" ] || continue
		case "$name" in
			/dev/sr*|/dev/loop*|/dev/nbd*) continue ;;
		esac
		size="$(_disk_size "$name")"
		model="$(_disk_model "$name")"
		printf '%s\t%s\t%s\n' "$name" "$size" "$model"
	done < <(list_block_disks)
}

read_password() {
	local prompt="$1" pass pass2
	while true; do
		read -r -s -p "$prompt: " pass
		printf '\n'
		[ -n "$pass" ] || { echo "Password cannot be empty."; continue; }
		read -r -s -p "Confirm: " pass2
		printf '\n'
		[ "$pass" = "$pass2" ] || { echo "Passwords do not match."; continue; }
		printf '%s' "$pass"
		return 0
	done
}

pick_disk() {
	local -a entries=() line name size model
	while IFS=$'\t' read -r name size model; do
		entries+=("$name ($size — $model)")
	done < <(list_disks)

	if [ "${#entries[@]}" -eq 0 ]; then
		printf '\nVisible block devices (/sys/block):\n' >&2
		ls -1 /sys/block/ 2>/dev/null | sed 's/^/  /' >&2 || true
		die "no installable disks — VirtualBox: Settings → Storage → Controller SATA → Add disk (≥8 GB), then reboot VM"
	fi

	heading "Select target disk"
	printf 'All data on the chosen disk will be erased.\n\n'
	PS3="Disk: "
	select _ in "${entries[@]}" "Abort"; do
		case "$REPLY" in
			''|*[!0-9]*) echo "Invalid option"; continue ;;
		esac
		if [ "$REPLY" -eq $((${#entries[@]} + 1)) ]; then
			echo "Aborted."
			exit 0
		fi
		if [ "$REPLY" -ge 1 ] && [ "$REPLY" -le "${#entries[@]}" ]; then
			SELECTED_DISK="${entries[$((REPLY - 1))]%% *}"
			return 0
		fi
	done
}

confirm_install() {
	local disk="$1" hostname="$2"
	local kernel="${LUNA_INSTALL_KERNEL:-lts}"
	heading "Confirm installation"
	printf '  Disk:     %s\n' "$disk"
	printf '  Hostname: %s\n' "$hostname"
	printf '  Kernel:   linux-%s (disk) · live ISO stays virt\n' "$kernel"
	printf '  Mode:     sys (full disk, ext4, GRUB on EFI)\n'
	printf '  Users:    root, luna (passwords required after install)\n\n'
	read -r -p "Proceed? This erases ${disk}. [y/N] " ans
	case "$ans" in
		y|Y|yes|Yes|YES) return 0 ;;
		*) echo "Aborted."; exit 0 ;;
	esac
}

prepare_setup_alpine() {
	local repo_sh="${LUNA_SHARE:-/usr/share/luna}/luna-apk-repo.sh"
	[ -r "$repo_sh" ] || die "missing $repo_sh (broken luna-base package)"
	# shellcheck disable=SC1091
	. "$repo_sh"
	prepare_live_for_setup_alpine
}

apk_repos_for_install() {
	local alpine_ver repos
	# shellcheck disable=SC1091
	. /etc/os-release 2>/dev/null || true
	alpine_ver="${VERSION_ID%.*}"
	alpine_ver="${alpine_ver:-3.20}"
	repos="https://dl-cdn.alpinelinux.org/alpine/v${alpine_ver}/main"
	repos="${repos} https://dl-cdn.alpinelinux.org/alpine/v${alpine_ver}/community"
	repos="${repos} /var/lib/luna/apk-repo"
	if [ -d /usr/share/luna/apk-repo/noarch ]; then
		repos="${repos} /usr/share/luna/apk-repo"
	fi
	printf '%s' "$repos"
}

write_answer_file() {
	local disk="$1" hostname="$2"
	local kernel="${LUNA_INSTALL_KERNEL:-lts}"
	local apk_repos
	apk_repos="$(apk_repos_for_install)"

	cat > "$ANSWER_FILE" <<EOF
# Luna install answer file — generated by luna install
KEYMAPOPTS=none
HOSTNAMEOPTS=${hostname}
DEVDOPTS=mdev
INTERFACESOPTS="auto lo
iface lo inet loopback

iface eth0 inet dhcp
iface enp0s3 inet dhcp
iface end0 inet dhcp
hostname ${hostname}
"
TIMEZONEOPTS=UTC
PROXYOPTS=none
APKREPOSOPTS="${apk_repos}"
USEROPTS="-a -u -g wheel luna"
SSHDOPTS=openssh
NTPOPTS=none
DISKOPTS="-k ${kernel} -m sys ${disk}"
LBUOPTS=none
APKCACHEOPTS=none
EOF
}

find_root_partition() {
	local disk="$1" part fstype
	while IFS= read -r part; do
		fstype="$(part_fstype "$part" || true)"
		case "$fstype" in
			ext4|ext3|xfs|btrfs) printf '%s' "$part"; return 0 ;;
		esac
	done < <(list_disk_partitions "$disk")
	return 1
}

find_esp_partition() {
	local disk="$1" part fstype
	while IFS= read -r part; do
		fstype="$(part_fstype "$part" || true)"
		[ "$fstype" = "vfat" ] && { printf '%s' "$part"; return 0; }
	done < <(list_disk_partitions "$disk")
	return 1
}

mount_sysroot() {
	local disk="$1" root_part esp_part
	root_part="$(find_root_partition "$disk")" || die "could not find root partition on $disk"
	mkdir -p "$SYSROOT"
	mount "$root_part" "$SYSROOT"
	esp_part="$(find_esp_partition "$disk" || true)"
	if [ -n "$esp_part" ]; then
		mkdir -p "$SYSROOT/boot/efi"
		mount "$esp_part" "$SYSROOT/boot/efi" 2>/dev/null || true
	fi
	for d in dev proc sys; do
		mount --bind "/$d" "$SYSROOT/$d"
	done
}

umount_sysroot() {
	for d in sys proc dev; do
		umount "$SYSROOT/$d" 2>/dev/null || true
	done
	umount "$SYSROOT/boot/efi" 2>/dev/null || true
	umount "$SYSROOT" 2>/dev/null || true
}

verify_sys_install() {
	local disk="$1"

	find_root_partition "$disk" >/dev/null || die "no root partition on $disk after setup-alpine"
	mount_sysroot "$disk"
	if [ ! -e "$SYSROOT/sbin/init" ]; then
		umount_sysroot
		die "setup-alpine did not install a bootable system (/sbin/init missing on disk). Keep live ISO attached — do not reboot."
	fi
	umount_sysroot
}

install_luna_apk_repo_bundle() {
	if [ ! -d /usr/share/luna/apk-repo/noarch ]; then
		return 1
	fi
	mkdir -p "$SYSROOT/var/lib/luna/apk-repo"
	cp -a /usr/share/luna/apk-repo/. "$SYSROOT/var/lib/luna/apk-repo/"
}

# setup-alpine/lbu не включает /usr/local — legacy fallback без bundled apk-repo
install_luna_overlay() {
	local src dst rel
	for rel in \
		usr/local/bin/luna \
		usr/local/bin/luna-help \
		usr/share/luna \
		etc/profile.d/luna-prompt.sh \
		etc/profile.d/luna-locale.sh \
		etc/init.d/luna-agent \
		etc/local.d/network-dhcp.start \
		etc/local.d/setup-apkrepos.start \
		etc/local.d/mount-persist.start \
		etc/luna/locale.conf \
		etc/luna-release \
		etc/motd \
		etc/issue \
		etc/network/interfaces
	do
		src="/$rel"
		[ -e "$src" ] || continue
		dst="$SYSROOT/$rel"
		if [ -d "$src" ]; then
			mkdir -p "$(dirname "$dst")"
			cp -a "$src/." "$dst/"
		else
			install -D -m "$(stat -c '%a' "$src" 2>/dev/null || echo 644)" "$src" "$dst"
		fi
	done
	chmod +x "$SYSROOT"/usr/local/bin/* 2>/dev/null || true
	chmod +x "$SYSROOT"/usr/share/luna/*.sh 2>/dev/null || true
	chmod +x "$SYSROOT"/etc/local.d/*.start 2>/dev/null || true
	chmod +x "$SYSROOT"/etc/init.d/luna-agent 2>/dev/null || true
}

install_luna_to_sysroot() {
	install_luna_apk_repo_bundle || true

	if [ -f /etc/network/interfaces ]; then
		install -D -m644 /etc/network/interfaces "$SYSROOT/etc/network/interfaces"
	fi

	if [ -d "$SYSROOT/var/lib/luna/apk-repo/noarch" ]; then
		return 0
	fi

	install_luna_overlay
}

post_install() {
	local disk="$1" hostname="$2" root_pass="$3" luna_pass="$4"
	local root_part

	[ -n "$root_pass" ] || die "root password is empty"
	[ -n "$luna_pass" ] || die "luna password is empty"

	heading "Finalizing Luna on disk"
	root_part="$(find_root_partition "$disk")" || die "root partition missing after install"

	mount_sysroot "$disk"
	install_luna_to_sysroot

	# Пароли через файлы — heredoc ломает $, :, \ в паролях
	printf '%s' "$root_pass" > "$SYSROOT/tmp/.luna-pass-root"
	printf '%s' "$luna_pass" > "$SYSROOT/tmp/.luna-pass-luna"
	printf '%s' "$hostname" > "$SYSROOT/tmp/.luna-hostname"
	chmod 600 "$SYSROOT/tmp/.luna-pass-root" "$SYSROOT/tmp/.luna-pass-luna"

	chroot "$SYSROOT" /bin/sh <<'CHROOT'
set -eu
root_pw=$(cat /tmp/.luna-pass-root)
luna_pw=$(cat /tmp/.luna-pass-luna)
host=$(cat /tmp/.luna-hostname)
rm -f /tmp/.luna-pass-root /tmp/.luna-pass-luna /tmp/.luna-hostname

printf '%s:%s\n' root "$root_pw" | chpasswd
if ! id luna >/dev/null 2>&1; then
	addgroup -g 1000 wheel 2>/dev/null || true
	adduser -D -u 1000 -G wheel -h /home/luna -s /bin/bash luna
fi
printf '%s:%s\n' luna "$luna_pw" | chpasswd
unset root_pw luna_pw
sed -i 's|^root:.*|root:x:0:0:root:/root:/bin/bash|' /etc/passwd 2>/dev/null || true
sed -i 's|^luna:.*|luna:x:1000:1000:luna:/home/luna:/bin/bash|' /etc/passwd 2>/dev/null || true

install -d -m 750 /etc/sudoers.d
echo '%wheel ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

rm -f /etc/ssh/sshd_config.d/luna.conf
cat > /etc/ssh/sshd_config.d/luna-installed.conf <<'SSHD'
# Luna installed system — no empty passwords
PasswordAuthentication yes
PermitEmptyPasswords no
SSHD

. /etc/os-release 2>/dev/null || VERSION_ID=3.20
ver="\${VERSION_ID%.*}"
cat > /etc/apk/repositories <<REPOS
https://dl-cdn.alpinelinux.org/alpine/v\${ver}/main
https://dl-cdn.alpinelinux.org/alpine/v\${ver}/community
REPOS

if ls /var/lib/luna/apk-repo/noarch/luna-base-*.apk >/dev/null 2>&1; then
	grep -qxF /var/lib/luna/apk-repo /etc/apk/repositories 2>/dev/null || \
		echo /var/lib/luna/apk-repo >> /etc/apk/repositories
	apk update
	if apk add --force-overwrite luna-base 2>/dev/null; then
		:
	elif apk add --force-overwrite --allow-untrusted /var/lib/luna/apk-repo/noarch/luna-base-*.apk; then
		:
	fi
	rm -f /usr/local/bin/luna /usr/local/bin/luna-help
fi

if [ -f /etc/luna-release ]; then
	grep -q '^LUNA_MODE=' /etc/luna-release && \
		sed -i 's/^LUNA_MODE=.*/LUNA_MODE=installed/' /etc/luna-release || \
		echo 'LUNA_MODE=installed' >> /etc/luna-release
fi

chmod +x /etc/local.d/*.start 2>/dev/null || true
chmod +x /etc/init.d/luna-agent 2>/dev/null || true
chmod +x /usr/bin/luna /usr/bin/luna-help 2>/dev/null || true
chmod +x /usr/share/luna/*.sh 2>/dev/null || true

rc-update add sshd default 2>/dev/null || true
rc-update add local boot 2>/dev/null || true
rc-update add networking boot 2>/dev/null || true

hostname "$host"

# Bare-metal extras (linux-firmware, …)
if [ -f /usr/share/luna/packages-install.txt ]; then
	_pkgs=""
	while read -r _p; do
		case "$_p" in ''|\#*) continue ;; esac
		_pkgs="$_pkgs $_p"
	done < /usr/share/luna/packages-install.txt
	if [ -n "$_pkgs" ]; then
		apk add --no-cache $_pkgs
	fi
fi
CHROOT

	umount_sysroot

	printf '\n'
	printf '🌙 Installation complete.\n'
	printf '  Remove live ISO, reboot, then login as luna or root (passwords you set).\n'
	printf '  Verify: luna status · ssh · apk add\n\n'
}

run_install() {
	local disk="$1" hostname="$2" root_pass="$3" luna_pass="$4"

	prepare_setup_alpine
	write_answer_file "$disk" "$hostname"

	{
		echo "DISK=$disk"
		echo "HOSTNAME=$hostname"
	} > "$STATE_FILE"

	heading "Running setup-alpine"
	setup-alpine -f "$ANSWER_FILE" -e || die "setup-alpine failed — disk may be unusable; keep live ISO attached"

	verify_sys_install "$disk"
	post_install "$disk" "$hostname" "$root_pass" "$luna_pass"
}

preflight() {
	[ "$(id -u)" -eq 0 ] || die "must run as root (sudo luna install)"
	is_live || die "already running from disk — use live ISO to install Luna"
	command -v setup-alpine >/dev/null 2>&1 || die "setup-alpine not found (alpine-conf)"
	if ! has_network; then
		echo "Waiting for network (DHCP)..."
		local i=0
		while [ "$i" -lt 30 ]; do
			has_network && break
			sleep 2
			i=$((i + 1))
		done
		has_network || die "no network — check VirtualBox NAT and reboot live session"
	fi
	ensure_install_tools
	if [ -r "$LUNA_SHARE/luna-apk-repo.sh" ]; then
		# shellcheck disable=SC1091
		. "$LUNA_SHARE/luna-apk-repo.sh"
		strip_luna_base_from_world 2>/dev/null || true
	fi
}

main() {
	local disk hostname root_pass luna_pass default_host

	preflight

	# Non-interactive (CI/QEMU): LUNA_INSTALL_DISK + passwords
	if [ -n "${LUNA_INSTALL_DISK:-}" ]; then
		disk="$LUNA_INSTALL_DISK"
		hostname="${LUNA_INSTALL_HOSTNAME:-luna}"
		root_pass="${LUNA_INSTALL_ROOT_PASS:?set LUNA_INSTALL_ROOT_PASS}"
		luna_pass="${LUNA_INSTALL_LUNA_PASS:?set LUNA_INSTALL_LUNA_PASS}"
		[ -b "$disk" ] || die "disk not found: $disk"
		run_install "$disk" "$hostname" "$root_pass" "$luna_pass"
		return
	fi

	heading "Luna install"
	printf 'Install Luna to a virtual or physical disk from live ISO.\n'
	printf 'Tip: VirtualBox → Settings → Storage → add SATA disk (≥8 GB).\n'

	pick_disk
	disk="$SELECTED_DISK"

	default_host="$(hostname 2>/dev/null || echo luna)"
	read -r -p "Hostname [$default_host]: " hostname
	hostname="${hostname:-$default_host}"

	root_pass="$(read_password "Root password")"
	luna_pass="$(read_password "luna user password")"

	confirm_install "$disk" "$hostname"

	run_install "$disk" "$hostname" "$root_pass" "$luna_pass"
}

main "$@"
