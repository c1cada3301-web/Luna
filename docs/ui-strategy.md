# Стратегия UI: без GNOME, к Luna Shell

Luna — **не десктопный дистрибутив**. Полноценный DE (GNOME, KDE) в roadmap на старте **нет** — см. [vision.md](vision.md). Ниже — варианты интерфейса от «только терминал» до будущего AI-shell и зачем (не) нужен файловый менеджер.

## Что есть сейчас (0.4.0)

| Слой | Реализация |
|------|------------|
| Boot / login | OpenRC + agetty, ASCII banner `/etc/issue` |
| Shell | bash, prompt Luna |
| Обзор системы | `luna status`, `luna version` |
| Простое меню | `luna tui` (bash `select`, **вручную** после login) |
| Файлы в терминале | **`mc`** (Midnight Commander) — уже в образе |
| Удалённый доступ | SSH, `scp`/`rsync` с хоста |

Отдельного «окна входа» или графического TUI при boot **нет** — это одна консоль tty1; agetty очищает экран и показывает banner.

## Зачем (не) нужен GNOME

| | GNOME / KDE | Luna сейчас |
|---|-------------|-------------|
| Размер | +500 MB–1 GB | ~112 MB ISO |
| RAM | 1–2 GB+ комфортно | 512 MB–1 GB достаточно |
| Цель | Универсальный desktop | Агент, скрипты, SSH, live demo |
| Настройка | Много сервисов (dbus, polkit, …) | OpenRC + shell |

**GNOME имеет смысл**, если Luna станет «Linux для обычного пользователя с мышкой». **Не имеет смысла**, если основной сценарий — VM/SSH, автomation и будущий AI-agent.

## Зачем (не) нужен файловый менеджер

| Задача | Решение в Luna |
|--------|----------------|
| Посмотреть дерево файлов | `ls`, `tree`, **`mc`** |
| Скопировать с Mac | SSH, shared folder VirtualBox, `scp` |
| Агент читает/пишет FS | API shell (`cat`, `find`, `cp`) — GUI не нужен |
| «Потыкать мышкой» | GUI-FM только вместе с графической средой |

GUI-FM (`nautilus`, `thunar`) без compositor бесполезен. Для консоли достаточно **`mc`**.

Раскладка и locale: **`setup-keymap ru`** после login (не при boot — иначе `apk add` блокирует OpenRC `local`).

## Три пути развития UI

### Путь A — Terminal-first (текущий, фазы 0–3)

```
GRUB → OpenRC → login banner → bash → luna / mc / apk
```

- Минимальный образ, быстрый boot
- Всё через CLI и SSH
- **Рекомендуется** до стабилизации agent runtime

### Путь B — Лёгкая графика (опциональный milestone)

Минимальный стек без GNOME:

```
Wayland compositor (sway / labwc / cage)
  + терминал (foot / alacritty)
  + опционально wmenu / rofi
```

| Плюсы | Минусы |
|-------|--------|
| Окна, несколько терминалов | +100–200 MB, драйверы/шрифты |
| Близко к «настоящему desktop» | Сложнее live ISO и отладка в VB |
| Можно запускать браузер (`apk add firefox`) | Не цель Luna 0.x |

Подходит как **эксперимент** (`experiments/wayland/`), не как default ISO.

### Путь C — Luna Shell (фаза 4+, целевой)

```
┌─────────────────────────────────────┐
│  Luna Shell — intent → action       │  чат / команды / подтверждения
├─────────────────────────────────────┤
│  Agent runtime (luna-agent)         │  LLM local или API
├─────────────────────────────────────┤
│  Compositor (минимальный или TUI)     │  не обязательно GNOME
├─────────────────────────────────────┤
│  OpenRC + Alpine userspace          │
└─────────────────────────────────────┘
```

Примеры intent:

- «покажи статус сети» → `luna status` / `ip addr`
- «найди большие файлы в /var» → `find …`
- «открой редактор» → `vim` / `nano` / терминал с foot

**Compositor** здесь — транспорт для UI shell, не клон GNOME Settings.

## Сравнение вариантов

| Критерий | A Terminal | B Wayland minimal | C Luna Shell |
|----------|------------|-------------------|--------------|
| Размер ISO | ✅ маленький | ⚠️ средний | ⚠️ зависит от LLM |
| Boot в VB | ✅ проверено | ⚠️ нужна отладка | 🔮 фаза 4 |
| AI-native UX | через CLI | через терминал | ✅ основная идея |
| Файлы «мышкой» | mc | mc + опционально GUI-FM | intent → команда |

## Рекомендация для репозитория

1. **Default ISO** — путь A (как сейчас).
2. **Не добавлять GNOME** в основной образ без отдельного решения ADR.
3. **Файлы** — документировать `mc`; GUI-FM не включать.
4. **Фаза 4** — проектировать Luna Shell поверх терминала или лёгкого compositor, не портировать GNOME.

## Связанные документы

- [vision.md](vision.md) — долгосрочная цель
- [roadmap.md](roadmap.md) — фаза 4 AI-shell
- [user-experience.md](user-experience.md) — login, MOTD, prompt
- [default-packages.md](default-packages.md) — `mc`, locale
