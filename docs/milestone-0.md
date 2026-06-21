# Milestone 0: первый загружаемый ISO

## Цель

Собрать **`luna-0.1.0`**, который:

1. Загружается в VirtualBox (Apple Silicon, ARM64) или QEMU
2. Показывает login prompt с брендингом Luna
3. После входа — shell и motd «Welcome to Luna»
4. `cat /etc/luna-release` выводит версию

## Definition of Done

- [x] Скрипт сборки запускается одной командой (`docker compose run …`)
- [x] ISO < 200 MB (~83 MB для aarch64)
- [x] Загрузка без kernel panic в VirtualBox
- [x] Hostname: `luna`
- [x] Файл `/etc/luna-release` существует
- [x] Login: `root` / пустой пароль

**Статус: закрыт** (июнь 2026)

## Что реализовано

### Pipeline сборки

1. **`build/build-rootfs.sh`** — `apk --root`, overlay, OpenRC, `mkinitfs`
2. **`build/build-iso.sh`** — modloop, локальный apk-репозиторий на ISO, подпись `APKINDEX`, `localhost.apkovl.tar.gz`, упаковка ISO
3. **`docker-compose.yml`** — `luna-build-aarch64` и `luna-build-x86_64`

### Boot-модель (Alpine diskless live)

Initramfs монтирует ISO, устанавливает пакеты из локального репозитория (`apks/.boot_repository`), распаковывает `localhost.apkovl.tar.gz`, делает `switch_root`.

Важные детали, выработанные при отладке:

| Решение | Зачем |
|---------|--------|
| Подпись `APKINDEX` ключом `luna@local` | initramfs отклонял неподписанный индекс |
| Без `etc/apk/repositories` в apkovl | иначе при сети в VM apk тянет CDN и ломается |
| `modloop=none` в cmdline | модули уже в rootfs через apk; modloop на VB ARM падал |
| `console=tty0` (без ttyAMA0) | VirtualBox ARM не имеет serial-консоли |
| Inittab: только `tty1` + agetty | без дублирования getty (OpenRC + inittab) |
| `/root` в apkovl | иначе login не находил home directory |

### Overlay Luna

| Файл | Содержимое |
|------|------------|
| `/etc/hostname` | `luna` |
| `/etc/issue` | версия + подсказка login/password |
| `/etc/motd` | `Welcome to Luna` |
| `/etc/luna-release` | `LUNA_VERSION=0.1.0` |
| `/etc/apk/keys/luna@local.rsa.pub` | публичный ключ локального репозитория |

### Dual-arch

| Архитектура | Bootloader | ISO |
|-------------|------------|-----|
| `aarch64` | GRUB UEFI | `out/luna-0.1.0-aarch64.iso` |
| `x86_64` | syslinux BIOS | `out/luna-0.1.0-x86_64.iso` |

## Тест

### VirtualBox (Apple Silicon)

| Параметр | Значение |
|----------|----------|
| Type | Other Linux **(ARM 64-bit)** |
| EFI | **ON** |
| Memory | 1024 MB |
| ISO | `out/luna-0.1.0-aarch64.iso` |

### QEMU

```bash
./scripts/test-qemu.sh aarch64   # окно с virtio-gpu (macOS)
./scripts/test-qemu.sh x86_64    # serial console
```

## После M0

- [Фаза 1](roadmap.md#фаза-1--минимально-живая-система) — сеть, пакеты, persist ✅
- [Фаза 2](roadmap.md#фаза-2--идентичность-luna) — брендинг, документация ✅
- [Фаза 3](roadmap.md#фаза-3--luna-userspace) — утилита `luna` (CLI)
