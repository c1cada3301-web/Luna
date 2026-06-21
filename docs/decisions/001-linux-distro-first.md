# ADR-001: начинаем с Linux-дистрибутива, а не с kernel с нуля

**Статус:** принято  
**Дата:** 2025-06-21  
**Контекст:** выбор первого подхода к проекту Luna

## Решение

Строим **собственный Linux-дистрибутив** на базе Alpine Linux. Kernel и bootloader берём из экосистемы Alpine; кастомизируем rootfs, конфигурацию, branding и userspace.

Собственное ядро с нуля — **отложено** в optional track (OSDev), не блокирует продукт.

## Обоснование

### Почему не kernel с нуля (сейчас)

- До «терминал + клавиатура + базовая FS» — месяцы работы
- Сеть, USB, GPU, файловые системы — ещё месяцы
- Цель «базовый функционал» и «быстрый первый результат» не совместимы с greenfield kernel

### Почему дистрибутив

- Первый загружаемый ISO — дни/недели
- Сразу получаем сеть, storage, package manager (после фазы 1)
- Долгосрочная vision (AI shell) живёт в **userspace** — дистрибутив даёт правильный фундамент

### Почему Alpine

- Минимальный размер и простая структура
- OpenRC проще для понимания, чем full systemd stack
- Официальные инструменты для live/image (`mkimage`, `apk`)
- Активная документация: [Alpine Developer Documentation](https://wiki.alpinelinux.org/wiki/Developer_Documentation)

## Альтернативы

| Вариант | Плюсы | Минусы |
|---------|-------|--------|
| Debian + debootstrap | Огромная экосystema `.deb` | Тяжелее, systemd |
| NixOS | Декларативность | Крутая learning curve |
| Kernel с нуля | Полный контроль | Не «быстрый результат» |
| Fedora remix | Современный desktop | Избыточно для minimal Luna |

## Последствия

- Репозиторий фокусируется на `build/`, `overlay/`, скриптах сборки
- Зависимость от upstream Alpine (kernel, security updates)
- При необходимости позже: custom kernel **config** или hardened profile — без написания kernel с нуля
- Toy kernel можно вести в `experiments/` без влияния на release ISO

## Пересмотр

Пересмотреть после M2, если:

- Alpine ограничивает userspace-цели Luna
- Нужны пакеты, недоступные в `apk`
- Появится команда/время на отдельный kernel track как продукт, а не учёбу
