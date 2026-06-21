# Changelog

Формат: [Keep a Changelog](https://keepachangelog.com/). Версия образа — `overlay/etc/luna-release`.

## [0.9.4] — 2026-06-21

### Fixed

- **`setup-apkrepos.start`:** `command -v` не видит shell-функции в ash — bundled repo не поднимался при boot
- **`luna install`:** `prepare_live_for_setup_alpine` — repo + `apk update`, repair `luna-base` из local, strip world, die если world не очистился
- **Rootfs build:** fail если `luna-base` остаётся в world после сборки

## [0.9.3] — 2026-06-21

### Fixed

- **Live boot:** `setup-apkrepos.start` копирует bundled repo в `/var/lib/luna/apk-repo` — apk на live может резолвить `luna-base` без CDN
- **`luna install`:** перед `setup-alpine` — bundled repo + очистка world (`/etc/apk/world`, `/var/lib/apk/world`) + `apk update`

## [0.9.2] — 2026-06-21

### Fixed

- **`luna install`:** `luna-base` в `/etc/apk/world` на live — setup-alpine пытался ставить пакет с CDN на каждом шаге (`no such package: luna-base`). Файлы остаются на ISO; world очищается при сборке rootfs и перед `setup-alpine`.

## [0.9.1] — 2026-06-21

### Fixed

- **ISO build:** `apk fetch` не находил `luna-base` на CDN — копируем `.apk` из bundled repo в boot apks

## [0.9.0] — 2026-06-21

### Added

- **Фаза 4 apk-repo:** rootfs через `apk add luna-base` (`install-luna-base-rootfs.sh`), infra-only overlay
- **Fresh install:** `luna install` → `luna-base` из bundled repo, `/usr/bin/luna`
- **E2E:** `test-install-qemu.sh` проверяет `luna-base` + `/usr/bin/luna` после reboot

### Changed

- **Releases:** убран `userspace.tar.gz` — только ISO + `apk-repo.tar.gz`
- **`luna self-update`:** userspace tar.gz — deprecated fallback

## [0.8.10] — 2026-06-21

### Fixed

- **Self-update:** re-source `luna-apk-repo.sh` после `apk install` (старые функции в памяти снова писали `LUNA_VERSION=luna-base`)
- **`luna upgrade`:** reload scripts после self-update; игнор битого `LUNA_VERSION` без `X.Y.Z`

## [0.8.9] — 2026-06-21

### Fixed

- **Версия Luna:** `apk info -e` возвращает только `luna-base` — парсинг через `apk info luna-base` (`luna-base-0.8.8-r0`)

## [0.8.8] — 2026-06-21

### Added

- **`luna-apk-repo.sh`:** `_ensure_luna_apk_repo`, `apk upgrade luna-base` из file repo
- **`/etc/apk/repositories`:** строка `/var/lib/luna/apk-repo` (setup-apkrepos + upgrade)
- **Live ISO:** bundled apk-repo в `/usr/share/luna/apk-repo`; `luna install` ставит `luna-base` в chroot

### Fixed

- **Подпись apk:** `luna-repo.rsa.pub` (совпадает с `.SIGN.RSA.luna-repo.rsa.pub` в пакете) — index без `--allow-untrusted`
- **`setup-apkrepos.start`:** CDN + Luna repo при boot

## [0.8.7] — 2026-06-21

### Fixed

- **Миграция tar.gz → luna-base apk:** удаление `/usr/local/bin/luna` (PATH отдавал старую копию)
- **`/etc/luna-release`:** явная синхронизация `LUNA_VERSION` из `apk info luna-base` после установки
- **`LUNA_MODE=installed`:** сохраняется до `apk add`, а не после (когда пакет уже перезаписал файл)

## [0.8.6] — 2026-06-21

### Fixed

- **CI release:** `mv` apk-repo tarball — файлы в `out/` от root в Docker, runner без `sudo chown` не мог их переместить

## [0.8.5] — 2026-06-21

### Fixed

- **`luna self-update`:** `tmpdir: unbound variable` — RETURN trap с `set -u` (literal path + явный cleanup)
- **CI release:** `luna-*-apk-repo.tar.gz` не попадал в GitHub Release (сборка в контейнере писала в немounted `release-assets/`)

## [0.8.4] — 2026-06-21

### Added

- **`luna-base`** metapackage: `packages/luna-base/APKBUILD`, `scripts/build-apk-repo.sh`
- Release asset `luna-*-apk-repo.tar.gz` (CI + Docker build)
- **`luna upgrade` / self-update:** prefer `luna-base` apk from GitHub; fallback userspace tar.gz

### Changed

- `luna upgrade`: CDN repos before Luna self-update
- [docs/luna-base-apk-repo.md](docs/luna-base-apk-repo.md) — plan + фаза 1

## [0.8.3] — 2026-06-21

### Fixed

- **`luna self-update`:** парсинг однострочного JSON GitHub — `tag_name` и `browser_download_url` больше не путаются с `"url"`
- Запросы к GitHub API с `User-Agent: Luna/VERSION`

## [0.8.2] — 2026-06-21

### Fixed

- **`_ensure_cdn_repos`:** `${VERSION_ID%%.*}` обрезал `3.20` до `3` — заменено на `%.*` (как в `setup-apkrepos.start`)
- Повторный `luna upgrade` перезаписывает CDN repos, если версия в URL неверная (например `v3/` вместо `v3.20/`)
- **`luna-install.sh`:** та же ошибка в post-install chroot
- **`luna self-update`:** подсказки при отсутствии `curl` или `ca-certificates`
- **`packages-install.txt`:** `curl`, `ca-certificates` на диске (bare metal)

## [0.8.1] — 2026-06-21

### Added

- **`luna upgrade`** — одна команда: Luna release с GitHub Releases + `apk upgrade`
- **`luna self-update`** — только userspace (CLI, scripts, motd) с GitHub
- `luna-VERSION-userspace.tar.gz` в релизах; `scripts/bundle-userspace.sh`
- `overlay/usr/share/luna/luna-self-update.sh` — API GitHub, сохранение `LUNA_MODE=installed`

### Changed

- Релизный workflow и `release-local.sh` публикуют userspace bundle
- README: `sudo luna upgrade` обновляет и Luna, и Alpine

## [0.8.0] — 2026-06-21

### Added

- **Bare-metal install profile:** `setup-disk -k lts`, post-install `linux-firmware`
- `usr/share/luna/packages-install.txt` — extra packages на диск
- [docs/luna-base.md](docs/luna-base.md) — live vs install, `LUNA_INSTALL_KERNEL`
- README: установка на mini-PC (USB, EFI, типичные ошибки)

### Changed

- Фаза **5.3** (bare metal); фаза 4 LLM — отложена
- `luna upgrade`: пояснение Luna release vs Alpine packages; dedupe http repos

### Verified

- VirtualBox ARM64: `luna install` → reboot → `luna status` (`boot: installed (disk)`)
- 5.2: SSH, python3 persist, `luna upgrade`

## [0.7.0] — 2026-06-21

### Added

- **`luna upgrade`** — `apk update` + `apk upgrade`, CDN repos, версия Luna до/после
- Предупреждение на live ISO: апдейты не сохраняются после reboot
- Пункт «Upgrade (root)» в `luna tui`

### Changed

- Фаза **5.2** (lifecycle): первый шаг — upgrade с диска

## [0.6.4] — 2026-06-21

### Fixed

- **post-install**: пароли через temp-файлы — `chpasswd: missing new password` при `$`, `:`, `\` в пароле
- Проверка: оба пароля непустые до установки

## [0.6.3] — 2026-06-21

### Fixed

- **post-install**: `passwd -stdin` не существует в Alpine → `chpasswd`
- **post-install**: копирование `/usr/local/bin/luna` и `/usr/share/luna` на диск (lbu их не включает)

## [0.6.2] — 2026-06-21

### Fixed

- **`luna install`**: `dev: unbound variable` — bash `local dev=... ${dev#...}` на одной строке с `set -u`
- Сообщение «no disks» показывает `/sys/block` для диагностики

## [0.6.1] — 2026-06-21

### Fixed

- **`luna install`**: `lsblk` not found — добавлен `util-linux`, авто `apk add`, fallback через `/sys/block`
- QEMU test script: `-cpu max` вместо `cortex-a72`

## [0.6.0] — 2026-06-21

### Added

- **`luna install`** — TUI установки на диск из live ISO (фаза 5.1)
- `luna-install.sh`: выбор диска, hostname, пароли root/luna, обёртка `setup-alpine`
- Post-install: CDN `apk` repos, SSH без пустых паролей, `LUNA_MODE=installed`
- `luna status` — строка `boot: live (ISO) | installed (disk)`
- Пункт «Install to disk» в `luna tui`

### Changed

- Фаза **5** (install на диск); фаза 4 (Shell UX) продолжается параллельно
- Login banner / MOTD: подсказка `sudo luna install`

## [0.5.0] — 2026-06-21

### Added

- **Luna Shell welcome** — `luna` без аргументов → карточка с 🌙 (Claude-style)
- `luna think [sec]` — анимация фаз 🌙 ◐ ◑ ◒
- `welcome-screen.sh`, `thinking.sh` в `/usr/share/luna/`
- SSH: `PermitEmptyPasswords` для dev-VM (`sshd_config.d/luna.conf`)
- Login banner: 🌙 Luna 0.5.0 (`/etc/issue`)

### Changed

- `luna status` — заголовок с 🌙 и uptime
- `luna tui` — пункт «Think (demo)»
- Фаза **4** (начало Luna Shell UX); agent по-прежнему stub
- Документация: SSH port forward, JetBrains Mono

### Fixed

- Welcome-screen: убран `tput dim/bold` — дубли строк в SSH/iTerm

### Verified

- VirtualBox ARM64 + SSH `2222→22`: welcome, think, status (JetBrains Mono)

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
