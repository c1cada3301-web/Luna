# Luna CLI

Утилита **`luna`** — первый собственный userspace Luna (фаза 3). Shell-скрипт, без зависимостей кроме стандартных Alpine-утилит.

## Команды

| Команда | Описание |
|---------|----------|
| `luna` | То же, что `luna help` |
| `luna version` | Версия Luna, фаза, база Alpine, kernel, arch |
| `luna status` | Uptime, память, сеть, persist, agent, sshd, число пакетов |
| `luna help` | Список команд |
| `luna tui` | Простое интерактивное меню (bash `select`) |

Сокращения: `luna -v`, `luna -h`.

**Legacy:** `luna-help` → вызывает `luna help`.

## Примеры

```sh
luna:~$ luna version
Luna 0.4.0
  phase:  3
  base:   Alpine 3.20
  kernel: 6.6.142-0-virt
  arch:   aarch64

luna:~$ luna status
◐ Luna 0.4.0 · luna
  uptime:   0h 12m
  memory:   89M used / 1.7G total
  network:
  eth0  10.0.2.15/24
  persist:  not configured
  agent:    stopped (stub)
  sshd:     running
  packages: 84 installed
```

## Luna agent (OpenRC stub)

Сервис **`luna-agent`** — заглушка под AI-shell (фаза 4). **Не** включён в default runlevel.

```sh
sudo rc-service luna-agent start
sudo rc-service luna-agent status
sudo rc-service luna-agent stop
```

При `start` создаётся `/run/luna/agent.stub` с меткой времени — без фоновых процессов и сетевых вызовов.

## Файлы в репозитории

| Путь | Назначение |
|------|------------|
| `overlay/usr/local/bin/luna` | CLI entry point |
| `overlay/usr/share/luna/luna-tui.sh` | TUI menu |
| `overlay/etc/init.d/luna-agent` | OpenRC stub |

## TUI

`luna tui` — опциональное меню **после login** (не autostart). Для файлов используй **`mc`**.

## UI и desktop

GNOME не входит в roadmap default ISO. Варианты развития: [ui-strategy.md](ui-strategy.md).

## Дальше (фаза 4)

- Заменить stub на agent runtime
- `luna ask "…"` → intent → shell с подтверждением
- Переписать CLI на Rust/Go — опционально, когда стабилизируется API
