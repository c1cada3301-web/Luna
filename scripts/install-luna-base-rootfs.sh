#!/usr/bin/env bash
# Build luna-base apk repo and install Luna files into staging rootfs.
# Live ISO must NOT register luna-base in apk world — setup-alpine runs apk add
# (setup-keymap) before disk install and fails on world[luna-base] without CDN.
#
# Usage: ./scripts/install-luna-base-rootfs.sh <rootfs> <workdir>

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROOTFS="${1:?rootfs path}"
WORKDIR="${2:?workdir}"

# shellcheck source=scripts/overlay-infra.sh
. "$ROOT/scripts/overlay-infra.sh"

LUNA_VERSION="$(grep '^LUNA_VERSION=' "$ROOT/overlay/etc/luna-release" | cut -d= -f2)"

[ -f "$ROOT/build/keys/luna-repo.rsa" ] || {
	echo "install-luna-base-rootfs: missing build/keys/luna-repo.rsa" >&2
	exit 1
}

extract_luna_base_apk() {
	local apk="$1" dest="$2" tmp="$3"
	local item base

	rm -rf "$tmp"
	mkdir -p "$tmp" "$dest"
	tar xzf "$apk" -C "$tmp"
	if [ -f "$tmp/data.tar.gz" ]; then
		tar xzf "$tmp/data.tar.gz" -C "$dest"
	elif [ -f "$tmp/data.tar.zst" ]; then
		tar --zstd -xf "$tmp/data.tar.zst" -C "$dest"
	elif [ -d "$tmp/usr" ] || [ -d "$tmp/etc" ]; then
		# APK v3 — payload at archive root (etc/, usr/, …)
		for item in "$tmp"/* "$tmp"/.[!.]*; do
			[ -e "$item" ] || continue
			base="$(basename "$item")"
			case "$base" in
				.PKGINFO|.SIGN.*|CONTROL|dep|hashf) continue ;;
			esac
			cp -a "$item" "$dest/"
		done
	else
		echo "install-luna-base-rootfs: unknown apk layout in $apk" >&2
		ls -la "$tmp" >&2
		return 1
	fi
	rm -rf "$tmp"
}

apk_out="$WORKDIR/luna-apk-out"
repo_root="$WORKDIR/luna-apk-repo-mount"

mkdir -p "$apk_out" "$repo_root" "$ROOTFS/usr/share/luna/apk-repo"
"$ROOT/scripts/build-apk-repo.sh" "$apk_out"
tar xzf "$apk_out/luna-${LUNA_VERSION}-apk-repo.tar.gz" -C "$repo_root"
cp -a "$repo_root/." "$ROOTFS/usr/share/luna/apk-repo/"

APK="$(find "$repo_root/noarch" -maxdepth 1 -name 'luna-base-*.apk' -print -quit 2>/dev/null || true)"
[ -n "$APK" ] || {
	echo "install-luna-base-rootfs: luna-base apk missing under $repo_root/noarch" >&2
	exit 1
}

echo "==> Installing luna-base ${LUNA_VERSION} into rootfs (extract — not apk world)"
extract_luna_base_apk "$APK" "$ROOTFS" "$WORKDIR/apk-extract"

apply_overlay_infra "$ROOTFS" "$ROOT/overlay"

if apk info --root "$ROOTFS" -e luna-base >/dev/null 2>&1; then
	echo "install-luna-base-rootfs: luna-base must not be in apk db on live rootfs" >&2
	exit 1
fi
if grep -q '^luna-base' "$ROOTFS/etc/apk/world" "$ROOTFS/var/lib/apk/world" 2>/dev/null; then
	echo "install-luna-base-rootfs: luna-base must not be in apk world on live rootfs" >&2
	exit 1
fi
[ -x "$ROOTFS/usr/bin/luna" ] || {
	echo "install-luna-base-rootfs: /usr/bin/luna missing after extract" >&2
	exit 1
}

rm -f "$ROOTFS/usr/local/bin/luna" "$ROOTFS/usr/local/bin/luna-help" 2>/dev/null || true
chmod +x "$ROOTFS"/usr/bin/luna "$ROOTFS"/usr/bin/luna-help 2>/dev/null || true
chmod +x "$ROOTFS"/usr/share/luna/*.sh 2>/dev/null || true
