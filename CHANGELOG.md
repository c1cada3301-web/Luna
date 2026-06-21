# Changelog

Формат: [Keep a Changelog](https://keepachangelog.com/). Версия образа — `overlay/etc/luna-release`.

## [0.4.0] — 2026-06-21

### Added

- CLI `luna`: `version`, `status`, `help`, `tui`
- OpenRC stub `luna-agent` (не в default runlevel)
- [docs/luna-cli.md](docs/luna-cli.md), [docs/ui-strategy.md](docs/ui-strategy.md)
- `usr/` в `localhost.apkovl.tar.gz` — CLI доступен после diskless boot
- `musl-locales`, `musl-locales-lang`, `kbd-bkeymaps`
- `/etc/luna/locale.conf`, `/etc/profile.d/luna-locale.sh` (LANG в shell)
- SSH host keys генерируются при сборке rootfs

### Changed

- `luna-help` делегирует в `luna help`
- MOTD короче; login banner с рамкой ASCII (`/etc/issue`)
- agetty **без** `--noclear` — чистый экран перед login (scrollback OpenRC в истории tty)

### Fixed

- Boot зависал на `Starting local ...` — удалён `luna-locale.start` с `setup-keymap` при boot (`setup-keymap` вызывает `apk add` до DHCP/CDN)
- Восстановлены boot-скрипты `network-dhcp.start` и `setup-apkrepos.start` как в 0.3.0
- `luna: command not found` — в apkovl раньше был только `etc/`, без `usr/local/bin/luna`
- Откат экспериментов с `mkinitfs` stub / `linux-virt --no-deps` / `--no-scripts` — ломали init или apk
- Ошибки `loadkmap` при boot — убран принудительный `loadkmap` в boot runlevel; раскладка: `setup-keymap us` после login

### Verified

- VirtualBox ARM64: login, `luna status`, `curl`, `apk add`, `git clone`

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
