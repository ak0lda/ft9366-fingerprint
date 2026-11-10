# Сканер отпечатков FocalTech FT9366 (2808:a658) на Fedora

[English](README.md) · **Русский**

Набор для ноутбуков ASUS Vivobook и других, где стоит сканер
`ID 2808:a658 Realtek USB2.0 Finger Print Bridge FocalTech Fingerprint Device`.
Стандартный libfprint его не поддерживает.

## Что внутри

| Файл | Что делает |
|---|---|
| `install.sh` | Собирает libfprint из исходников Fedora с драйвером ft9366, ставит, фиксирует версию, подбирает усиление, ставит приложение |
| `ft9366-tune-dac` | Подбор усиления изображения под конкретный экземпляр сканера (2–7 касаний) |
| `fingerprint-settings` | Приложение «Отпечатки пальцев»: запись/удаление/проверка пальцев и выбор, где ими входить |
| `fingerprint-settings-helper` | Помощник приложения (через pkexec): меняет PAM и настройки экрана входа |
| `patches/ft9366-driver.patch` | Открытый драйвер, [tattwamashi/libfprint-ft9366-pkg](https://github.com/tattwamashi/libfprint-ft9366-pkg) @ `9bdb018` |
| `patches/ft9366-dac-env.patch` | Своя правка: усиление через переменную `FT9366_IMG_DAC` (как в upstream PR #4) |

## Установка

```bash
git clone https://github.com/<your-username>/ft9366-fingerprint.git
cd ft9366-fingerprint
sudo ./install.sh            # всё сразу
sudo ./install.sh driver     # только драйвер
sudo ./install.sh tune       # только подобрать усиление
sudo ./install.sh app        # только приложение
sudo ./install.sh uninstall  # вернуть как было
```

После установки — «Отпечатки пальцев» в меню приложений: «Добавить» → около 20 лёгких касаний.

## Почему нужен подбор усиления

У каждого экземпляра FT9366 узкое рабочее окно усиления (DAC), и оно разное
(`0x34–0x38` на K3502ZA, `0x38–0x40` на N7600ZE, `0x3a` на M6500QC). При неверном значении
кадр чёрный или пересвеченный, и палец не совпадает никогда. `ft9366-tune-dac` снимает кадр
при нескольких значениях и выбирает то, при котором пустой сканер даёт среднюю яркость ~2000/4095.
Значение хранится в `/etc/systemd/system/fprintd.service.d/ft9366-dac.conf`.

После смены усиления старые отпечатки нужно записать заново.

## Где входить по отпечатку

| Переключатель | Как устроен |
|---|---|
| Вход в систему | `org.gnome.login-screen enable-fingerprint-authentication` в dconf-базе gdm |
| Разблокировка экрана | тот же ключ в настройках пользователя |
| Терминал (sudo, su) | `/etc/pam.d/sudo`, `/etc/pam.d/su`: `system-auth` ↔ `password-auth` |
| Запросы прав администратора | `/etc/pam.d/polkit-1` поверх `/usr/lib/pam.d/polkit-1` |

`password-auth` в Fedora — тот же набор, что `system-auth`, только без `pam_fprintd`.
Пароль работает всегда. Исходные файлы сохраняются как `*.fingerprint-settings.orig`.

## Обновления Fedora

`libfprint` зафиксирован (`dnf versionlock`). Когда Fedora выпустит новую версию, пересоберите:
`sudo ./install.sh driver`. Если патч не ляжет на новую версию, сборка остановится, а установленная
версия останется.

## Важно

Драйвер любительский, проверен на нескольких ноутбуках. Это удобство, а не граница безопасности.
Сканер встроен в кнопку питания — касайтесь легко.

## Лицензия

Скрипты и приложение — [GPL-3.0-or-later](LICENSE). Файлы в `patches/` изменяют libfprint
и распространяются, как и сам libfprint, под [LGPL-2.1-or-later](patches/LICENSE.LGPL-2.1).
