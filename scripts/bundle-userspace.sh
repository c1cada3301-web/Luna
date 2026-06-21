#!/usr/bin/env bash
# Build luna-VERSION-userspace.tar.gz for GitHub Releases (installed-system updates).
# Usage: ./scripts/bundle-userspace.sh [out-dir]

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="$(grep '^LUNA_VERSION=' overlay/etc/luna-release | cut -d= -f2)"
OUT_DIR="${1:-out}"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

# Same paths as install_luna_overlay (except etc/network/interfaces — user config).
PATHS=(
	usr/local/bin/luna
	usr/local/bin/luna-help
	usr/share/luna
	etc/profile.d/luna-prompt.sh
	etc/profile.d/luna-locale.sh
	etc/init.d/luna-agent
	etc/local.d/network-dhcp.start
	etc/local.d/setup-apkrepos.start
	etc/local.d/mount-persist.start
	etc/luna/locale.conf
	etc/luna-release
	etc/motd
	etc/issue
)

for rel in "${PATHS[@]}"; do
	src="overlay/$rel"
	[ -e "$src" ] || { echo "Missing overlay/$rel" >&2; exit 1; }
	dst="$STAGING/$rel"
	if [ -d "$src" ]; then
		mkdir -p "$dst"
		cp -a "$src/." "$dst/"
	else
		mkdir -p "$(dirname "$dst")"
		cp -a "$src" "$dst"
	fi
done

chmod +x "$STAGING"/usr/local/bin/* 2>/dev/null || true
chmod +x "$STAGING"/usr/share/luna/*.sh 2>/dev/null || true
chmod +x "$STAGING"/etc/local.d/*.start 2>/dev/null || true
chmod +x "$STAGING"/etc/init.d/luna-agent 2>/dev/null || true

mkdir -p "$OUT_DIR"
ARCHIVE="$OUT_DIR/luna-${VERSION}-userspace.tar.gz"
tar -C "$STAGING" -czf "$ARCHIVE" "${PATHS[@]}"
echo "$ARCHIVE ($(du -h "$ARCHIVE" | awk '{print $1}'))"
