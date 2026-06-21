#!/bin/bash
# Fetch latest Luna userspace from GitHub Releases and apply to /.
# Called by: luna upgrade, luna self-update

set -euo pipefail

LUNA_SHARE="${LUNA_SHARE:-/usr/share/luna}"

# shellcheck disable=SC1091
. "$LUNA_SHARE/luna-apk-repo.sh"

load_release() {
	if [ -r /etc/luna-release ]; then
		# shellcheck disable=SC1091
		. /etc/luna-release
	fi
}

load_github_config() {
	LUNA_GITHUB_REPO="${LUNA_GITHUB_REPO:-c1cada3301-web/Luna}"
	if [ -r /etc/luna/github.conf ]; then
		# shellcheck disable=SC1091
		. /etc/luna/github.conf
	fi
}

version_lt() {
	# true if $1 < $2 (X.Y.Z, no sort -V — BusyBox-safe)
	local IFS=.
	local i a b av bv
	read -r -a a <<< "$1"
	read -r -a b <<< "$2"
	for i in 0 1 2; do
		av="${a[$i]:-0}"
		bv="${b[$i]:-0}"
		case "$av" in
			*[!0-9]*) av=0 ;;
		esac
		case "$bv" in
			*[!0-9]*) bv=0 ;;
		esac
		if [ "$av" -lt "$bv" ]; then return 0; fi
		if [ "$av" -gt "$bv" ]; then return 1; fi
	done
	return 1
}

strip_v() {
	printf '%s' "$1" | sed 's/^v//'
}

github_curl() {
	local url="$1"
	local max_time="${2:-60}"
	load_release
	curl -fsSL --connect-timeout 15 --max-time "$max_time" \
		-H "User-Agent: Luna/${LUNA_VERSION:-unknown}" \
		-H "Accept: application/vnd.github+json" \
		"$url"
}

github_download() {
	local url="$1" out="$2"
	load_release
	curl -fsSL --connect-timeout 15 --max-time 300 \
		-H "User-Agent: Luna/${LUNA_VERSION:-unknown}" \
		-o "$out" "$url"
}

# GitHub returns minified single-line JSON; grep+ cut breaks on "url" vs "tag_name".
json_field() {
	local key="$1" json="$2"
	printf '%s' "$json" | sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" | head -1
}

json_asset_download_url() {
	local json="$1" want="$2"
	printf '%s' "$json" | grep -o "\"browser_download_url\":\"[^\"]*${want}\"" | head -1 | cut -d'"' -f4
}

github_latest_tag() {
	local api="https://api.github.com/repos/${LUNA_GITHUB_REPO}/releases/latest"
	local json tag

	if ! json="$(github_curl "$api" 2>/dev/null)"; then
		echo "failed to fetch $api" >&2
		return 1
	fi

	tag="$(json_field tag_name "$json")"
	[ -n "$tag" ] || { echo "no tag_name in release JSON" >&2; return 1; }
	printf '%s' "$tag"
}

github_userspace_url() {
	local tag="$1"
	local ver api json url want

	ver="$(strip_v "$tag")"
	want="luna-${ver}-userspace.tar.gz"
	api="https://api.github.com/repos/${LUNA_GITHUB_REPO}/releases/tags/${tag}"

	if ! json="$(github_curl "$api" 2>/dev/null)"; then
		echo "failed to fetch release $tag" >&2
		return 1
	fi

	url="$(json_asset_download_url "$json" "$want")"
	[ -n "$url" ] || {
		echo "release $tag has no asset $want (need Luna 0.8.1+)" >&2
		return 1
	}
	printf '%s' "$url"
}

github_apk_repo_url() {
	local tag="$1"
	local ver api json url want

	ver="$(strip_v "$tag")"
	want="luna-${ver}-apk-repo.tar.gz"
	api="https://api.github.com/repos/${LUNA_GITHUB_REPO}/releases/tags/${tag}"

	if ! json="$(github_curl "$api" 2>/dev/null)"; then
		echo "failed to fetch release $tag" >&2
		return 1
	fi

	url="$(json_asset_download_url "$json" "$want")"
	[ -n "$url" ] || return 1
	printf '%s' "$url"
}

