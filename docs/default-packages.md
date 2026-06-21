# Пакеты Luna by default

Luna 0.3.0 — live ISO на **Alpine Linux 3.20**. Все пакеты ниже попадают в локальный APK-репозиторий на ISO и устанавливаются при boot через initramfs.

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
| `mc` | Файловый менеджер |

## Пользователи и сервисы

| Элемент | Значение |
|---------|----------|
| `root` | Пароль пустой, shell `/bin/bash` |
| `luna` | UID 1000, группа `wheel`, sudo NOPASSWD |
| OpenRC | `networking`, `sshd`, `local` (DHCP, apk repos, persist) |

## Не в образе (ставятся после boot)

Любой пакет из Alpine CDN через `apk add` после `setup-apkrepos.start`.

## Где менять состав

- Новые пакеты → `build/packages.txt`
- Брендинг, сеть, скрипты boot → `overlay/etc/`
- Версия образа → `overlay/etc/luna-release`
