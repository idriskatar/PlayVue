#!/usr/bin/env python3
"""ios/Runner/Info.plist dosyasını PlayVue için yamalar (idempotent)."""
import pathlib
import plistlib
import sys

root = pathlib.Path(__file__).resolve().parent.parent
p = root / "ios/Runner/Info.plist"
if not p.exists():
    sys.exit("ios/Runner/Info.plist bulunamadı")

with open(p, "rb") as f:
    d = plistlib.load(f)

d["CFBundleDisplayName"] = "PlayVue"
d["CFBundleName"] = "PlayVue"
# IPTV akışlarının çoğu http olduğu için
d["NSAppTransportSecurity"] = {"NSAllowsArbitraryLoads": True}
# Arka planda ses
modes = list(d.get("UIBackgroundModes", []))
if "audio" not in modes:
    modes.append("audio")
d["UIBackgroundModes"] = modes
# Kayıtlar Dosyalar uygulamasında görünsün
d["UIFileSharingEnabled"] = True
d["LSSupportsOpeningDocumentsInPlace"] = True

with open(p, "wb") as f:
    plistlib.dump(d, f, sort_keys=False)
print("Info.plist yamalandı")
