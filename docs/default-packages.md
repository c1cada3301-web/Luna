# Пакеты Luna by default

Luna 0.4.0 — live ISO на **Alpine Linux 3.20**. Все пакеты ниже попадают в локальный APK-репозиторий на ISO и устанавливаются при boot через initramfs.

## Базовые (build-rootfs.sh)

Скелет системы, init, ядро:

| Пакет | Назначение |
|-------|------------|
| `alpine-base` | Минимальный Alpine: OpenRC, apk, busybox, mdev |
| `alpine-conf` | `setup-*` утилиты |
| `alpine-release` | Версия Alpine |
| `busybox-openrc` | Busybox + OpenRC-интеграция |
| `openrc` | Init-система |
| `agetty` | Login prompt |
| `linux-virt` | Ядро `virt` (QEMU / VirtualBox) |
| `mkinitfs` | Initramfs (сборка на хосте) |
| `tzdata` | Часовые пояса (UTC) |

## Дополнительные (build/packages.txt)

| Пакет | Назначение |
|-------|------------|
| `bash` | Интерактивный shell (prompt Luna) |
| `nano` | Простой редактор |
| `curl` | HTTP-клиент |
| `wget` | Загрузка файлов |
| `git` | VCS |
| `vim` | Редактор |
| `sudo` | sudo для группы `wheel` |
| `openssh` | SSH-сервер и клиент |
| `e2fsprogs` | ext4 для persist-диска `LUNA_DATA` |
| `htop` | Монитор процессов |
| `mc` | TUI файловый менеджер (двухпанельный) |
| `musl-locales` | UTF-8 локали (musl) |
| `musl-locales-lang` | Языковые данные (ru, de, …) |
| `kbd-bkeymaps` | Раскладки для `setup-keymap` |

## Locale / timezone / keyboard

| Команда | Назначение |
|---------|------------|
| `setup-timezone` | Часовой пояс (из `alpine-conf`, tzdata в base) |
| `setup-keymap us\|ru\|de` | Консольная раскладка (**после login**, не в `local.d`) |
| `/etc/luna/locale.conf` | `LUNA_LANG`, `LUNA_KEYMAP` — подхватывает `profile.d/luna-locale.sh` |

Пример для русского:

```sh
sudo setup-timezone Europe/Moscow
sudo setup-keymap ru
# в /etc/luna/locale.conf: LUNA_LANG=ru_RU.UTF-8
```

| Элемент | Значение |
|---------|----------|
| `root` | Пароль пустой, shell `/bin/bash` |
| `luna` | UID 1000, группа `wheel`, sudo NOPASSWD |
| OpenRC | `networking`, `sshd`, `local` (DHCP, apk repos, persist) |

## Не в образе (ставятся после boot)

Любой пакет из Alpine CDN через `apk add` после `setup-apkrepos.start`. GNOME/KDE и GUI-FM — не в образе; см. [ui-strategy.md](ui-strategy.md).

## Где менять состав

- Новые пакеты → `build/packages.txt`
- Брендинг, сеть, скрипты boot → `overlay/etc/`
- Версия образа → `overlay/etc/luna-release`
