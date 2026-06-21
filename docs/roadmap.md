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

**Milestone 5.1** — VirtualBox ARM64: install → reboot → `luna status`.

| # | Задача | Статус |
|---|--------|--------|
| 5 | x86_64 install + boot | ⏳ |
| 6 | E2E `test-install-qemu.sh` | ⏳ |

### 5.2 — Жизненный цикл ✅

| # | Задача | Статус |
|---|--------|--------|
| 1 | Root ext4 на диске | ✅ |
| 2 | CDN apk repos | ✅ |
| 3 | `luna upgrade` | ✅ 0.7.0 |
| 4 | SSH / `LUNA_MODE=installed` | ✅ |
| 5 | Профили пакетов | ✅ [luna-base.md](luna-base.md) |
| 6 | `apk add` после reboot | ✅ python3 |

**Milestone 5.2** — проверено на установленной VM: upgrade, SSH с Mac, persist.

### 5.3 — Bare metal ← **СЕЙЧАС**

| # | Задача | Критерий | Статус |
|---|--------|----------|--------|
| 1 | `linux-lts` на диске | `uname -r` → `*-lts` после install | ✅ 0.8.0 (`-k lts`) |
| 2 | `linux-firmware` | Wi‑Fi/Ethernet на железе | ✅ post-install |
| 3 | README mini-PC | USB, EFI, ошибки | ✅ |
| 4 | Smoke-test mini-PC + x86 VM | install + boot + SSH LAN | ⏳ |

**Milestone 5.3:** Luna с USB на реальном ARM/x86 mini-PC, SSH с Mac по LAN.

### 5.4 — Релизы как продукт

| # | Задача | Статус |
|---|--------|--------|
| 1 | ISO на GitHub Releases | ⏳ |
| 2 | CHANGELOG + bump ритуал | 🔄 |
| 3 | Канал stable / beta | ⏳ |
| 4 | apk-репо `luna-base` | ⏳ |

**Milestone 5.4:** Luna 1.0.0 — Releases, upgrade, bare metal, agent stub.

### Порядок работ

```
5.1 ✅ ──► 5.2 ✅ ──► 5.3 ◄── СЕЙЧАС ──► 5.4 releases
```

**Не делаем в фазе 5:** GNOME/KDE, LLM (пока), свой пакетный менеджер, своё ядро.

---

## Что дальше

1. **Smoke-test 0.8.0** — чистый `luna install` → `uname -r` содержит `lts`, `apk info linux-firmware`
2. **Mini-PC** — USB install, SSH по LAN (закрывает 5.3.4)
3. **x86_64** — QEMU/Intel VM install+boot
4. **5.4** — GitHub Release `v0.8.0`, тег, `.iso` артефакт

### Горизонт

| Версия | Фокус |
|--------|--------|
| **0.8.x** | bare metal validation |
| **0.9.x** | x86_64 smoke, polish post-install |
| **1.0.0** | Releases, stable, без LLM |
