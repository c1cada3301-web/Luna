# Опыт пользователя (Luna 0.4.0)

Как выглядит Luna при загрузке в VirtualBox / QEMU — минимально, но узнаваемо.

## Последовательность boot

```
GRUB «Luna» → OpenRC [*] → (clear) → login banner → luna / Enter → MOTD → prompt
```

1. **GRUB** — пункт меню Luna, ядро `virt`, initramfs с локального ISO.
2. **OpenRC** — монтирование FS, `mdev`, `hwdrivers`, `networking`, `local`, `sshd`.
3. **Login banner** — agetty очищает tty1 и показывает `/etc/issue`.
4. **Login** — `luna` или `root`, пароль пустой (Enter).
5. **MOTD** — `/etc/motd` при первом входе в shell.
6. **Prompt** — `◐ luna:~/path$` (bash).

Красные `ERROR: … package mentioned in index not found` в initramfs — **косметика** (локальный индекс ISO vs world); на login не влияют.

## Login banner (`/etc/issue`)

```
+------------------------------+
|        L U N A  0.4.0        |
|   minimal Linux · live ISO   |
+------------------------------+
 login: luna or root
 password: (empty — press Enter)

  after login: luna status · luna help · luna tui

login:
```

- Показывается на **tty1** до ввода логина.
- Рамка выровнена под ~80 колонок; на широком окне VirtualBox может быть слева — это нормально для текстовой консоли.
- Отдельного «окна» или второго TTY нет — тот же fullscreen терминал VB после clear.

## После входа

**MOTD:**

```
── Luna 0.4.0 ──  luna status · luna help · setup-timezone · setup-keymap
```

**Prompt** (`/etc/profile.d/luna-prompt.sh`):

| Пользователь | Пример |
|--------------|--------|
| `luna` | `◐ luna:~$` |
| `root` | `◐ luna:~#` |

**CLI:**

```sh
luna status
luna version
luna help
luna tui          # меню вручную, не при boot
luna-help         # → luna help
mc                # файловый менеджер (TUI)
cat /etc/luna-release
```

**Locale / keyboard** (после login, когда CDN repos уже настроены):

```sh
setup-keymap us    # или ru
setup-timezone Europe/Moscow
```

Не вызывать `setup-keymap` в `local.d` при boot — блокирует OpenRC.

## Типичная сессия (проверено)

```sh
luna:~$ luna status
luna:~$ curl -I https://example.com
luna:~$ apk add tree
luna:~$ git clone https://github.com/user/repo.git
```

Сеть через NAT, CDN после `setup-apkrepos.start`. Данные в RAM — после reboot исчезают (кроме `/mnt/persist` с диском `LUNA_DATA`).

## Известные косметические сообщения

**mdev coldplug** (scrollback):

```text
sh: /lib/mdev/persistent-storage: not found
```

На работу не влияет; persist через `LABEL=LUNA_DATA` — отдельно (`mount-persist.start`).

## UI и desktop

GNOME и GUI-FM **не входят** в образ. Стратегия интерфейса: [ui-strategy.md](ui-strategy.md).

## Файлы брендинга в репозитории

| Путь | Назначение |
|------|------------|
| `overlay/etc/issue` | Login banner |
| `overlay/etc/motd` | MOTD |
| `overlay/etc/luna-release` | Версия (источник для имени ISO) |
| `overlay/etc/luna/locale.conf` | LANG / KEYMAP defaults (shell) |
| `overlay/etc/profile.d/luna-prompt.sh` | PS1 |
| `overlay/etc/profile.d/luna-locale.sh` | export LANG |
| `overlay/etc/skel/.bashrc` | bash для root и luna |
| `overlay/usr/local/bin/luna` | CLI |
| `overlay/etc/init.d/luna-agent` | Agent stub |
| `overlay/etc/local.d/*.start` | DHCP, CDN repos, persist |

Версия ISO: `grep LUNA_VERSION overlay/etc/luna-release` → `out/luna-<ver>-<arch>.iso`.
