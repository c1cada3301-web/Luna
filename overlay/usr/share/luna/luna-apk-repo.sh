#!/bin/sh
# Luna local apk repo — file:// /var/lib/luna/apk-repo (noarch luna-base).
# Sourced by: luna, luna-self-update.sh, setup-apkrepos.start

LUNA_APK_REPO_ROOT="${LUNA_APK_REPO_ROOT:-/var/lib/luna/apk-repo}"
LUNA_APK_REPO_BUNDLED="${LUNA_APK_REPO_BUNDLED:-/usr/share/luna/apk-repo}"

luna_apk_repo_line() {
	printf '%s' "$LUNA_APK_REPO_ROOT"
}

luna_apk_repo_present() {
	[ -f "$LUNA_APK_REPO_ROOT/noarch/APKINDEX.tar.gz" ] && \
		find "$LUNA_APK_REPO_ROOT/noarch" -maxdepth 1 -name 'luna-base-*.apk' -print -quit 2>/dev/null | grep -q .
}

luna_apk_repo_bundled_present() {
	[ -f "$LUNA_APK_REPO_BUNDLED/noarch/APKINDEX.tar.gz" ] && \
		find "$LUNA_APK_REPO_BUNDLED/noarch" -maxdepth 1 -name 'luna-base-*.apk' -print -quit 2>/dev/null | grep -q .
}

ensure_luna_apk_repo_in_repositories() {
	local line
	line="$(luna_apk_repo_line)"
	luna_apk_repo_present || return 1
	if grep -qxF "$line" /etc/apk/repositories 2>/dev/null; then
		return 0
	fi
	printf '%s\n' "$line" >> /etc/apk/repositories
}

ensure_bundled_luna_apk_repo_in_repositories() {
	luna_apk_repo_bundled_present || return 1
	if grep -qxF "$LUNA_APK_REPO_BUNDLED" /etc/apk/repositories 2>/dev/null; then
		return 0
	fi
	printf '%s\n' "$LUNA_APK_REPO_BUNDLED" >> /etc/apk/repositories
}

strip_luna_base_from_world() {
	local w
	for w in /etc/apk/world /var/lib/apk/world; do
		[ -f "$w" ] || continue
		sed -i '/^luna-base/d' "$w"
	done
}

luna_base_in_world() {
	grep -q '^luna-base' /etc/apk/world /var/lib/apk/world 2>/dev/null
}

# Live ISO: local repo + indexes before any setup-alpine apk add.
ensure_luna_apk_repos_live() {
	if ! luna_apk_repo_present 2>/dev/null; then
		install_bundled_luna_apk_repo 2>/dev/null || true
	fi
	ensure_luna_apk_repo_in_repositories 2>/dev/null || true
	ensure_bundled_luna_apk_repo_in_repositories 2>/dev/null || true
	apk update || return 1
	return 0
}

prepare_live_for_setup_alpine() {
	ensure_luna_apk_repos_live || die "apk update failed — check /etc/apk/repositories"
	strip_luna_base_from_world
	luna_base_in_world && die "luna-base still in apk world — use Luna 0.9.8+ live ISO"
}

extract_luna_apk_repo() {
	local tarball="$1"
	[ -n "$tarball" ] && [ -f "$tarball" ] || return 1
	mkdir -p "$LUNA_APK_REPO_ROOT"
	rm -rf "${LUNA_APK_REPO_ROOT:?}"/*
	tar xzf "$tarball" -C "$LUNA_APK_REPO_ROOT"
}

install_bundled_luna_apk_repo() {
	luna_apk_repo_bundled_present || return 1
	mkdir -p "$LUNA_APK_REPO_ROOT"
	rm -rf "${LUNA_APK_REPO_ROOT:?}"/*
	cp -a "$LUNA_APK_REPO_BUNDLED/." "$LUNA_APK_REPO_ROOT/"
}

luna_base_apk_file() {
	find "$LUNA_APK_REPO_ROOT/noarch" -maxdepth 1 -name 'luna-base-*.apk' -print -quit 2>/dev/null
}

luna_base_installed() {
	apk info -e luna-base >/dev/null 2>&1
}

luna_base_pkg_version() {
	local pkg
	luna_base_installed || return 1
	pkg="$(apk info luna-base 2>/dev/null | head -1)"
	case "$pkg" in
		luna-base-*-r[0-9]*) ;;
		*) return 1 ;;
	esac
	printf '%s' "$pkg" | sed 's/^luna-base-//; s/-r[0-9]*$//'
}

luna_version_valid() {
	case "$1" in
		*.*.*) return 0 ;;
		*) return 1 ;;
	esac
}

sync_luna_release_version() {
	local ver
	ver="$(luna_base_pkg_version)" || return 0
	luna_version_valid "$ver" || return 0
	if [ -f /etc/luna-release ] && grep -q '^LUNA_VERSION=' /etc/luna-release; then
		sed -i "s/^LUNA_VERSION=.*/LUNA_VERSION=${ver}/" /etc/luna-release
	fi
}

preserve_luna_installed_mode() {
	local mode="$1"
	if [ "$mode" = "installed" ]; then
		if grep -q '^LUNA_MODE=' /etc/luna-release 2>/dev/null; then
			sed -i 's/^LUNA_MODE=.*/LUNA_MODE=installed/' /etc/luna-release
		else
			printf '\nLUNA_MODE=installed\n' >> /etc/luna-release
		fi
	fi
}

remove_tarball_luna_bins() {
	rm -f /usr/local/bin/luna /usr/local/bin/luna-help 2>/dev/null || true
}

luna_base_fix_permissions() {
	remove_tarball_luna_bins
	chmod +x /usr/bin/luna /usr/bin/luna-help 2>/dev/null || true
	chmod +x /usr/share/luna/*.sh 2>/dev/null || true
	chmod +x /etc/local.d/*.start 2>/dev/null || true
	chmod +x /etc/init.d/luna-agent 2>/dev/null || true
}

luna_base_post_install() {
	local mode="${1:-}"
	sync_luna_release_version
	preserve_luna_installed_mode "$mode"
	luna_base_fix_permissions
}

_luna_reload_apks_repo() {
	# apk install replaces scripts on disk — refresh functions in this shell
	# shellcheck disable=SC1091
	. "${LUNA_SHARE:-/usr/share/luna}/luna-apk-repo.sh"
}

# Install or upgrade luna-base from local file repo. Returns 0 on success.
upgrade_luna_base_from_repo() {
	local mode apk_file

	mode="$(grep '^LUNA_MODE=' /etc/luna-release 2>/dev/null | cut -d= -f2 || true)"
	luna_apk_repo_present || return 1
	ensure_luna_apk_repo_in_repositories || return 1

	apk update || return 1

	if apk upgrade --force-overwrite luna-base; then
		_luna_reload_apks_repo
		luna_base_post_install "$mode"
		return 0
	fi

	apk_file="$(luna_base_apk_file)"
	[ -n "$apk_file" ] || return 1

	printf '  note:     apk upgrade failed — installing %s directly\n' "$(basename "$apk_file")"
	if apk add --force-overwrite --allow-untrusted "$apk_file"; then
		_luna_reload_apks_repo
		luna_base_post_install "$mode"
		printf '  note:     luna-base installed with --allow-untrusted (fix apk keys)\n' >&2
		return 0
	fi

	return 1
}
