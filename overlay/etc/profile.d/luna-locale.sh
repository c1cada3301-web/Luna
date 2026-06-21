# Luna locale (musl-locales)
[ -r /etc/luna/locale.conf ] && . /etc/luna/locale.conf
export LANG="${LUNA_LANG:-C.UTF-8}"
