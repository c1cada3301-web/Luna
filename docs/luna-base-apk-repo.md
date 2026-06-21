# План: apk-репо `luna-base` (5.4.4)

Цель — упаковать Luna userspace как подписанный Alpine-пакет и обновлять его через `apk`, без отдельного `curl` + tar.gz.

**Критерий готовности:** на установленной системе `sudo luna upgrade` (или `apk upgrade luna-base`) поднимает Luna release до версии из GitHub Releases; `apk info luna-base` показывает актуальный pkgver.

---

## Что уже есть

| Компонент | Где | Зачем |
|-----------|-----|--------|
| Overlay userspace | `overlay/usr`, `overlay/etc/…` | CLI, scripts, motd |
| Список файлов | `scripts/bundle-userspace.sh`, `luna-install.sh` | Единый manifest |
| Ключ подписи | `build/keys/luna-repo.rsa` | CI secret `LUNA_REPO_RSA` |
| Публичный ключ в ISO | `overlay/etc/apk/keys/luna@local.rsa.pub` | `apk` доверяет Luna repo |
| Подпись APKINDEX | `build/build-iso.sh` | Boot-репо на ISO (все пакеты rootfs) |
| Self-update | `luna-self-update.sh` + userspace tar.gz | Временный канал до `luna-base` |

Boot-репо на ISO — **не то же самое**, что online `luna-base`: на ISO лежат все Alpine-пакеты rootfs; `luna-base` — один metapackage только с Luna overlay.

---

## Архитектура

```
overlay/                    ──►  packages/luna-base/APKBUILD
                                      │
scripts/build-apk-repo.sh   ◄─────────┘  abuild → .apk
                                      │
                              repo/$ALPINE_VER/$ARCH/
                                ├── luna-base-0.8.3-r0.apk
                                └── APKINDEX.tar.gz  (signed)
                                      │
                              luna-0.8.3-apk-repo-aarch64.tar.gz
                                      │
GitHub Releases             ◄─────────┘
                                      │
Установленная система       ◄── extract → /var/lib/luna/apk-repo/$ARCH
                                /etc/apk/repositories += file://…
                                apk upgrade luna-base
```

### Почему `file://`, а не HTTP

GitHub Releases не отдаёт каталог как apk-репозиторий (нужны `APKINDEX.tar.gz` + `.apk` по одному base URL).

Для **личного** дистрибутива достаточно:

1. Скачать `luna-*-apk-repo-$ARCH.tar.gz` с Releases  
2. Распаковать в `/var/lib/luna/apk-repo/$ARCH`  
3. Строка в repos: `/var/lib/luna/apk-repo/aarch64`

HTTP (GitHub Pages) — опциональная фаза B, если понадобится `apk update` без скачивания tarball.

---

## Фаза 1 — APKBUILD и локальная сборка

### 1.1 Дерево `packages/luna-base/`

```
packages/luna-base/
├── APKBUILD
└── luna-base.post-install   # chmod +x, опционально
```

**APKBUILD (скелет):**

```bash
pkgname=luna-base
pkgver=0.8.3          # из overlay/etc/luna-release при сборке
pkgrel=0
pkgdesc="Luna OS userspace (CLI, scripts, branding)"
url="https://github.com/c1cada3301-web/Luna"
arch="noarch"         # только конфиги и shell; один apk на все CPU
license="MIT"
depends="bash"
install=luna-base.post-install
options="!strip !check"

# source — не tarball: файлы копируются из $startdir/../../overlay в package()
```

`pkgver` подставлять в CI скриптом (`sed` по `luna-release`), не коммитить руками каждый раз.

**`package()`** — тот же manifest, что в `bundle-userspace.sh`:

- `usr/local/bin/luna`, `luna-help`
- `usr/share/luna/`
- `etc/profile.d/luna-*.sh`, `etc/init.d/luna-agent`
- `etc/local.d/{network-dhcp,setup-apkrepos,mount-persist}.start`
- `etc/luna/locale.conf`, `etc/luna-release`, `etc/motd`, `etc/issue`

**Не включать** в пакет (user/local state):

- `etc/network/interfaces`
- пароли, `LUNA_MODE=installed` — post-install / `preserve_installed_mode`

