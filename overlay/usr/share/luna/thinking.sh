#!/bin/sh
# Luna thinking animation — 🌙 ◐ ◑ ◒

duration="${1:-5}"
phases='🌙 ◐ ◑ ◒'

cleanup() {
	printf '\r\033[K\n'
}
trap cleanup INT TERM EXIT

if [ "$duration" = "0" ] || [ "$duration" = "forever" ]; then
	end=0
else
	case "$duration" in
		*[!0-9]*) duration=5 ;;
	esac
	end=$(($(date +%s) + duration))
fi

while :; do
	for p in $phases; do
		printf '\r  %s  thinking…' "$p"
		sleep 0.35
		if [ "$end" -gt 0 ] && [ "$(date +%s)" -ge "$end" ]; then
			exit 0
		fi
	done
done
