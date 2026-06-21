# Luna package profiles

## Live ISO (`build/packages.txt`)

Пакеты в образе для demo и `luna install`. Ядро: **linux-virt** (быстрый boot в VM).

| Категория | Пакеты |
|-----------|--------|
| Shell | bash, nano, vim, mc, htop |
| Сеть / dev | curl, wget, git, openssh, sudo, util-linux, e2fsprogs |
| Locale | musl-locales, musl-locales-lang, kbd-bkeymaps |

Базовые: `alpine-base`, `alpine-conf`, `openrc`, `linux-virt`, `mkinitfs` — в `build-rootfs.sh`.

## Disk install (`usr/share/luna/packages-install.txt`)

Дополнительно ставятся в post-install на целевой системе:

| Пакет | Зачем |
|-------|--------|
| `linux-firmware` | Wi‑Fi / Ethernet на реальном железе |

## Ядро на диске

По умолчанию `luna install` вызывает `setup-disk -k lts` → **linux-lts** на установленной системе.

Live ISO остаётся на **linux-virt**; на диск попадает LTS-профиль для bare metal.

Для установки только в VM (меньше размер):

```sh
export LUNA_INSTALL_KERNEL=virt
sudo luna install
```

## Luna OS vs Alpine packages

| | Обновление |
|---|-----------|
| Alpine (`python3`, kernel, …) | `sudo luna upgrade` / `apk upgrade` |
| Luna release (CLI, scripts, motd) | `sudo luna upgrade` — `luna-base` apk (0.8.4+) или userspace tar.gz |

## Будущее (5.4)

Metapackage **`luna-base`** в своём подписанном apk-репозитории — один `apk upgrade luna-base` для Luna userspace.

**План реализации:** [luna-base-apk-repo.md](luna-base-apk-repo.md) — APKBUILD, CI, `file://` repo, интеграция в `luna upgrade`.