**`luna-base.post-install`:**

```sh
chmod +x /usr/local/bin/luna /usr/local/bin/luna-help 2>/dev/null || true
chmod +x /usr/share/luna/*.sh /etc/local.d/*.start /etc/init.d/luna-agent 2>/dev/null || true
```

### 1.2 `scripts/build-apk-repo.sh`

```bash
docker compose run --rm luna-build-aarch64 ./scripts/build-apk-repo.sh
# → out/luna-${VERSION}-apk-repo.tar.gz
```

Структура tarball (распаковать в `/var/lib/luna/apk-repo`):

```
noarch/luna-base-VERSION-r0.apk
noarch/APKINDEX.tar.gz
aarch64/APKINDEX.tar.gz   # пустой stub (apk на aarch64 ищет $ARCH/APKINDEX)
x86_64/APKINDEX.tar.gz    # то же для x86_64
```

`/etc/apk/repositories`:

```
/var/lib/luna/apk-repo
```

**Фаза 1 (сейчас):** установка напрямую из `.apk` (репо-index доработаем в фазе 3):

```sh
tar xzf luna-0.8.3-apk-repo.tar.gz -C /var/lib/luna/apk-repo
sudo apk add --force-overwrite --allow-untrusted \
  /var/lib/luna/apk-repo/noarch/luna-base-*.apk
apk info luna-base   # → 0.8.3-r0
command -v luna      # → /usr/bin/luna
```

Примечания:

- Пакет кладёт бинарники в **`/usr/bin`** (Alpine запрещает `/usr/local` в apk)
- `--force-overwrite` — для `etc/motd`, `etc/issue` (конфликт с alpine-baselayout)
- `--allow-untrusted` — пока имя pubkey не совпадает с fingerprint подписи abuild (исправим в фазе 3)

**Локальная проверка:**

```bash
docker compose run --rm luna-build-aarch64 ./scripts/build-apk-repo.sh
# на VM после ручной установки repo:
# apk update && apk add luna-base
```

---

## Фаза 2 — CI и Releases

### 2.1 Изменения `.github/workflows/release.yml`

В job `publish`, после `bundle-userspace.sh`:

```yaml
- name: APK repo (luna-base)
  run: |
    chmod +x scripts/build-apk-repo.sh
    ./scripts/build-apk-repo.sh release-assets
```

Артефакты релиза:

| Файл | Назначение |
|------|------------|
| `luna-*-aarch64.iso` | live + install |
| `luna-*-x86_64.iso` | … |
| `luna-*-userspace.tar.gz` | **legacy** — убран из Releases в 0.9.0; fallback в self-update |
| `luna-*-apk-repo.tar.gz` | **новый** — signed repo |
| `SHA256SUMS` | все файлы |

`build-apk-repo.sh` один раз (noarch); не нужен per-arch, если пакет `noarch`.

### 2.2 SHA256SUMS

Добавить `luna-*-apk-repo.tar.gz` в `sha256sum luna-*`.

---

## Фаза 3 — Runtime на установленной системе

### 3.1 `_ensure_luna_apk_repo()` в `luna` / `luna-self-update.sh`

```sh
LUNA_APK_REPO="/var/lib/luna/apk-repo/noarch"
# 1. Если apk index свежий и luna-base установлен — skip
# 2. Скачать luna-${latest}-apk-repo.tar.gz с GitHub Releases
# 3. rm -rf "$LUNA_APK_REPO" && mkdir -p /var/lib/luna/apk-repo
# 4. tar xzf … -C /var/lib/luna/apk-repo
# 5. Добавить в /etc/apk/repositories (если нет):
#    /var/lib/luna/apk-repo/v3.20/noarch
```

Alpine CDN repos не трогаем — `_ensure_cdn_repos` как сейчас.

### 3.2 `luna upgrade` — новый порядок

```
1. _ensure_cdn_repos
2. _ensure_luna_apk_repo          # скачать/распаковать repo
3. apk update
4. apk upgrade luna-base          # Luna userspace
5. apk upgrade                    # остальной Alpine
```

