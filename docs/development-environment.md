# Окружение разработки

Сборка Luna рассчитана на **macOS**; тест — в **VirtualBox** (Apple Silicon) и/или **QEMU**.

## Требования

| Компонент | Зачем |
|-----------|--------|
| Docker Desktop | Linux-контейнер для сборки rootfs/ISO |
| QEMU | Быстрый boot ISO (`brew install qemu`) |
| VirtualBox | Ручное тестирование на Apple Silicon |
| Git | Версионирование |

## Apple Silicon vs Intel

| Задача | Apple Silicon (M1/M2/M3) | Intel Mac |
|--------|--------------------------|-----------|
| Сборка ARM64 ISO | `docker compose run --rm luna-build-aarch64` | то же (эмуляция или native) |
| Сборка x86 ISO | `docker compose run --rm luna-build-x86_64` | нативно |
| Тест в VM | VirtualBox: **ARM 64-bit + EFI** | VirtualBox x86_64 или QEMU |

На Apple Silicon **не** используй x86_64 ISO в VirtualBox — только `luna-0.1.0-aarch64.iso`.

## Первоначальная настройка

### Ключ подписи (один раз)

```bash
mkdir -p build/keys
abuild-keygen -a -i -n luna-repo -f build/keys/luna-repo.rsa
cp build/keys/luna-repo.rsa.pub overlay/etc/apk/keys/luna@local.rsa.pub
```

Приватный ключ в `.gitignore`. Без него `build-iso.sh` завершится с ошибкой.

### Сборка

```bash
docker compose run --rm luna-build-aarch64
# или
docker compose run --rm luna-build-x86_64
```

Артеfact: `out/luna-0.1.0-<arch>.iso`

## Workflow разработчика

```
┌─────────┐   docker compose   ┌─────────┐   out/      ┌──────────┐
│ Mac     │ ────────────────► │  ISO    │ ──────────► │ QEMU/VBox│
│ + Docker│                   └─────────┘             └──────────┘
└─────────┘
```

1. Правки в `overlay/` или `build/packages.txt`
2. `docker compose run --rm luna-build-aarch64`
3. `./scripts/test-qemu.sh` — smoke test
4. VirtualBox snapshot после успешной загрузки

## Docker-сборка

`docker-compose.yml` монтирует `overlay/`, `build/`, `out/`, `work/` в контейнер Alpine 3.20.

`build/Dockerfile` ставит:

- **x86_64:** syslinux, xorriso, squashfs-tools, alpine-sdk, abuild
- **aarch64:** grub-efi, dosfstools, mtools, xorriso, …

Команда внутри контейнера: `./build/build-iso.sh` (вызывает `build-rootfs.sh`, затем упаковывает ISO).

## Тестирование ISO

### VirtualBox (рекомендуется на Apple Silicon)

| Параметр | Значение |
|----------|----------|
| Type | Other Linux (ARM 64-bit) |
| System → EFI | **Enable EFI** |
| Memory | 1024 MB |
| Storage | Optical → `out/luna-0.1.0-aarch64.iso` |
| Disk | не обязателен (live) |

**Login:** `root`, пароль пустой (Enter).

### QEMU

```bash
./scripts/test-qemu.sh aarch64
```

На aarch64 скрипт открывает окно с `-display cocoa` (virtio-gpu). Для x86_64 — serial console (`-serial stdio`).

## Отладка

| Симптом | Что проверить |
|---------|----------------|
| `Mounting boot media failed` | структура ISO: `apks/.boot_repository`, подписанный `APKINDEX` |
| `UNTRUSTED signature` | ключ `luna@local.rsa.pub` в overlay и подпись с `-p` |
| `package mentioned in index not found` | apkovl не должен содержать online `repositories` |
| `can't open /dev/ttyAMA0` | используй ISO с `console=tty0` (без getty на AMA0) |
| `Login incorrect` | пароль пустой, не `root` |
| Два login prompt / выброс из сессии | дублирование getty (inittab + OpenRC agetty) |

## Что не нужно на старте

- Кросс-компилятор kernel (`x86_64-elf-gcc`)
- Полный Alpine build tree
- Сеть внутри гостя (фаза 1)
