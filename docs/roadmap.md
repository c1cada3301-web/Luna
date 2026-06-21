# Roadmap

Этапы дают работающий артефакт на каждом шаге.

## Фаза 0 — Фундамент ✅

ISO, Docker-сборка, login в VM. **Июнь 2026**

## Фаза 1 — Живая система ✅

DHCP, online `apk add`, SSH, persist (`LUNA_DATA` → `/mnt/persist`).

## Фаза 2 — Идентичность Luna ✅

Banner, MOTD, prompt, `luna-release`, CHANGELOG.

## Фаза 3 — Luna userspace ✅

CLI `luna`, `luna tui`, OpenRC `luna-agent` stub.

## Фаза 4 — Luna Shell ✅ (UX)

Welcome (`luna`), `luna think`, SSH для dev. **0.5.0**

**Отложено:** LLM, intent → команды, sandbox — не блокирует дистрибутив.

---

## Фаза 5 — Полноценный дистрибутив (в работе)

**Сейчас:** **5.3 bare metal** — linux-lts, firmware, mini-PC.

**Цель:** Luna ставится на диск, переживает reboot, обновляется, работает на реальном железе.

### 5.1 — Установка на диск ✅

| # | Задача | Статус |
|---|--------|--------|
| 1 | `luna install` TUI | ✅ |
| 2 | setup-alpine + overlay Luna | ✅ 0.6.3+ |
| 3 | GRUB EFI aarch64 | ✅ VirtualBox |
| 4 | Один ISO live + install | ✅ |

**Milestone 5.1** — VirtualBox ARM64 + x86_64 VM: install → reboot → `luna status`; E2E `test-install-qemu.sh`.

| # | Задача | Статус |
|---|--------|--------|
| 5 | x86_64 install + boot | ✅ VM |
| 6 | E2E `test-install-qemu.sh` | ✅ |

### 5.2 — Жизненный цикл ✅

| # | Задача | Статус |
|---|--------|--------|
| 1 | Root ext4 на диске | ✅ |
| 2 | CDN apk repos | ✅ |
| 3 | `luna upgrade` (Luna + Alpine) | ✅ 0.8.1 |
| 4 | SSH / `LUNA_MODE=installed` | ✅ |
| 5 | Профили пакетов | ✅ [luna-base.md](luna-base.md) |
| 6 | `apk add` после reboot | ✅ python3 |

**Milestone 5.2** — проверено на установленной VM: upgrade, SSH с Mac, persist. **0.8.1:** self-update с GitHub Releases.

### 5.3 — Bare metal ← **СЕЙЧАС**

| # | Задача | Критерий | Статус |
|---|--------|----------|--------|
| 1 | `linux-lts` на диске | `uname -r` → `*-lts` после install | ✅ 0.8.0 (`-k lts`) |
| 2 | `linux-firmware` | Wi‑Fi/Ethernet на железе | ✅ post-install |
| 3 | README mini-PC | USB, EFI, ошибки | ✅ |
| 4 | Smoke-test mini-PC + x86 VM | install + boot + SSH LAN | ⏳ |

**Milestone 5.3:** Luna с USB на реальном ARM/x86 mini-PC, SSH с Mac по LAN.

### 5.4 — Релизы как продукт ← **в работе**

| # | Задача | Статус |
|---|--------|--------|
| 1 | ISO на GitHub Releases по тегу `v0.x.0` | ✅ workflow + scripts |
| 2 | CHANGELOG + bump `luna-release` в одном ритуале | ✅ `scripts/release.sh` |
| 3 | Канал **stable** (latest release) | ✅ `gh release --latest` |
| 4 | apk-репо `luna-base` | ⏳ фаза 1 ✅ [план](luna-base-apk-repo.md) · runtime фаза 3 |

**Milestone 5.4:** Luna 1.0.0 — Releases, upgrade, bare metal.

**Первый релиз:** `v0.8.0` — `./scripts/release-local.sh` или push tag после merge workflow.

### Порядок работ

```
5.1 ✅ ──► 5.2 ✅ ──► 5.3 ◄── СЕЙЧАС ──► 5.4 releases
```

**Не делаем в фазе 5:** GNOME/KDE, LLM (пока), свой пакетный менеджер, своё ядро.

---

## Что дальше

1. **Mini-PC** smoke-test (5.3.4)
2. **apk-репо `luna-base`** (5.4.4)

### Горизонт

| Версия | Фокус |
|--------|--------|
| **0.8.x** | bare metal validation |
| **0.9.x** | x86_64 smoke, polish post-install |
| **1.0.0** | Releases, stable, без LLM |
