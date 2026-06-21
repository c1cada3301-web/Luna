# Luna shell prompt (bash)
[ -n "$BASH_VERSION" ] || return

_luna_ver() {
	[ -r /etc/luna-release ] && . /etc/luna-release
	printf '%s' "${LUNA_VERSION:-?}"
}

if [ "$(id -u)" -eq 0 ]; then
	PS1='\[\033[1;35m\]◐\[\033[0m\] \[\033[1;37mluna\[\033[0;35m\]:\[\033[1;34m\]\w\[\033[0;35m\]# \[\033[0m\]'
else
	PS1='\[\033[1;35m\]◐\[\033[0m\] \[\033[1;37mluna\[\033[0;35m\]:\[\033[1;34m\]\w\[\033[0;35m\]\$ \[\033[0m\]'
fi

export PS1
