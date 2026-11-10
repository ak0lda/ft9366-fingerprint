---
name: Bug report
about: Something in the installer, tuner or app does not work
labels: bug
---

**What happened:**

**What you expected:**

**Steps to reproduce:**

**System:**
- Laptop model:
- Fedora version (`cat /etc/fedora-release`):
- libfprint version (`rpm -q libfprint`):

**Logs:**
- Build failure: `~/.cache/ft9366-fingerprint/rpmbuild/build.log` (last 50 lines)
- fprintd: `journalctl -u fprintd -b --no-pager | tail -50`

<!-- Do not attach sensor images (*.pgm) — they contain your fingerprint. -->