`luna-self-update.sh`: сначала пробовать apk-путь; если нет `luna-base` в repo — fallback на userspace tar.gz (обратная совместимость 0.8.x).

### 3.3 Post-install (`luna-install.sh`)

После CDN repos:

```sh
# Установить начальный luna-base с live-системы или скачать repo
# Вариант A: apk add из file repo, скопированного с live overlay при install
# Вариант B: curl apk-repo tarball в chroot (нужна сеть)
```

Проще **Вариант A** на install: на live ISO уже есть `luna-base` APK в `/usr/share/luna/apk-repo/` (кладём при сборке ISO).

### 3.4 `setup-apkrepos.start`

Добавить строку Luna repo **после** CDN:

```
https://dl-cdn.alpinelinux.org/alpine/v3.20/main
https://dl-cdn.alpinelinux.org/alpine/v3.20/community
/var/lib/luna/apk-repo/v3.20/noarch
```

---

## Фаза 4 — ISO и live

### 4.1 Включить `luna-base` в rootfs

В `build-rootfs.sh` или отдельным шагом после overlay:

```bash
./scripts/build-apk-repo.sh /tmp/luna-repo-out
# apk add --allow-untrusted или с ключом:
apk add --repositories-file … luna-base
```

Либо `apk add ./luna-base-*.apk` локально при сборке rootfs.

### 4.2 Убрать дублирование overlay

Долгосрочно: **единственный источник** userspace — пакет `luna-base`. Overlay в git остаётся source для APKBUILD; в rootfs файлы только через `apk add luna-base`, не копированием.

Переход поэтапный: сначала apk **поверх** overlay (как сейчас), потом рефактор `build-rootfs.sh`.

---

## Фаза 5 — Документация и 1.0.0

| Задача | Файл |
|--------|------|
| Обновить профили пакетов | `docs/luna-base.md` |
| README: upgrade через apk | `README.md` |
| Roadmap 5.4.4 → ✅ | `docs/roadmap.md` |
| CHANGELOG | секция Added/Changed |

**Убрать после 1.0.0:**

- `userspace.tar.gz` из релизов (или оставить как emergency fallback ещё один релиз)

---

## Порядок работ (оценка)

| # | Задача | Сложность | Результат |
|---|--------|-----------|-----------|
| 1 | `packages/luna-base/APKBUILD` + post-install | ✅ |
| 2 | `scripts/build-apk-repo.sh` | ✅ |
| 3 | CI: публикация `apk-repo.tar.gz` | ✅ |
| 4 | `_ensure_luna_apk_repo` + `apk upgrade luna-base` | ✅ |
| 5 | post-install + setup-apkrepos | ✅ |
| 6 | rootfs через `apk add luna-base` | ✅ 0.9.0 |
| 7 | (опц.) GitHub Pages HTTP repo | S | `apk update` без tarball |

**Milestone 5.4.4** закрывается пунктами **1–5**. Пункт 6 — polish к **1.0.0**.

---

## Проверка (acceptance)

На VM после `luna install` + reboot:

```sh
apk info luna-base                    # pkgver = LUNA_VERSION
cat /etc/apk/repositories             # CDN + /var/lib/luna/…
sudo luna upgrade                     # без tar.gz, через apk
luna status                           # версия совпадает с latest release
```

На системе **0.8.3 без luna-base**:

```sh
sudo luna upgrade   # скачивает apk-repo tarball, ставит luna-base, дальше только apk
```

---

## Риски

| Риск | Митигация |
|------|-----------|
| Ключ CI ≠ ключ в старых ISO | Один `LUNA_REPO_RSA`; не ротировать без bump major |
| `noarch` vs `$ARCH` | Использовать `noarch` — один repo tarball |
| Конфликт tar.gz и apk | apk приоритет; tar.gz fallback один релиз |
| Нет сети на install | Копировать repo с live ISO в chroot |

---

## Связь с «полноценным личным дистрибутивом»

После **5.4.4** + **5.3.4** (mini-PC smoke):

- install / reboot / upgrade — **один инструмент** (`apk` + `luna`)
- релизы на GitHub — ISO + signed repo
- формально готов к тегу **1.0.0**

LLM, desktop и своё ядро остаются за scope фазы 5.
