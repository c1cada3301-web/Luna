# Milestone 0: первый загружаемый ISO

## Цель

Собрать **`luna-0.1.0.iso`**, который:

1. Загружается в VirtualBox или QEMU (x86_64)
2. Показывает login prompt
3. После входа — shell с сообщением Luna (motd)
4. `cat /etc/luna-release` выводит версию

## Definition of Done

- [ ] Скрипт сборки запускается одной командой из README/build
- [ ] ISO < 200 MB (ориентир для minimal Alpine)
- [ ] Загрузка без kernel panic в VirtualBox
- [ ] Hostname: `luna`
- [ ] Файл `/etc/luna-release` существует

## Шаги реализации

### 1. Окружение сборки

На Mac:

```bash
# Docker для Linux-сборки
docker --version

# QEMU для быстрого теста (опционально на M0)
brew install qemu
```

Подробнее: [development-environment.md](development-environment.md)

### 2. Rootfs на базе Alpine

Два рабочих подхода (выберем один при реализации):

**A. Alpine `mkimage` (официальный путь для live/rescue ISO)**

Используется в Alpine Linux для создания образов. Требует Alpine build environment (Docker с образом `alpine`).

**B. Ручной chroot через `apk`**

```bash
# Псевдокод pipeline — будет в build/build-rootfs.sh
apk add --root ./rootfs --initdb alpine-base alpine-conf ...
cp -r overlay/* ./rootfs/
```

### 3. Overlay Luna

Минимальный набор файлов:

| Файл | Содержимое |
|------|------------|
| `/etc/hostname` | `luna` |
| `/etc/issue` | `Luna 0.1.0\n` |
| `/etc/motd` | Приветствие + ссылка на docs |
| `/etc/luna-release` | `LUNA_VERSION=0.1.0` |

### 4. Упаковка ISO

- Bootloader: extlinux/isolinux (стандарт для Alpine live)
- Output: `out/luna-0.1.0.iso`

### 5. Тест

**QEMU:**

```bash
qemu-system-x86_64 \
  -cdrom out/luna-0.1.0.iso \
  -m 512 \
  -serial stdio
```

**VirtualBox:**

1. New VM → Linux → Other Linux (64-bit)
2. RAM 512 MB–1 GB
3. Storage → attach ISO
4. Boot → login

## Риски

| Риск | Митигация |
|------|-----------|
| Сборка Alpine ISO на Mac | Docker с Linux |
| Apple Silicon + VirtualBox медленный | QEMU для dev; UTM как альтернатива |
| Забытые зависости в rootfs | Явный `packages.txt`, CI позже |

## После M0

Переход к [Фазе 1](roadmap.md#фаза-1--минимально-живая-система): сеть и `apk add` внутри гостя.
