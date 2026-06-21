# Changelog

Формат: [Keep a Changelog](https://keepachangelog.com/). Версия образа — `overlay/etc/luna-release`.

## [0.3.0] — 2026-06-21

### Added

- Login banner и MOTD в стиле Luna
- Кастомный bash-prompt (`/etc/profile.d/luna-prompt.sh`)
- `luna-help` и `/usr/share/luna/welcome.txt` на системе
- Документ [default-packages.md](docs/default-packages.md)
- Версия ISO читается из `overlay/etc/luna-release` при сборке

### Changed

- Фаза 2 roadmap: идентичность Luna (не «голый Alpine»)

### Verified

- VirtualBox ARM64: login banner, MOTD, prompt, `git clone`, `apk add`

## [0.2.0] — 2026-06-21

### Added

- DHCP (`network-dhcp.start`), online `apk add` через CDN после boot
- Пользователь `luna` + sudo, OpenSSH
- Пакеты: curl, wget, git, vim, sudo, openssh, e2fsprogs, htop, mc
- Persist-диск `LUNA_DATA` → `/mnt/persist`

### Fixed

- Initramfs без CDN (`--no-network`, `ip=off`)
- `persistent-storage: not found` (mdev `@` вместо `*`)
- `mkinitfs -i` для пропатченного init

## [0.1.0] — 2026-06-21

### Added

- Первый загрузочный ISO (aarch64 UEFI + x86_64 BIOS)
- Diskless live boot, локальный подписанный APK-репо на ISO
- Docker Compose dual-arch, VirtualBox / QEMU
