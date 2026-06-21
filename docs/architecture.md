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
unpack localhost.apkovl.tar.gz (etc/ + root/)
       ↓
switch_root → OpenRC → agetty tty1 → login
```

ISO содержит:

- `boot/vmlinuz-virt`, `boot/initramfs-virt`
- `boot/modloop-virt` (squashfs модулей; на M0 не монтируется — `modloop=none`)
- `apks/<arch>/*.apk` + подписанный `APKINDEX.tar.gz`
- `localhost.apkovl.tar.gz` — конфиг Luna (hostname, issue, motd, keys)
- `.alpine-release`

Модули ядра ставятся через пакет `linux-virt` при diskless apk, без modloop.

## Dual-arch

| | x86_64 | aarch64 |
|---|--------|---------|
| Целевая VM | QEMU, VirtualBox Intel | VirtualBox / UTM на Apple Silicon |
| Bootloader | syslinux (BIOS) | GRUB UEFI (`BOOTAA64.EFI`) |
| Kernel cmdline | `console=tty0 console=ttyS0` | `console=tty0` |
| ISO | `out/luna-0.1.0-x86_64.iso` | `out/luna-0.1.0-aarch64.iso` |

Сборка: `LUNA_ARCH` в Docker (`docker-compose.yml`).

## Слои системы

```
┌──────────────────────────────────────────┐
│  luna-shell / luna-cli        (будущее)  │
├──────────────────────────────────────────┤
│  overlay: hostname, issue, motd, release │
├──────────────────────────────────────────┤
│  Alpine rootfs (diskless tmpfs)  OpenRC  │
├──────────────────────────────────────────┤
│  linux-virt kernel (Alpine)              │
├──────────────────────────────────────────┤
│  GRUB UEFI / syslinux + ISO9660          │
└──────────────────────────────────────────┘
```

Kernel не форкаем. Кастомизация — overlay, `packages.txt`, apkovl.

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
├── scripts/test-qemu.sh
├── docker-compose.yml
└── out/                      # gitignore
```

## Init и консоль

- **OpenRC** — sysinit/boot/default runlevels
- **Login:** `/etc/inittab` → `agetty` на `tty1` (без дублирования через OpenRC agetty)
- Serial-консоли добавляет initramfs (`setup_inittab_console`), только если устройство доступно
- Root без пароля на M0 (`passwd -d root` при сборке)

## Подпись локального репозитория

Boot-time `apk` требует доверенный `APKINDEX`. Схема:

1. `abuild-sign -k build/keys/luna-repo.rsa -p luna@local.rsa.pub`
2. Публичный ключ в `overlay/etc/apk/keys/luna@local.rsa.pub` → попадает в apkovl и initramfs

## Тестирование

| Инструмент | Назначение |
|------------|------------|
| **VirtualBox ARM64** | Основной тест на Apple Silicon |
| **QEMU** | Быстрый smoke test из терминала |

## Безопасность (минимум)

- Root без пароля — только M0; на M1 — user + sudo
- Приватный ключ репозитория не в git
- AI-shell (фаза 4) — подтверждение destructive commands

## Языки

| Слой | Язык |
|------|------|
| Сборка | Bash, Dockerfile |
| Конфиг | shell, OpenRC, inittab |
| Luna CLI (фаза 3) | Rust или Go |
| Kernel (если ever) | отдельный трек |
