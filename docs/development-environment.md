# Окружение разработки

Сборка Luna рассчитана на **macOS** как основной хост разработки; тест — в **VirtualBox** и/или **QEMU**.

## Требования

| Компонент | Зачем |
|-----------|--------|
| Docker Desktop | Linux-контейнер для сборки rootfs/ISO |
| QEMU | Быстрый boot ISO из терминала |
| VirtualBox | Ручное тестирование, snapshots |
| Git | Версионирование |

Опционально: **UTM** (удобнее на Apple Silicon, чем VirtualBox для некоторых сценариев).

## macOS: установка

```bash
# Homebrew
brew install docker qemu git

# Docker Desktop — отдельно с https://docker.com/products/docker-desktop
# VirtualBox — отдельно с https://virtualbox.org (или brew install --cask virtualbox)
```

## Apple Silicon (M1/M2/M3)

- **Сборка** в Docker (linux/amd64 или linux/arm64) — работает нормально
- **VirtualBox** на ARM Mac: x86_64 guest эмулируется медленно; для частых итераций предпочитай **QEMU**
- **UTM** может быть удобнее для ARM-native Linux guest, но наш первый ISO — **x86_64** для универсальности

## Workflow разработчика

```
┌─────────┐     build/      ┌─────────┐     out/       ┌──────────┐
│ Mac     │ ──────────────► │  ISO    │ ─────────────► │ QEMU/VBox│
│ + Docker│                 └─────────┘                └──────────┘
└─────────┘
```

1. Правки в `overlay/` или `build/packages.txt`
2. `./build/build-iso.sh` (будет добавлен)
3. `./scripts/test-qemu.sh` — smoke test
4. VirtualBox snapshot «after change X» для регрессий

## Docker-сборка (концепт)

Сборочный контейнер на базе Alpine:

```dockerfile
# build/Dockerfile — черновик для M0
FROM alpine:3.20
RUN apk add --no-cache alpine-sdk abuild mkinitfs syslinux xorriso squashfs-tools
WORKDIR /luna
```

Запуск с монтированием репозитория:

```bash
docker build -t luna-build -f build/Dockerfile .
docker run --rm -v "$(pwd):/luna" -w /luna luna-build ./build/build-iso.sh
```

Точные команды появятся вместе со скриптами Milestone 0.

## Тестирование ISO

### QEMU (рекомендуется для итераций)

```bash
qemu-system-x86_64 \
  -machine q35 \
  -cpu qemu64 \
  -m 1024 \
  -cdrom out/luna-0.1.0.iso \
  -boot d \
  -serial stdio \
  -display none
```

Serial console полезен, если графический вывод глючит.

### VirtualBox

| Параметр | Значение |
|----------|----------|
| Type | Linux, Other Linux (64-bit) |
| Memory | 512 MB – 1 GB |
| Disk | не обязателен для live ISO |
| Boot order | Optical first |

После первой успешной загрузки — **Snapshot** «M0 clean boot».

## Отладка

- **Не грузится:** проверить, что ISO bootable; смотреть QEMU с `-d guest_errors`
- **Kernel panic:** несовместимость initramfs/kernel — сверить версии Alpine packages
- **Нет сети:** ожидаемо на M0; сеть — фаза 1

## Что не нужно на старте

- Кросс-компилятор `x86_64-elf-gcc` (это для kernel dev, не для distro)
- Полный Alpine build tree (abuild все пакетов)
- GUI на хосте кроме VM viewer
