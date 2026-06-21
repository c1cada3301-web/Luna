# Окружение разработки

Сборка Luna на **macOS**; тест — **VirtualBox** (Apple Silicon) и **QEMU**.

## Требования

Docker Desktop, QEMU (`brew install qemu`), VirtualBox, Git.

## Сборка

```bash
# Ключ (один раз) — см. README.md
docker compose run --rm luna-build-aarch64
```

Результат: `out/luna-0.3.0-aarch64.iso` (~112 MB)

## VirtualBox (Apple Silicon)

| Параметр | Значение |
|----------|----------|
| Type | Other Linux **(ARM 64-bit)** |
| EFI | **ON** |
| RAM | **1024–2048 MB** |
| Network | Adapter 1 **NAT** |
| ISO | `out/luna-0.3.0-aarch64.iso` |

**Login:** `luna` или `root`, пароль пустой (Enter). После входа — MOTD и prompt `◐ luna:…$`.

## Проверка образа

### Фаза 1 — сеть и пакеты

```sh
ip addr
curl -I https://example.com
apk update && apk add mc    # без ошибок index not found
htop                        # предустановлен
sudo id
git clone https://github.com/user/repo.git   # проверено в VB
```

### Фаза 2 — брендинг

```sh
cat /etc/luna-release       # LUNA_VERSION=0.3.0
luna-help                   # quick reference
```

Login banner (рамка `L U N A`) — на экране **до** ввода логина. Подробнее: [user-experience.md](user-experience.md).

## Отладка

| Симптом | Решение |
|---------|---------|
| `Network unreachable` | NAT в VB, пересобери ISO с `network-dhcp.start` |
| `package mentioned in index not found` | Старый ISO или локальный+CDN repos; нужен `setup-apkrepos` (замена на CDN) |
| `apk update` → v3.20.10 | Неверный URL; CDN использует `v3.20` |
| Login `luna` fail | ISO 0.1.0; нужен ≥ 0.2.0 |
| `persistent-storage: not found` | Косметика при mdev coldplug; на работу не влияет |
| ping fail, curl ok | ICMP блокируется NAT — нормально |

## QEMU

```bash
./scripts/test-qemu.sh aarch64
```
