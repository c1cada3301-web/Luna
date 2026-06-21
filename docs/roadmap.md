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

## Фаза 4 — Luna Shell (в работе)

Welcome (`luna`), `luna think`, SSH для dev. Дальше: LLM, intent → команды, sandbox.

**0.5.0** · июнь 2026

## Фаза 5 — Полноценный дистрибутив

Сейчас Luna — live ISO в RAM. Чтобы стать полноценным дистрибутивом: установка на диск (`luna install` поверх setup-alpine), root на SSD с сохранением пакетов и конфигов после reboot, ядро и firmware под bare metal, версионированные релизы и обновления через `apk` — без GNOME, agent-first как в фазе 4.
