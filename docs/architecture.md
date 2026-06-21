# Архитектура

## Выбор базы: Alpine Linux

| Критерий | Alpine | Debian minimal |
|----------|--------|----------------|
| Размер base | ~5–130 MB | ~200+ MB |
| Init | OpenRC (простой) | systemd |
| Пакеты | `apk` | `apt` |
| Документация для custom ISO | `mkimage`, `lbu` | debootstrap + live-build |
| Сложность для новичка | Средняя | Средняя |

**Решение:** Alpine — меньше образ, проще ментальная модель для minimal distro, хорошо подходит для live ISO и embedded-подхода.

Переход на Debian возможен позже (ADR отдельно), если понадобится экосистема `.deb`.

## Слои системы

```
┌──────────────────────────────────────────┐
│  luna-shell / luna-cli        (будущее)  │
├──────────────────────────────────────────┤
│  /etc/luna/*                  конфиги    │
│  overlay: motd, issue, packages.txt      │
├──────────────────────────────────────────┤
│  Alpine rootfs                apk, OpenRC│
├──────────────────────────────────────────┤
│  Linux kernel                 (от Alpine)│
├──────────────────────────────────────────┤
│  Bootloader              extlinux /      │
│                          grub / syslinux │ 
└──────────────────────────────────────────┘
```

Мы **не форкаем kernel** на старте. Кастомизация — через rootfs overlay и список пакетов.

## Структура репозитория (план)

```
Luna/
├── docs/                 # документация (этот каталог)
├── build/
│   ├── Dockerfile        # воспроизводимая сборка на Mac
│   ├── build-rootfs.sh   # создаёт rootfs из Alpine
│   ├── build-iso.sh      # упаковывает ISO
│   └── packages.txt      # список apk-пакетов для Luna
├── overlay/              # файлы, копируемые в rootfs
│   └── etc/
│       ├── hostname
│       ├── issue
│       ├── motd
│       └── luna-release
├── scripts/
│   └── test-qemu.sh      # быстрый прогон в QEMU
└── out/                  # артеfactы сборки (gitignore)
    └── luna-0.1.0.iso
```

Папки `build/`, `overlay/` появятся при реализации Milestone 0.

## Сборка

### Pipeline

1. **Rootfs** — `apk` в chroot или официальный `mkimage`-workflow Alpine
2. **Overlay** — копирование `/overlay` → rootfs
3. **ISO** — `mkimage` или xorriso + isolinux
4. **Test** — QEMU локально, VirtualBox для «как пользователь»

### Где собирать

| Хост | Возможность |
|------|-------------|
| macOS + Docker | ✅ Рекомендуется: Linux-контейнер с `apk`, chroot |
| macOS нативно | ⚠️ Ограничено: нет нативного `apk`/debootstrap |
| Linux VM на Mac | ✅ Полный контроль |

Alpine-образы и `mkimage` рассчитаны на Linux; на Mac используем Docker или Linux VM.

## Init и сервисы

- **OpenRC** — init Alpine по умолчанию
- На M0: стандартный boot → getty → login
- Позже: свой runlevel или сервис `luna-agent` (OpenRC init script)

OpenRC init scripts для кастомных сервисов — [Alpine Developer Documentation](https://wiki.alpinelinux.org/wiki/Developer_Documentation).

## Тестирование

| Инструмент | Назначение |
|------------|------------|
| **QEMU** | Быстрые итерации, serial console (`-serial stdio`) |
| **VirtualBox** | Ручная проверка, snapshots, «как на железе» |
| **UTM** | Альтернатива на Apple Silicon |

Целевая архитектура гостя: **x86_64** (широкая совместимость с VirtualBox на Intel Mac; на Apple Silicon — эмуляция медленнее, но работает).

## Безопасность (минимум)

- Root login только на M0 для отладки; на M1 — user + sudo
- Не хранить секреты в overlay/git
- AI-shell (фаза 4) — обязательное подтверждение для destructive commands

## Языки

| Слой | Язык |
|------|------|
| Сборка | Bash, Dockerfile |
| Конфиг | shell, OpenRC scripts |
| Luna CLI (фаза 3) | Rust или Go (на выбор позже) |
| TUI | Rust (ratatui) или Python (textual) |
| Kernel (если ever) | C, asm, возможно Rust — **отдельный трек** |

На фазах 0–2 достаточно shell и конфигов.
