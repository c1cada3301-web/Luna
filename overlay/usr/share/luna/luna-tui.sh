#!/bin/bash
# Luna simple TUI (bash select — no extra packages)

set -euo pipefail

luna_cmd() {
	command luna "$@"
}

while true; do
	echo
	echo "── Luna menu ──"
	PS3="Choose: "
	choices=(
		"Status"
		"Version"
		"Help"
		"Agent (stub) status"
		"Quit"
	)
	select _ in "${choices[@]}"; do
		case "$REPLY" in
			1) echo; luna_cmd status ;;
			2) echo; luna_cmd version ;;
			3) echo; luna_cmd help ;;
			4)
				echo
				rc-service luna-agent status 2>&1 || true
				;;
			5) exit 0 ;;
			*) echo "Invalid option" ;;
		esac
		break
	done
done
