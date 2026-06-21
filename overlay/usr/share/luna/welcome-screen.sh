#!/bin/sh
# Luna Shell welcome (Claude-style card) — plain text, no tput (SSH-safe)

load_release() {
	if [ -r /etc/luna-release ]; then
		# shellcheck disable=SC1091
		. /etc/luna-release
	fi
}

_agent_line() {
	if rc-service luna-agent status 2>/dev/null | grep -q started; then
		echo "agent running (stub)"
	else
		echo "agent stopped (stub)"
	fi
}

load_release
ver="${LUNA_VERSION:-?}"
base="${LUNA_BASE:-Alpine 3.20}"
user="$(id -un 2>/dev/null || echo luna)"
host="$(hostname 2>/dev/null || echo luna)"
pwd_short="${PWD:-~}"
pwd_short="${pwd_short/#$HOME/\~}"
agent="$(_agent_line)"
identity="${user}@${host}"

printf '\n'
printf '%s\n' '┌──────────────────────────────────────────────────────────────────────┐'
printf '%s\n' '│                                                                      │'
printf '%s\n' '│  Welcome to Luna                                                     │'
printf '%s\n' '│                                                                      │'
printf '%s\n' '│  🌙              Tips for getting started                              │'
printf '│  Luna %-7s • luna status   — network, memory, services        │\n' "$ver"
printf '│  %-18s • luna help     — all commands                     │\n' "$identity"
printf '│  %-18s • mc            — files (TUI)                        │\n' "$pwd_short"
printf '%s\n' '│                   • setup-keymap ru — keyboard after login           │'
printf '%s\n' '│                                                                      │'
printf '%s\n' '│                   What'"'"'s new                                         │'
printf '%s\n' '│                   • Agent stub: rc-service luna-agent status         │'
printf '%s\n' '│                   • luna install — disk install (live ISO, sudo)       │'
printf '%s\n' '│                   • SSH: port forward 2222→22 (NAT, JetBrains Mono)  │'
printf '%s\n' '│                                                                      │'
printf '%s\n' '└──────────────────────────────────────────────────────────────────────┘'
printf '\n'
printf 'Luna %s · %s · %s\n' "$ver" "$base" "$agent"
printf '? luna help · luna status · luna think · luna tui\n'
