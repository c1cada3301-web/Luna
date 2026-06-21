# Luna default interactive shell
[ -f /etc/profile ] && . /etc/profile

if [ -f ~/.bash_aliases ]; then
	. ~/.bash_aliases
fi
