# Документация Luna

**Текущая версия:** 0.4.0 · фазы 0–3 закрыты (июнь 2026)

| Документ | О чём |
|----------|--------|
| [Видение](vision.md) | Зачем Luna, долгосрочная цель, принципы |
| [Roadmap](roadmap.md) | Этапы от ISO до AI-shell |
| [UI без GNOME](ui-strategy.md) | Terminal / Wayland / Luna Shell |
| [Архитектура](architecture.md) | Boot, dual-arch, apk, overlay |
| [Luna CLI](luna-cli.md) | `luna version`, `status`, `tui`, agent stub |
| [Опыт пользователя](user-experience.md) | Banner, MOTD, prompt, boot |
| [Пакеты по умолчанию](default-packages.md) | Состав образа |
| [Окружение разработки](development-environment.md) | Mac, Docker, VirtualBox, QEMU |
| [Milestone 0](milestone-0.md) | Первый загружаемый ISO |
| [ADR-001](decisions/001-linux-distro-first.md) | Почему Linux-дистрибутив, а не kernel с нуля |
| [Changelog](../CHANGELOG.md) | История версий образа |

## Статус по фазам

| Фаза | Статус | Критерий |
|------|--------|----------|
| 0 — Фундамент | ✅ | ISO грузится, login, shell |
| 1 — Живая система | ✅ | `curl`, `apk add`, `git clone`, SSH |
| 2 — Идентичность | ✅ | Banner, MOTD, prompt |
| 3 — Luna CLI | ✅ | `luna version`, `luna status` |
| 4 — AI-shell | — | После фаз 1–3 |

## Быстрые команды

```bash
docker compose run --rm luna-build-aarch64
# → out/luna-0.4.0-aarch64.iso
```

В VM: `luna` / Enter → `luna status` → `mc` (файлы) → `luna help`
