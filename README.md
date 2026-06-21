# Luna

Минимальный Linux-дистрибутив на базе Alpine Linux. Долгосрочная цель — интерфейс «ОС как диалог с ИИ»; сейчас закрыт **Milestone 0**: загрузочный ISO с login и брендингом Luna.

## Статус

**Milestone 0 — готов** (июнь 2026)

- ISO собирается одной командой через Docker
- Загрузка в VirtualBox (Apple Silicon, ARM64) и QEMU
- Login prompt, shell, `Welcome to Luna`, `/etc/luna-release`

## Быстрый старт

### 1. Ключ подписи APK-репозитория (один раз)

ISO использует локальный apk-репозиторий на диске. Для сборки нужен приватный ключ:

```bash
mkdir -p build/keys
abuild-keygen -a -i -n luna-repo -f build/keys/luna-repo.rsa
cp build/keys/luna-repo.rsa.pub overlay/etc/apk/keys/luna@local.rsa.pub
```

Файл `build/keys/luna-repo.rsa` в `.gitignore` — не коммитить.

### 2. Сборка ISO

```bash
# Apple Silicon → VirtualBox / UTM (ARM64, нативно)
docker compose run --rm luna-build-aarch64

# Intel Mac / QEMU x86_64
docker compose run --rm luna-build-x86_64
```

Результат:

| Файл | Архитектура | Где тестировать |
|------|-------------|-----------------|
| `out/luna-0.1.0-aarch64.iso` (~83 MB) | ARM64 | VirtualBox на Mac (ARM 64-bit, **EFI ON**) |
| `out/luna-0.1.0-x86_64.iso` | x86_64 | QEMU, VirtualBox на Intel |

### 3. Запуск в VirtualBox (Apple Silicon)

1. New VM → **Other Linux (ARM 64-bit)**
2. RAM: 1024 MB
3. **System → EFI:** включить
4. Optical drive → `out/luna-0.1.0-aarch64.iso`
5. Boot

**Вход:** логин `root`, пароль **пустой** (просто Enter).

### 4. Тест в QEMU

```bash
./scripts/test-qemu.sh              # auto: aarch64 на M Mac
./scripts/test-qemu.sh aarch64
./scripts/test-qemu.sh x86_64
```

## Структура репозитория

```
Luna/
├── build/
│   ├── Dockerfile           # Alpine 3.20, syslinux / GRUB
│   ├── build-rootfs.sh      # rootfs + OpenRC + initramfs
│   ├── build-iso.sh         # modloop, apk repo, ISO
│   ├── packages.txt         # доп. пакеты (bash, nano)
│   └── keys/                # приватный ключ (gitignore)
├── overlay/etc/             # hostname, issue, motd, luna-release
├── scripts/test-qemu.sh
├── docs/                    # видение, roadmap, архитектура
├── docker-compose.yml
└── out/                     # ISO (gitignore)
```

## Документация

| Документ | О чём |
|----------|--------|
| [Видение](docs/vision.md) | Зачем Luna, долгосрочная цель |
| [Roadmap](docs/roadmap.md) | Этапы от ISO до AI-shell |
| [Архитектура](docs/architecture.md) | Стек, boot-модель, dual-arch |
| [Milestone 0](docs/milestone-0.md) | Критерии и результат M0 |
| [Окружение разработки](docs/development-environment.md) | Mac, Docker, VirtualBox, QEMU |
| [ADR-001](docs/decisions/001-linux-distro-first.md) | Почему Linux-дистрибутив, а не kernel с нуля |

## Стек

- **База:** Alpine Linux 3.20, OpenRC, `apk`
- **Boot:** diskless live (initramfs + локальный apk-репозиторий на ISO)
- **Сборка:** Docker на macOS, dual-arch (`x86_64` / `aarch64`)
- **Bootloader:** syslinux (x86 BIOS) / GRUB UEFI (ARM64)

## Известные ограничения M0

- Live-система в RAM, изменения не сохраняются после перезагрузки
- Сеть не настроена (фаза 1)
- При загрузке могут мелькать косметические предупреждения (`persistent-storage`, старые строки apk в scrollback) — на работу не влияют
