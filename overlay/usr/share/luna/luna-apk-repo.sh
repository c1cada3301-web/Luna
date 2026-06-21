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

sync_luna_release_version() {
	local ver
	ver="$(apk info -e luna-base 2>/dev/null | sed 's/^luna-base-//; s/-r[0-9]*$//')"
	[ -n "$ver" ] || return 0
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

# Install or upgrade luna-base from local file repo. Returns 0 on success.
upgrade_luna_base_from_repo() {
	local mode apk_file

	mode="$(grep '^LUNA_MODE=' /etc/luna-release 2>/dev/null | cut -d= -f2 || true)"
	luna_apk_repo_present || return 1
	ensure_luna_apk_repo_in_repositories || return 1

	apk update || return 1

	if apk upgrade --force-overwrite luna-base; then
		luna_base_post_install "$mode"
		return 0
	fi

	apk_file="$(luna_base_apk_file)"
	[ -n "$apk_file" ] || return 1

	printf '  note:     apk upgrade failed — installing %s directly\n' "$(basename "$apk_file")"
	if apk add --force-overwrite --allow-untrusted "$apk_file"; then
		luna_base_post_install "$mode"
		printf '  note:     luna-base installed with --allow-untrusted (fix apk keys)\n' >&2
		return 0
	fi

	return 1
}
