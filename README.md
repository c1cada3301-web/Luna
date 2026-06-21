# Luna

Минимальный Linux-дистрибутив на базе Alpine Linux. Долгосрочная цель — интерфейс «ОС как диалог с ИИ».

## Статус

**Luna 0.3.0 — фаза 2** (июнь 2026)

- Загрузочный ISO (ARM64 + x86_64), diskless live
- Брендинг: login banner, MOTD, bash-prompt, `luna-help`
- Сеть (DHCP), online `apk add`, curl/git/vim/htop/mc
- Пользователи `root` и `luna` (sudo), SSH
- Опциональный persist-диск (`LUNA_DATA` → `/mnt/persist`)

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
| `out/luna-0.3.0-aarch64.iso` (~112 MB) | ARM64 | VirtualBox: **ARM 64-bit, EFI ON** |
| `out/luna-0.3.0-x86_64.iso` | x86_64 | QEMU, VirtualBox Intel |

### 3. VirtualBox (Apple Silicon)

1. Other Linux **(ARM 64-bit)**, EFI **ON**, RAM **1024–2048 MB**
2. Network → Adapter 1 → **NAT**
3. ISO → `out/luna-0.3.0-aarch64.iso`

**Вход:** `luna` или `root`, пароль **пустой** (Enter).

### 4. После входа

```sh
luna-help               # справка на системе
cat /etc/luna-release   # версия
curl -I https://example.com
apk add mc              # online repos (CDN)
```

Prompt: `◐ luna:~$` (фиолетово-синий).

### 5. QEMU

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
├── overlay/usr/    # luna-help, welcome.txt
├── scripts/
├── docs/
├── CHANGELOG.md
└── out/            # ISO (gitignore)
```

## Документация

| Документ | О чём |
|----------|--------|
| [Roadmap](docs/roadmap.md) | Фазы 0–4 |
| [Опыт пользователя](docs/user-experience.md) | Banner, MOTD, prompt |
| [Пакеты по умолчанию](docs/default-packages.md) | Состав образа 0.3.0 |
| [Changelog](CHANGELOG.md) | История версий |
| [Документация](docs/README.md) | Индекс всех docs |
| [Архитектура](docs/architecture.md) | Boot, dual-arch, apk |
| [Milestone 0](docs/milestone-0.md) | Первый ISO |
| [Окружение](docs/development-environment.md) | Mac, Docker, VM |

## Ограничения

- Live в RAM — данные теряются после reboot (кроме `/mnt/persist` с диском `LUNA_DATA`)
- ICMP ping может не проходить через NAT; ориентируйся на `curl` / `apk`
