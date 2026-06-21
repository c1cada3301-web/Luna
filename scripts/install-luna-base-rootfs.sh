#!/usr/bin/env bash
# Build luna-base apk repo and install into a staging rootfs via apk.
# Usage: ./scripts/install-luna-base-rootfs.sh <rootfs> <workdir>

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROOTFS="${1:?rootfs path}"
WORKDIR="${2:?workdir}"

# shellcheck source=scripts/overlay-infra.sh
. "$ROOT/scripts/overlay-infra.sh"

LUNA_VERSION="$(grep '^LUNA_VERSION=' "$ROOT/overlay/etc/luna-release" | cut -d= -f2)"
ALPINE_VER="$(grep '^LUNA_BASE=' "$ROOT/overlay/etc/luna-release" | cut -d= -f2 | tr -d '"' | awk '{print $2}')"
ALPINE_VER="${ALPINE_VER:-3.20}"

[ -f "$ROOT/build/keys/luna-repo.rsa" ] || {
	echo "install-luna-base-rootfs: missing build/keys/luna-repo.rsa" >&2
	exit 1
}

apk_out="$WORKDIR/luna-apk-out"
repo_root="$WORKDIR/luna-apk-repo-mount"
repos_file="$WORKDIR/luna-staging.repos"

mkdir -p "$apk_out" "$repo_root" "$ROOTFS/usr/share/luna/apk-repo"
"$ROOT/scripts/build-apk-repo.sh" "$apk_out"
tar xzf "$apk_out/luna-${LUNA_VERSION}-apk-repo.tar.gz" -C "$repo_root"
cp -a "$repo_root/." "$ROOTFS/usr/share/luna/apk-repo/"

apply_overlay_infra "$ROOTFS" "$ROOT/overlay"

cat > "$repos_file" <<EOF
https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VER}/main
https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VER}/community
${repo_root}
EOF

echo "==> Installing luna-base ${LUNA_VERSION} into rootfs (apk)"
apk add --root "$ROOTFS" --repositories-file "$repos_file" --force-overwrite luna-base

# Files stay on rootfs; drop from world so live setup-alpine does not require luna-base from CDN.
sed -i '/^luna-base$/d' "$ROOTFS/etc/apk/world" 2>/dev/null || true

rm -f "$ROOTFS/usr/local/bin/luna" "$ROOTFS/usr/local/bin/luna-help" 2>/dev/null || true
chmod +x "$ROOTFS"/usr/bin/luna "$ROOTFS"/usr/bin/luna-help 2>/dev/null || true
chmod +x "$ROOTFS"/usr/share/luna/*.sh 2>/dev/null || true
