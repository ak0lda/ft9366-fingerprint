# FT9366 Fingerprint for Fedora

**English** · [Русский](README.ru.md)

Make the **FocalTech FT9366** fingerprint reader (USB `2808:a658`) work on Fedora —
the one built into the power button of many ASUS Vivobook laptops:

```
ID 2808:a658 Realtek USB2.0 Finger Print Bridge FocalTech Fingerprint Device
```

Stock libfprint does not support this sensor. This kit builds Fedora's own `libfprint`
package with an open-source FT9366 driver, tunes the image gain for your particular
sensor, and adds a small GNOME app to enroll fingers and choose where they can be used.

## Features

- **Driver** — rebuilds the Fedora `libfprint` source RPM with the FT9366 driver and pins
  the version with `dnf versionlock`, so a system update can't silently replace it.
- **Gain tuning** — `ft9366-tune-dac` finds a working imaging gain (DAC) for your unit in
  2–7 touches. Without this, many sensors never match a finger.
- **Fingerprints app** (GTK 4 / libadwaita) — enroll, verify and delete fingers, and switch
  fingerprint login on or off for:
  - the GDM login screen
  - the lock screen
  - `sudo` / `su` in the terminal
  - polkit "Authentication required" dialogs
- **Clean uninstall** — restores stock libfprint, PAM files and settings.

> The app interface is currently in Russian. Translations are welcome.

## Requirements

- Fedora Workstation 40 or newer (GNOME, libadwaita ≥ 1.5)
- A sensor that shows up as `2808:a658`:
  ```bash
  lsusb -d 2808:a658
  ```
- `sudo` rights; about 5 minutes for the build

## Installation

```bash
git clone https://github.com/ak0lda/ft9366-fingerprint.git
cd ft9366-fingerprint
sudo ./install.sh
```

Then open **Fingerprints** («Отпечатки пальцев») from the app menu, press **Add**
and touch the sensor lightly about 20 times.

Individual steps:

| Command | What it does |
|---|---|
| `sudo ./install.sh` | Everything: driver, gain tuning, app |
| `sudo ./install.sh driver` | Build and install libfprint with the driver |
| `sudo ./install.sh tune` | Re-tune the gain only |
| `sudo ./install.sh app` | Install the app only |
| `sudo ./install.sh uninstall` | Revert everything |

## How it works

### Why gain tuning

Each FT9366 unit has a narrow, unit-specific working gain window — for example
`0x34–0x38` on a K3502ZA, `0x38–0x40` on an N7600ZE, `0x3a` on an M6500QC. With the wrong
value every frame is black or washed out and no finger ever matches.

`ft9366-tune-dac` captures a frame at a few gain values and picks the one where an empty
sensor averages about 2000 of 4095. Captured frames stay in RAM (`/run`, root-only) and are
deleted right after. The result is stored as a systemd drop-in:

```
/etc/systemd/system/fprintd.service.d/ft9366-dac.conf
```

After changing the gain, enroll your fingers again.

### Where fingerprints are used

| Switch | Mechanism |
|---|---|
| Login screen | `org.gnome.login-screen enable-fingerprint-authentication` in the gdm dconf database |
| Lock screen | Same key in the user's settings |
| Terminal (`sudo`, `su`) | `/etc/pam.d/sudo`, `/etc/pam.d/su`: `system-auth` ↔ `password-auth` |
| Admin prompts (polkit) | `/etc/pam.d/polkit-1` overriding `/usr/lib/pam.d/polkit-1` |

On Fedora `password-auth` is the same stack as `system-auth` minus `pam_fprintd`, so the
password always keeps working. Original files are saved as `*.fingerprint-settings.orig`.

### Matching speed

Every touch is compared against each enrolled finger's template, built from its
~20 enrollment images. The original driver rebuilt every template on every touch,
on one core: about 0.5 s per enrolled finger. `ft9366-speed.patch` spreads that
work over all CPU cores (≈6–7× faster) and keeps built templates in memory while
fprintd runs, so a retry is instant. Enrollment no longer slows down towards the
last touches. Matching results are unchanged, existing fingerprints keep working.

### Fedora updates

`libfprint` is version-locked. When Fedora ships a new libfprint, rebuild:

```bash
sudo ./install.sh driver
```

If the patch no longer applies, the build stops and the installed version stays in place.

## Repository layout

| File | Purpose |
|---|---|
| `install.sh` | Installer / uninstaller |
| `ft9366-tune-dac` | Per-unit gain tuning |
| `fingerprint-settings` | The Fingerprints app (Python, GTK 4, libadwaita) |
| `fingerprint-settings-helper` | Privileged helper (run via `pkexec`) that edits PAM and GDM settings |
| `org.local.fingerprint-settings.policy` | polkit action for the helper |
| `org.local.FingerprintSettings.desktop` | App launcher |
| `patches/ft9366-driver.patch` | FT9366 driver from [tattwamashi/libfprint-ft9366-pkg](https://github.com/tattwamashi/libfprint-ft9366-pkg) @ `9bdb018` |
| `patches/ft9366-dac-env.patch` | Lets the gain be set via `FT9366_IMG_DAC` |
| `patches/ft9366-speed.patch` | Faster matching: templates built on all CPU cores and cached |

The installer verifies all patches by SHA-256 before building.

## Security note

The driver is community-written and tested on a handful of laptops. Treat fingerprint login
as a convenience, not a security boundary. Your password always works as a fallback.

## Tested hardware

| Laptop | Working gain |
|---|---|
| ASUS Vivobook K3502ZA | `0x34–0x38` |
| ASUS Vivobook N7600ZE | `0x38–0x40` |
| ASUS Vivobook M6500QC | `0x3a` |

Got it working on another model? Please
[open a hardware report](../../issues/new?template=hardware-report.md).

## Credits

- FT9366 driver: Tattwamashi Nayak and v8v88v8v88 —
  [tattwamashi/libfprint-ft9366-pkg](https://github.com/tattwamashi/libfprint-ft9366-pkg)
- [libfprint](https://gitlab.freedesktop.org/libfprint/libfprint) and
  [fprintd](https://gitlab.freedesktop.org/libfprint/fprintd)

## License

The scripts and the app are licensed under [GPL-3.0-or-later](LICENSE).
The files in `patches/` modify libfprint and are under
[LGPL-2.1-or-later](patches/LICENSE.LGPL-2.1), like libfprint itself.
