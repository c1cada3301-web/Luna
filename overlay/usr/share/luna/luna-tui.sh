#!/bin/bash
# Luna simple TUI (bash select — no extra packages)

set -euo pipefail

luna_cmd() {
	command luna "$@"
}

while true; do
	echo
	printf '🌙 %s\n' "── Luna menu ──"
	PS3="Choose: "
	choices=(
		"Status"
		"Version"
		"Upgrade (root)"
		"Help"
		"Think (demo)"
		"Install to disk (root)"
		"Agent (stub) status"
		"Quit"
	)
	select _ in "${choices[@]}"; do
		case "$REPLY" in
			1) echo; luna_cmd status ;;
			2) echo; luna_cmd version ;;
			3)
				echo
				if [ "$(id -u)" -eq 0 ]; then
					luna_cmd upgrade
				else
					echo "Run: sudo luna upgrade"
				fi
				;;
			4) echo; luna_cmd help ;;
			5) echo; luna_cmd think 5 ;;
			6)
				echo
				if [ "$(id -u)" -eq 0 ]; then
					luna_cmd install
				else
					echo "Run: sudo luna install"
				fi
				;;
			7)
				echo
				rc-service luna-agent status 2>&1 || true
				;;
			8) exit 0 ;;
			*) echo "Invalid option" ;;
		esac
		break
	done
done
