#!/usr/bin/env bash
# Build signed luna-base APK repo tarball for GitHub Releases.
# Usage: ./scripts/build-apk-repo.sh [out-dir]
#
# Layout (extract to /var/lib/luna/apk-repo):
#   noarch/APKINDEX.tar.gz + luna-base-*.apk
#   aarch64/APKINDEX.tar.gz  (empty stub for aarch64 hosts)
#   x86_64/APKINDEX.tar.gz   (empty stub for x86_64 hosts)
#
# /etc/apk/repositories: /var/lib/luna/apk-repo

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION="$(grep '^LUNA_VERSION=' overlay/etc/luna-release | cut -d= -f2)"
ALPINE_VER="$(grep '^LUNA_BASE=' overlay/etc/luna-release | cut -d= -f2 | tr -d '"' | awk '{print $2}')"
ALPINE_VER="${ALPINE_VER:-3.20}"

OUT_DIR="${1:-$ROOT/out}"
case "$OUT_DIR" in
	/*) ;;
	*) OUT_DIR="$ROOT/$OUT_DIR" ;;
esac
KEY="$ROOT/build/keys/luna-repo.rsa"
PUB="$ROOT/overlay/etc/apk/keys/luna@local.rsa.pub"
PUB_NAME="luna@local.rsa.pub"
PKG_SRC="$ROOT/packages/luna-base"
BUILD_DIR="$ROOT/work/apk-build"
PKGDEST_ROOT="$ROOT/work/apk-pkg"
STAGING_ROOT="$ROOT/work/apk-repo-staging"
STAGING_NOARCH="$STAGING_ROOT/noarch"

die() {
	echo "build-apk-repo: $*" >&2
	exit 1
}

[ -f "$KEY" ] || die "missing $KEY — see README (abuild-keygen)"
[ -f "$PUB" ] || die "missing $PUB"
[ -f "$PKG_SRC/APKBUILD" ] || die "missing $PKG_SRC/APKBUILD"

export PACKAGER_PRIVKEY="$KEY"
export OVERLAY_ROOT="$ROOT/overlay"
export CARCH=noarch

install -m644 "$PUB" "${KEY}.pub"
mkdir -p /etc/apk/keys
install -m644 "$PUB" "/etc/apk/keys/$PUB_NAME"

rm -rf "$BUILD_DIR" "$PKGDEST_ROOT" "$STAGING_ROOT"
mkdir -p "$BUILD_DIR" "$PKGDEST_ROOT" "$STAGING_NOARCH"

export REPODEST="$PKGDEST_ROOT"
export PKGDEST="$PKGDEST_ROOT"

sed "s/^pkgver=.*/pkgver=$VERSION/" "$PKG_SRC/APKBUILD" > "$BUILD_DIR/APKBUILD"

echo "==> Building luna-base $VERSION (Alpine v$ALPINE_VER, noarch)"
cd "$BUILD_DIR"
set +e
abuild -F
set -e

APK="$(find "$PKGDEST_ROOT" -name "luna-base-${VERSION}-r*.apk" -print -quit 2>/dev/null || true)"
[ -n "$APK" ] || die "luna-base apk not found under $PKGDEST_ROOT"

cp -a "$APK" "$STAGING_NOARCH/"
cd "$STAGING_NOARCH"
apk index --allow-untrusted -o APKINDEX.tar.gz ./*.apk
abuild-sign -k "$KEY" -p "$PUB_NAME" APKINDEX.tar.gz

# apk on $ARCH hosts requires $ARCH/APKINDEX.tar.gz even for noarch-only repos
for arch in aarch64 x86_64; do
	mkdir -p "$STAGING_ROOT/$arch"
	cd "$STAGING_ROOT/$arch"
	apk index -o APKINDEX.tar.gz
	abuild-sign -k "$KEY" -p "$PUB_NAME" APKINDEX.tar.gz
done

mkdir -p "$OUT_DIR"
ARCHIVE="$OUT_DIR/luna-${VERSION}-apk-repo.tar.gz"
tar -C "$STAGING_ROOT" -czf "$ARCHIVE" noarch aarch64 x86_64

echo "==> $ARCHIVE ($(du -h "$ARCHIVE" | awk '{print $1}'))"
ls -laR "$STAGING_ROOT"
