# Архитектура

## Выбор базы: Alpine Linux

| Критерий | Alpine |
|----------|--------|
| Размер base | ~5–130 MB |
| Init | OpenRC |
| Пакеты | `apk` |
| Custom live ISO | initramfs diskless + локальный репозиторий на ISO |
| Сложность | Средняя |

**Решение:** Alpine — компактная база, хорошо подходит для live ISO.

## Boot-модель Luna (diskless live)

```
GRUB/syslinux → vmlinuz-virt + initramfs-virt
       ↓
initramfs: mount ISO9660, find apks/.boot_repository
       ↓
apk add (локальный репозиторий + подписанный APKINDEX)
       ↓
unpack localhost.apkovl.tar.gz (etc/ + root/ + home/ + usr/)
       ↓
switch_root → OpenRC → local.d → login (banner + MOTD + prompt)
       ↓
setup-apkrepos.start: /etc/apk/repositories ← только CDN (ISO-репо убирается)
```

После login пользователь видит Luna Shell 0.5.0 — см. [user-experience.md](user-experience.md).

ISO содержит:

- `boot/vmlinuz-virt`, `boot/initramfs-virt`
- `boot/modloop-virt` (squashfs модулей; на M0 не монтируется — `modloop=none`)
- `apks/<arch>/*.apk` + подписанный `APKINDEX.tar.gz`
- `localhost.apkovl.tar.gz` — конфиг Luna (hostname, issue, motd, keys, local.d)
- `.alpine-release`

Модули ядра ставятся через пакет `linux-virt` при diskless apk, без modloop.

## Dual-arch

| | x86_64 | aarch64 |
|---|--------|---------|
| Целевая VM | QEMU, VirtualBox Intel | VirtualBox / UTM на Apple Silicon |
| Bootloader | syslinux (BIOS) | GRUB UEFI (`BOOTAA64.EFI`) |
| Kernel cmdline | `console=tty0 console=ttyS0 ip=off` | `console=tty0 ip=off` |
| ISO | `out/luna-0.5.0-x86_64.iso` | `out/luna-0.5.0-aarch64.iso` |

Сборка: `LUNA_ARCH` в Docker (`docker-compose.yml`).

## Слои системы

```
┌──────────────────────────────────────────┐
│  luna CLI + luna-agent stub   (фаза 3)   │
├──────────────────────────────────────────┤
│  overlay: issue, motd, prompt, luna-help │
│  local.d: network, apk repos, persist    │
├──────────────────────────────────────────┤
│  Alpine rootfs (diskless tmpfs)  OpenRC  │
├──────────────────────────────────────────┤
│  linux-virt kernel (Alpine 3.20)         │
├──────────────────────────────────────────┤
│  GRUB UEFI / syslinux + ISO9660          │
└──────────────────────────────────────────┘
```

Kernel не форкаем. Кастомизация — overlay, `packages.txt`, apkovl.

## Overlay Luna (0.5.0)

| Путь | Назначение |
|------|------------|
| `etc/issue`, `etc/motd` | Login banner и MOTD |
| `etc/luna-release` | Версия образа (`LUNA_VERSION`) |
| `etc/luna/locale.conf` | LANG / KEYMAP defaults |
| `etc/profile.d/luna-prompt.sh` | Bash prompt `◐ luna:…` |
| `etc/profile.d/luna-locale.sh` | export LANG из locale.conf |
| `etc/skel/.bashrc` | Интерактивный shell для root/luna |
| `etc/local.d/*.start` | DHCP, CDN repos, persist-диск |
| `usr/local/bin/luna` | CLI: welcome, status, think, help, tui |
| `usr/share/luna/welcome-screen.sh` | Welcome card (Luna Shell) |
| `usr/share/luna/thinking.sh` | Phase animation |
| `etc/init.d/luna-agent` | OpenRC stub (не в default runlevel) |
| `etc/ssh/sshd_config.d/luna.conf` | SSH empty password (dev VM) |

**Boot `local.d`:** только `network-dhcp`, `setup-apkrepos`, `mount-persist` — как в 0.3.0. Не добавлять `setup-keymap` / `apk add` в `.start` (блокирует runlevel `local`).

Подробнее: [user-experience.md](user-experience.md), [default-packages.md](default-packages.md), [ui-strategy.md](ui-strategy.md).

## Структура репозитория

```
Luna/
├── docs/
├── build/
│   ├── Dockerfile
│   ├── build-rootfs.sh
│   ├── build-iso.sh
│   ├── packages.txt
│   └── keys/                 # luna-repo.rsa (gitignore)
├── overlay/etc/
├── overlay/usr/                # luna-help, welcome.txt
├── scripts/test-qemu.sh
├── docker-compose.yml
└── out/                      # gitignore
```

## Init и консоль

- **OpenRC** — sysinit/boot/default runlevels
- **Login:** `/etc/inittab` → `openrc default`, затем `agetty` на `tty1` (без `--noclear`); banner из `/etc/issue`
- Serial-консоли добавляет initramfs (`setup_inittab_console`), только если устройство доступно
- Пользователи `root` и `luna` — пустой пароль (live demo); `luna` в группе `wheel` (sudo)

## Подпись локального репозитория

Boot-time `apk` требует доверенный `APKINDEX`. Схема:

1. `abuild-sign -k build/keys/luna-repo.rsa -p luna@local.rsa.pub`
2. Публичный ключ в `overlay/etc/apk/keys/luna@local.rsa.pub` → попадает в apkovl и initramfs

## APK: boot vs runtime

| Этап | Репозитории | Зачем |
|------|-------------|--------|
| Initramfs | Локальный ISO (`apks/.boot_repository`) | Установка rootfs **без CDN** (`--no-network`, `ip=off`) |
| apkovl | **Без** `etc/apk/repositories` | Иначе при NAT apk тянет CDN во время boot |
| После boot | `setup-apkrepos.start` → **только CDN** | `apk add` без конфликта с ISO-индексом |

Локальный репо на ISO (~76 пакетов) и CDN (тысячи) **не смешиваются** после загрузки.

## Тестирование

| Инструмент | Назначение |
|------------|------------|
| **VirtualBox ARM64** | Основной тест на Apple Silicon |
| **QEMU** | Быстрый smoke test из терминала |

## Безопасность (минимум)

- Пустые пароли root/luna — только для live demo в VM
- Приватный ключ репозитория не в git
- AI-shell (фаза 4) — подтверждение destructive commands

## Языки

| Слой | Язык |
|------|------|
| Сборка | Bash, Dockerfile |
| Конфиг | shell, OpenRC, inittab |
| Luna CLI (фаза 3) | shell (OpenRC stub) |
| Kernel (если ever) | отдельный трек |
