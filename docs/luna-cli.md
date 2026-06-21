# Luna CLI

Утилита **`luna`** — Luna Shell (фаза 4). Shell-скрипт, без зависимостей кроме стандартных Alpine-утилит.

## Команды

| Команда | Описание |
|---------|----------|
| `luna` | **Welcome-screen** 🌙 (Claude-style card) |
| `luna version` | Версия Luna, фаза, база Alpine, kernel, arch |
| `luna status` | Uptime, память, сеть, persist, agent, sshd, пакеты |
| `luna think [sec]` | Анимация 🌙 ◐ ◑ ◒ (default 5s, `0` = до Ctrl+C) |
| `luna help` | Список команд |
| `luna tui` | Интерактивное меню (bash `select`) |

Сокращения: `luna -v`, `luna -h`.

**Legacy:** `luna-help` → `luna help`.

## SSH с Mac (VM запущена)

```text
VirtualBox NAT: Host 2222 → Guest 22
ssh -p 2222 luna@127.0.0.1
```

Шрифт iTerm: JetBrains Mono 15 — как в Cursor. См. [development-environment.md](development-environment.md).

## Примеры

```sh
luna:~$ luna
# welcome card …

luna:~$ luna status
🌙 Luna 0.5.0 · luna · 0h 12m
  memory:   89M used / 1.7G total
  …

luna:~$ luna think 3
  ◑  thinking…
```

## Luna agent (OpenRC stub)

Сервис **`luna-agent`** — заглушка под AI-shell. **Не** в default runlevel.

```sh
sudo rc-service luna-agent start
sudo rc-service luna-agent status
```

## Файлы в репозитории

| Путь | Назначение |
|------|------------|
| `overlay/usr/local/bin/luna` | CLI entry point |
| `overlay/usr/share/luna/welcome-screen.sh` | Welcome card |
| `overlay/usr/share/luna/thinking.sh` | Phase animation |
| `overlay/usr/share/luna/luna-tui.sh` | TUI menu |
| `overlay/etc/init.d/luna-agent` | OpenRC stub |
| `overlay/etc/ssh/sshd_config.d/luna.conf` | Empty password SSH (dev) |

## Дальше (фаза 4)

- Agent runtime вместо stub
- `luna ask "…"` → intent → shell с подтверждением

Эскиз UI: [luna-shell-tui-sketch.txt](luna-shell-tui-sketch.txt)
