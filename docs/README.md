# Документация Luna

**Текущая версия:** 0.3.0 · фазы 0–2 закрыты (июнь 2026)

| Документ | О чём |
|----------|--------|
| [Видение](vision.md) | Зачем Luna, долгосрочная цель, принципы |
| [Roadmap](roadmap.md) | Этапы от ISO до AI-shell |
| [Архитектура](architecture.md) | Boot, dual-arch, apk, overlay |
| [Опыт пользователя](user-experience.md) | Что видно при загрузке и login |
| [Пакеты по умолчанию](default-packages.md) | Состав образа 0.3.0 |
| [Окружение разработки](development-environment.md) | Mac, Docker, VirtualBox, QEMU |
| [Milestone 0](milestone-0.md) | Первый загружаемый ISO |
| [ADR-001](decisions/001-linux-distro-first.md) | Почему Linux-дистрибутив, а не kernel с нуля |
| [Changelog](../CHANGELOG.md) | История версий образа |

## Статус по фазам

| Фаза | Статус | Критерий |
|------|--------|----------|
| 0 — Фундамент | ✅ | ISO грузится, login, shell |
| 1 — Живая система | ✅ | `curl`, `apk add`, `git clone`, SSH |
| 2 — Идентичность | ✅ | Banner, MOTD, prompt, `luna-help` |
| 3 — Luna CLI | 🔜 | `luna version`, `luna status` |
| 4 — AI-shell | — | После фаз 1–3 |

## Быстрые команды

```bash
docker compose run --rm luna-build-aarch64
# → out/luna-0.3.0-aarch64.iso
```

В VM: `luna` / Enter → `luna-help` → `cat /etc/luna-release`
