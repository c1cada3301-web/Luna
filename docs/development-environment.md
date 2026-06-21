# Окружение разработки

Сборка Luna на **macOS**; тест — **VirtualBox** (Apple Silicon) и **QEMU**.

## Требования

Docker Desktop, QEMU (`brew install qemu`), VirtualBox, Git.

## Сборка

```bash
# Ключ (один раз) — см. README.md
docker compose run --rm luna-build-aarch64
```

Результат: `out/luna-0.4.0-aarch64.iso` (~112 MB)

## VirtualBox (Apple Silicon)

| Параметр | Значение |
|----------|----------|
| Type | Other Linux **(ARM 64-bit)** |
| EFI | **ON** |
| RAM | **1024–2048 MB** |
| Network | Adapter 1 **NAT** |
| ISO | `out/luna-0.4.0-aarch64.iso` |

**Login:** `luna` или `root`, пароль пустой (Enter). Экран входа — ASCII banner; OpenRC scrollback в истории tty.

## Проверка образа

### Фаза 1 — сеть и пакеты

```sh
ip addr
curl -I https://example.com
apk update && apk add tree
htop
mc
sudo id
git clone https://github.com/user/repo.git
```

### Фаза 3 — Luna CLI

```sh
luna version
luna status
luna tui
sudo rc-service luna-agent start   # stub
```

→ [luna-cli.md](luna-cli.md)

## Отладка

| Симптом | Решение |
|---------|---------|
| Зависание на `Starting local ...` | Не вызывать `setup-keymap` / `apk add` в `local.d`; см. [architecture.md](architecture.md) |
| `Network unreachable` | NAT в VB, пересобери ISO |
| `package mentioned in index not found` (initramfs) | Косметика; login должен появиться |
| `package mentioned in index not found` (apk add) | Старый ISO или смешанные repos; нужен `setup-apkrepos` |
| `loadkmap failed` | Убрать `loadkmap` из boot; `setup-keymap` после login |
| Login `luna` fail | ISO 0.1.0; нужен ≥ 0.2.0 |
| `persistent-storage: not found` | Косметика mdev; persist через `LUNA_DATA` |
| ping fail, curl ok | ICMP блокируется NAT — нормально |

## QEMU

```bash
./scripts/test-qemu.sh aarch64
```
