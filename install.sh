#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Сканер отпечатков FocalTech FT9366 (USB 2808:a658) на Fedora — установщик.
#
#   sudo ./install.sh            всё: драйвер + подбор усиления + приложение «Отпечатки пальцев»
#   sudo ./install.sh driver     только собрать и поставить libfprint с драйвером
#   sudo ./install.sh tune       только подобрать усиление (после установки драйвера)
#   sudo ./install.sh app        только приложение «Отпечатки пальцев»
#   sudo ./install.sh uninstall  вернуть всё как было (стандартный libfprint, PAM, настройки)
#
# Драйвер: открытый ft9366 из https://github.com/tattwamashi/libfprint-ft9366-pkg (патч проверен,
# sha256 ниже) + правка ft9366-dac-env.patch (усиление через FT9366_IMG_DAC).
set -euo pipefail

KIT_REV=1
KIT_DIR=$(cd "$(dirname "$0")" && pwd)
DRIVER_SHA=7eef11147e47452c0ceeaf1525090a2fc6ae92835d1f7ef439570c27966cb519
DAC_SHA=d73f3ad013545002b91291d559cceeefdbca4e5337be983b3287cd8bc294d9da
DROPIN=/etc/systemd/system/fprintd.service.d/ft9366-dac.conf

[[ $EUID -eq 0 && -n ${SUDO_USER:-} && $SUDO_USER != root ]] || {
  echo "Запустите через sudo от своего пользователя: sudo $0 ${1:-}"; exit 1; }
U=$SUDO_USER
UHOME=$(getent passwd "$U" | cut -d: -f6)
step() { printf '\n=== %s ===\n' "$*"; }
die()  { echo "ОШИБКА: $*" >&2; exit 1; }

check_hw() {
  grep -q '^ID=fedora' /etc/os-release || die "это не Fedora"
  lsusb -d 2808:a658 >/dev/null 2>&1 || die "сканер 2808:a658 не найден (lsusb -d 2808:a658)"
}

install_driver() {
  step "Драйвер: проверка патчей"
  (cd "$KIT_DIR/patches" &&
   echo "$DRIVER_SHA  ft9366-driver.patch" | sha256sum -c --quiet &&
   echo "$DAC_SHA  ft9366-dac-env.patch"   | sha256sum -c --quiet) || die "патчи изменены — сверьте sha256"

  step "Драйвер: исходники libfprint из Fedora"
  local top="$UHOME/.cache/ft9366-fingerprint/rpmbuild"
  sudo -u "$U" bash -euo pipefail -s "$top" "$KIT_DIR" "$KIT_REV" <<'EOS'
top=$1 kit=$2 rev=$3
rm -rf "$top"; mkdir -p "$top"/{SOURCES,SPECS,SRPMS}
cd "$top/SRPMS"
dnf download --source libfprint >/dev/null
srpm=$(ls libfprint-*.src.rpm | head -1)
cd "$top/SOURCES"; rpm2cpio "../SRPMS/$srpm" | cpio -idm --quiet
mv libfprint.spec ../SPECS/
cp "$kit"/patches/*.patch .
cd ../SPECS
rel=$(rpmspec -q --srpm --qf '%{release}' libfprint.spec 2>/dev/null)
base=${rel%%.fc*}
sed -i -E "s/^Release:.*/Release:        ${base}.ft9366.${rev}%{?dist}/" libfprint.spec
sed -i '/^Source0:/a Patch100:       ft9366-driver.patch\nPatch101:       ft9366-dac-env.patch' libfprint.spec
echo "Исходник: $srpm"
EOS
  local spec="$top/SPECS/libfprint.spec"

  step "Драйвер: зависимости для сборки"
  dnf -y builddep "$spec"

  step "Драйвер: сборка (несколько минут)"
  sudo -u "$U" rpmbuild -bb --define "_topdir $top" "$spec" >"$top/build.log" 2>&1 ||
    { tail -30 "$top/build.log"; die "сборка не удалась, лог: $top/build.log (возможно, новая версия libfprint и патч не подходит)"; }
  local rpm
  rpm=$(ls "$top"/RPMS/x86_64/libfprint-[0-9]*.ft9366.*.x86_64.rpm | head -1)
  echo "Собран: $(basename "$rpm")"

  step "Драйвер: установка и фиксация версии"
  dnf versionlock delete libfprint >/dev/null 2>&1 || true
  rpm -Uvh --oldpackage --replacepkgs "$rpm"
  dnf versionlock add libfprint
  systemctl stop fprintd.service 2>/dev/null || true
  authselect current 2>/dev/null | grep -q with-fingerprint || authselect enable-feature with-fingerprint
  fprintd-list "$U" 2>/dev/null | grep -q 'FT9366' && echo "Сканер виден: FocalTech FT9366" || die "fprintd не видит сканер"
}

install_tuner() {
  install -m 0755 "$KIT_DIR/ft9366-tune-dac" /usr/local/sbin/ft9366-tune-dac
}

tune() {
  step "Подбор усиления"
  install_tuner
  /usr/local/sbin/ft9366-tune-dac "$U"
}

install_app() {
  step "Приложение «Отпечатки пальцев»"
  install_tuner
  install -m 0755 "$KIT_DIR/fingerprint-settings"        /usr/local/bin/fingerprint-settings
  install -m 0755 "$KIT_DIR/fingerprint-settings-helper" /usr/local/libexec/fingerprint-settings-helper
  install -m 0644 "$KIT_DIR/org.local.fingerprint-settings.policy" /usr/share/polkit-1/actions/org.local.fingerprint-settings.policy
  install -D -m 0644 "$KIT_DIR/org.local.FingerprintSettings.desktop" /usr/local/share/applications/org.local.FingerprintSettings.desktop
  command -v restorecon >/dev/null && restorecon -F /usr/local/bin/fingerprint-settings /usr/local/libexec/fingerprint-settings-helper \
    /usr/share/polkit-1/actions/org.local.fingerprint-settings.policy /usr/local/share/applications/org.local.FingerprintSettings.desktop || true
  update-desktop-database /usr/local/share/applications >/dev/null 2>&1 || true
  echo "Установлено: ищите «Отпечатки» в меню приложений."
}

uninstall() {
  step "Удаление"
  for z in terminal polkit login; do /usr/local/libexec/fingerprint-settings-helper "$z" on 2>/dev/null || true; done
  rm -f /usr/local/bin/fingerprint-settings /usr/local/libexec/fingerprint-settings-helper \
        /usr/share/polkit-1/actions/org.local.fingerprint-settings.policy \
        /usr/local/share/applications/org.local.FingerprintSettings.desktop /usr/local/sbin/ft9366-tune-dac
  rm -f "$DROPIN"; rmdir --ignore-fail-on-non-empty "$(dirname "$DROPIN")" 2>/dev/null || true
  systemctl daemon-reload; systemctl stop fprintd.service 2>/dev/null || true
  dnf versionlock delete libfprint >/dev/null 2>&1 || true
  dnf -y distro-sync libfprint
  echo "Готово: стандартный libfprint возвращён. Записанные отпечатки можно удалить командой: fprintd-delete $U"
}

case ${1:-all} in
  all)       check_hw; install_driver; tune; install_app ;;
  driver)    check_hw; install_driver ;;
  tune)      check_hw; tune ;;
  app)       install_app ;;
  uninstall) uninstall ;;
  *) sed -n '3,11p' "$0"; exit 2 ;;
esac
echo; echo "ГОТОВО."
