# Опыт пользователя (Luna 0.3.0)

Как выглядит Luna при загрузке в VirtualBox / QEMU — минимально, но узнаваемо.

## Последовательность boot

```
GRUB «Luna» → OpenRC [*] → login banner → luna / Enter → MOTD → prompt
```

1. **GRUB** — пункт меню Luna, ядро `virt`, initramfs с локального ISO.
2. **OpenRC** — монтирование FS, `mdev`, `hwdrivers`, `networking`, `sshd`.
3. **Login banner** — `/etc/issue`: рамка `L U N A 0.3.0`, подсказка login/password.
4. **Login** — `luna` или `root`, пароль пустой (Enter).
5. **MOTD** — `/etc/motd`: версия, `luna-help`, сеть, persist.
6. **Prompt** — `◐ luna:~/path$` (bash, фиолетово-синий).

## Login banner (`/etc/issue`)

```
+------------------------------+
|        L U N A  0.3.0        |
|   minimal Linux · live ISO   |
+------------------------------+
 login: luna or root
 password: (empty — press Enter)
```

Показывается **до** ввода логина (agetty на tty1).

## После входа

**MOTD** (один раз за сессию через `/etc/profile`):

```
── Luna 0.3.0 · minimal live Linux ──

  luna-help          quick reference
  cat /etc/luna-release

  Network: DHCP · apk add <pkg> · sshd on
  Persist: mkfs.ext4 -L LUNA_DATA /dev/sdX → /mnt/persist
```

**Prompt** (`/etc/profile.d/luna-prompt.sh`):

| Пользователь | Пример |
|--------------|--------|
| `luna` | `◐ luna:~$` |
| `root` | `◐ luna:~#` |

**Справка на системе:**

```sh
luna-help                 # /usr/share/luna/welcome.txt
cat /etc/luna-release     # LUNA_VERSION=0.3.0
```

## Типичная сессия (проверено)

```sh
luna:~$ curl -I https://example.com
luna:~$ apk add git
luna:~$ git clone https://github.com/user/repo.git
luna:~/repo$ ls
```

Сеть через NAT, CDN после `setup-apkrepos.start`. Данные в RAM — после reboot исчезают (кроме `/mnt/persist`).

## Известные косметические сообщения

При coldplug `mdev` иногда в scrollback:

```text
sh: /lib/mdev/persistent-storage: not found
```

На работу системы не влияет; persist через `LABEL=LUNA_DATA` работает отдельно (`mount-persist.start`).

## Файлы брендинга в репозитории

| Путь | Назначение |
|------|------------|
| `overlay/etc/issue` | Login banner |
| `overlay/etc/motd` | MOTD |
| `overlay/etc/luna-release` | Версия (источник для имени ISO) |
| `overlay/etc/profile.d/luna-prompt.sh` | PS1 |
| `overlay/etc/skel/.bashrc` | bash для root и luna |
| `overlay/usr/local/bin/luna-help` | Справка |
| `overlay/usr/share/luna/welcome.txt` | Текст справки |

Версия ISO: `grep LUNA_VERSION overlay/etc/luna-release` → `out/luna-<ver>-<arch>.iso`.
