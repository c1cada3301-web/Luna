#!/usr/bin/env bash
# Build ISOs locally and publish GitHub Release (without CI).
# Usage: ./scripts/release-local.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

command -v gh >/dev/null 2>&1 || { echo "gh CLI required"; exit 1; }

VERSION="$(grep '^LUNA_VERSION=' overlay/etc/luna-release | cut -d= -f2)"
TAG="v${VERSION}"

grep -q "## \\[${VERSION}\\]" CHANGELOG.md || {
	echo "CHANGELOG missing [$VERSION]"
	exit 1
}

[ -f build/keys/luna-repo.rsa ] || {
	echo "Missing build/keys/luna-repo.rsa — see README"
	exit 1
}

echo "==> Building aarch64"
docker compose run --rm luna-build-aarch64

echo "==> Building x86_64"
docker compose run --rm luna-build-x86_64

ISO_A="out/luna-${VERSION}-aarch64.iso"
ISO_X="out/luna-${VERSION}-x86_64.iso"
for f in "$ISO_A" "$ISO_X"; do
	[ -f "$f" ] || { echo "Missing $f"; exit 1; }
done

NOTES="$(mktemp)"
awk -v ver="$VERSION" '
	$0 ~ "^## \\[" ver "\\]" { show=1; next }
	show && /^## \[/ { exit }
	show { print }
' CHANGELOG.md > "$NOTES"

CHECKSUMS="$(mktemp)"
(cd out && sha256sum "luna-${VERSION}"-*.iso > "$CHECKSUMS")

if git rev-parse "$TAG" >/dev/null 2>&1; then
	echo "Tag $TAG exists"
else
	git tag -a "$TAG" -m "Luna ${VERSION}"
fi

if gh release view "$TAG" >/dev/null 2>&1; then
	echo "Release $TAG exists — uploading assets"
	gh release upload "$TAG" "$ISO_A" "$ISO_X" "$CHECKSUMS" --clobber
else
	gh release create "$TAG" "$ISO_A" "$ISO_X" "$CHECKSUMS" \
		--title "Luna ${VERSION}" \
		--notes-file "$NOTES" \
		--latest
fi

rm -f "$NOTES" "$CHECKSUMS"
echo "==> https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/releases/tag/${TAG}"
