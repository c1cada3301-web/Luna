#!/bin/sh
# Overlay paths NOT shipped in luna-base — ISO rootfs / disk install only.

apply_overlay_infra() {
	local dest="$1"
	local overlay="$2"
	local rel src dst

	for rel in \
		etc/network/interfaces \
		etc/hostname \
		etc/ssh/sshd_config.d/luna.conf \
		etc/skel/.bashrc
	do
		src="$overlay/$rel"
		[ -e "$src" ] || continue
		dst="$dest/$rel"
		install -D -m644 "$src" "$dst"
	done

	if [ -d "$overlay/etc/apk/keys" ]; then
		mkdir -p "$dest/etc/apk/keys"
		cp -a "$overlay/etc/apk/keys/." "$dest/etc/apk/keys/"
	fi
}

apply_overlay_userspace_fallback() {
	local dest="$1"
	local overlay="$2"

	cp -a "$overlay/." "$dest/"
	chmod +x "$dest"/etc/local.d/*.start 2>/dev/null || true
	chmod +x "$dest"/etc/init.d/luna-agent 2>/dev/null || true
	chmod +x "$dest"/usr/local/bin/* 2>/dev/null || true
	chmod +x "$dest"/usr/share/luna/*.sh 2>/dev/null || true
}
