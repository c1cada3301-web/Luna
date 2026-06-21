# Luna

Минимальный Linux-дистрибутив на базе Alpine Linux. Долгосрочная цель — интерфейс «ОС как диалог с ИИ».

## Статус

**Luna 0.8.0 — фаза 5.3 (bare metal)** (июнь 2026)

- **`luna install`** → **linux-lts** + **linux-firmware** на диск (live ISO остаётся virt)
- **`luna upgrade`** — Alpine-пакеты; Luna release — через ISO/scp
- Проверено: VirtualBox ARM64 install → SSH → `apk add` persist → 0.7.0

## Быстрый старт

### 1. Ключ подписи APK (один раз)

```bash
mkdir -p build/keys
abuild-keygen -a -i -n luna-repo -f build/keys/luna-repo.rsa
cp build/keys/luna-repo.rsa.pub overlay/etc/apk/keys/luna@local.rsa.pub
```

`build/keys/luna-repo.rsa` — в `.gitignore`, не коммитить.

### 2. Сборка ISO

```bash
docker compose run --rm luna-build-aarch64   # VirtualBox на Apple Silicon
docker compose run --rm luna-build-x86_64    # QEMU / Intel
```

Версия берётся из `overlay/etc/luna-release`. Результат:

| ISO | Архитектура | Тест |
|-----|-------------|------|
| `out/luna-0.8.0-aarch64.iso` (~108 MB) | ARM64 | VirtualBox / mini-PC **ARM 64-bit, EFI ON** |
| `out/luna-0.8.0-x86_64.iso` | x86_64 | QEMU, VirtualBox Intel, NUC |

### 3. VirtualBox (Apple Silicon)

1. Other Linux **(ARM 64-bit)**, EFI **ON**, RAM **1024–2048 MB**
2. Network → Adapter 1 → **NAT**
3. ISO → `out/luna-0.8.0-aarch64.iso`

**Вход:** `luna` или `root`, пароль **пустой** (Enter). Затем **`luna`** — welcome-screen.

### 4. SSH с Mac (VM уже запущена)

1. VirtualBox → Network → NAT → Port Forwarding: **2222 → 22**
2. `ssh -p 2222 luna@127.0.0.1` (пароль пустой)
3. Шрифт в iTerm: **JetBrains Mono 15** — как в Cursor

### 5. После входа

```sh
luna                    # welcome-screen 🌙
luna status
luna think 5            # animation demo
luna help
sudo luna install       # install to virtual disk (add SATA disk ≥8 GB first)
sudo luna upgrade       # update packages (installed system)
```

Prompt: `◐ luna:~$` (фиолетово-синий).

### 6. Установка на диск (VirtualBox)

1. VM выключена → Settings → Storage → **SATA disk** (VDI, ≥8 GB) — один раз
2. Boot с ISO → `sudo luna install` → пароли root/luna
3. Отключить ISO → reboot → `luna status` (`boot: installed (disk)`)

На диск ставится **linux-lts** + firmware (для mini-PC). Только VM: `LUNA_INSTALL_KERNEL=virt sudo luna install`.

### 7. Mini-PC / bare metal (aarch64 или x86_64)

1. Записать `out/luna-0.8.0-*.iso` на USB (Balena Etcher, `dd`)
2. Boot с USB, **UEFI ON**, Secure Boot **OFF** (если не грузится)
3. Ethernet или Wi‑Fi после install — DHCP через `network-dhcp.start`
4. `sudo luna install` → выбрать внутренний NVMe/SATA (не USB-флешку!)
5. Reboot без USB → login → `luna status`

**SSH с Mac по LAN:** узнай IP (`ip addr`), `ssh luna@<ip>`.

Типичные проблемы: нет EFI → включить в BIOS; выбрал флешку вместо диска; Secure Boot блокирует GRUB.

Пакеты live vs install: [docs/luna-base.md](docs/luna-base.md).

### 8. QEMU

```bash
./scripts/test-qemu.sh aarch64
```

## Boot-модель

1. **Initramfs** ставит пакеты с **локального репо на ISO** (подписанный `APKINDEX`)
2. **После boot** `setup-apkrepos.start` **заменяет** repos на CDN Alpine — `apk add` без ошибок «package mentioned in index not found»

## Структура

```
Luna/
├── build/          # Dockerfile, build-rootfs.sh, build-iso.sh, packages.txt
├── overlay/etc/    # брендинг, сеть, local.d
├── overlay/usr/    # luna CLI, luna-help, welcome.txt
├── scripts/
├── docs/
├── CHANGELOG.md
└── out/            # ISO (gitignore)
```

## Документация

[Roadmap](docs/roadmap.md) · [Changelog](CHANGELOG.md) · [Package profiles](docs/luna-base.md)

## Релизы

Стабильные ISO публикуются на [GitHub Releases](https://github.com/c1cada3301-web/Luna/releases) по тегу `v0.x.0`.

| Файл | Назначение |
|------|------------|
| `luna-*-aarch64.iso` | Apple Silicon VM, ARM mini-PC, UEFI |
| `luna-*-x86_64.iso` | Intel/AMD VM, NUC, UEFI/BIOS |
| `SHA256SUMS` | контрольные суммы |

### Опубликовать релиз (maintainer)

1. Bump `overlay/etc/luna-release` + секция в `CHANGELOG.md`
2. Commit → push `main`
3. **CI (рекомендуется):** `./scripts/release.sh --push` — тег → GitHub Actions собирает оба ISO
4. **Локально:** `./scripts/release-local.sh` — Docker build + `gh release create`

Секрет **`LUNA_REPO_RSA`**: `base64 -i build/keys/luna-repo.rsa` → GitHub → Settings → Secrets.  
Должен соответствовать `overlay/etc/apk/keys/luna@local.rsa.pub`.

## Ограничения

- Live в RAM — данные теряются после reboot (кроме `/mnt/persist` с диском `LUNA_DATA`)
- ICMP ping может не проходить через NAT; ориентируйся на `curl` / `apk`
