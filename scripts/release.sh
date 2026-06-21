#!/usr/bin/env bash
# Tag + push → GitHub Actions builds ISOs and publishes Release.
# Usage: ./scripts/release.sh [--push]

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PUSH=false
if [ "${1:-}" = "--push" ]; then
	PUSH=true
fi

VERSION="$(grep '^LUNA_VERSION=' overlay/etc/luna-release | cut -d= -f2)"
TAG="v${VERSION}"

if ! grep -q "## \\[${VERSION}\\]" CHANGELOG.md; then
	echo "ERROR: CHANGELOG.md has no section [${VERSION}]" >&2
	exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
	echo "ERROR: working tree not clean — commit first" >&2
	git status -sb
	exit 1
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
	echo "Tag $TAG already exists locally"
else
	git tag -a "$TAG" -m "Luna ${VERSION}"
	echo "Created tag $TAG"
fi

echo ""
echo "Version:  $VERSION"
echo "Tag:      $TAG"
echo "Changelog section OK"
echo ""
echo "Next:"
echo "  1. Ensure GitHub secret LUNA_REPO_RSA (base64 of build/keys/luna-repo.rsa)"
echo "  2. git push origin main"
echo "  3. git push origin $TAG   # triggers .github/workflows/release.yml"
echo ""
echo "Or local ISO + manual release:"
echo "  docker compose run --rm luna-build-aarch64"
echo "  docker compose run --rm luna-build-x86_64"
echo "  gh release create $TAG out/luna-${VERSION}-*.iso --title \"Luna ${VERSION}\" --notes-file <(awk ... CHANGELOG.md)"

if $PUSH; then
	git push origin main
	git push origin "$TAG"
	echo "Pushed $TAG — watch Actions: https://github.com/$(gh repo view --json nameWithOwner -q .nameWithOwner)/actions"
fi