installed_luna_ver() {
	local ver
	load_release
	if ver="$(luna_base_pkg_version 2>/dev/null)" && luna_version_valid "$ver"; then
		printf '%s' "$ver"
		return 0
	fi
	if luna_version_valid "${LUNA_VERSION:-}"; then
		printf '%s' "$LUNA_VERSION"
		return 0
	fi
	printf '%s' "${LUNA_VERSION:-0.0.0}"
}

apply_luna_base_apk() {
	local url="$1" tmpdir

	if ! command -v apk >/dev/null 2>&1; then
		echo "apk not found" >&2
		return 1
	fi

	tmpdir="$(mktemp -d)"
	trap "rm -rf '$tmpdir'" RETURN

	printf '  downloading %s\n' "$(basename "$url")"
	github_download "$url" "$tmpdir/apk-repo.tar.gz"

	extract_luna_apk_repo "$tmpdir/apk-repo.tar.gz" || {
		echo "failed to extract apk-repo tarball" >&2
		return 1
	}

	printf '  upgrading luna-base (local apk repo)\n'
	upgrade_luna_base_from_repo

	trap - RETURN
	rm -rf "$tmpdir"
}

apply_userspace() {
	local url="$1" tmpdir archive luna_mode

	luna_mode="$(grep '^LUNA_MODE=' /etc/luna-release 2>/dev/null | cut -d= -f2 || true)"

	tmpdir="$(mktemp -d)"
	trap "rm -rf '$tmpdir'" RETURN
	archive="$tmpdir/userspace.tar.gz"

	printf '  downloading %s\n' "$(basename "$url")"
	github_download "$url" "$archive"

	printf '  extracting to /\n'
	tar -xzf "$archive" -C /
	preserve_luna_installed_mode "$luna_mode"
	luna_base_fix_permissions
	trap - RETURN
	rm -rf "$tmpdir"
}

# Returns 0 if an update was applied, 1 if already current, 2 on skip/error.
luna_self_update() {
	local current latest latest_ver tag url

	if [ "$(id -u)" -ne 0 ]; then
		echo "luna self-update requires root" >&2
		return 2
	fi
	if ! command -v curl >/dev/null 2>&1; then
		printf '  skip: curl not installed — run: apk add curl\n\n' >&2
		return 2
	fi
	if [ ! -f /etc/ssl/certs/ca-certificates.crt ]; then
		printf '  skip: ca-certificates missing — run: apk add ca-certificates\n\n' >&2
		return 2
	fi

	load_release
	load_github_config
	current="$(installed_luna_ver)"

	printf 'Checking Luna release (GitHub: %s)...\n' "$LUNA_GITHUB_REPO"

	if ! tag="$(github_latest_tag)"; then
		printf '  skip: could not reach GitHub — Alpine upgrade only\n\n'
		return 2
	fi

	latest_ver="$(strip_v "$tag")"
	printf '  current:  %s\n' "$current"
	printf '  latest:   %s (%s)\n' "$latest_ver" "$tag"

	if [ "$current" = "$latest_ver" ]; then
		printf '  Luna:     already up to date\n\n'
		return 1
	fi

	if version_lt "$latest_ver" "$current"; then
		printf '  Luna:     local %s is newer than release %s — skip\n\n' "$current" "$latest_ver"
		return 1
	fi

	printf '\nUpdating Luna %s → %s\n' "$current" "$latest_ver"

	if url="$(github_apk_repo_url "$tag" 2>/dev/null)" && [ -n "$url" ]; then
		if apply_luna_base_apk "$url"; then
			printf '  Luna:     updated to %s (luna-base apk)\n\n' "$latest_ver"
			return 0
		fi
		printf '  note:     luna-base apk failed — trying legacy userspace bundle (deprecated)\n'
	fi

	if ! url="$(github_userspace_url "$tag")"; then
		printf '  skip: no userspace bundle on %s — Alpine upgrade only\n\n' "$tag"
		return 2
	fi

	apply_userspace "$url"
	printf '  Luna:     updated to %s (userspace tar.gz)\n\n' "$latest_ver"
	return 0
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	luna_self_update
	exit $?
fi
