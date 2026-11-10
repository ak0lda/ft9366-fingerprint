---
name: Hardware report
about: Report whether the FT9366 sensor works on your laptop
title: "[Hardware] <laptop model>"
labels: hardware
---

**Laptop model:** (e.g. ASUS Vivobook K3502ZA)

**Fedora version:** (`cat /etc/fedora-release`)

**libfprint version:** (`rpm -q libfprint`)

**`lsusb -d 2808:a658` output:**

```
```

**Gain chosen by `ft9366-tune-dac`:** (`cat /etc/systemd/system/fprintd.service.d/ft9366-dac.conf`)

**Result:**
- [ ] Enrollment works
- [ ] Verification matches reliably
- [ ] Login screen / lock screen
- [ ] sudo

**Notes / logs:** (`journalctl -u fprintd -b --no-pager | tail -50`)

<!-- Do not attach sensor images (*.pgm) — they contain your fingerprint. -->
