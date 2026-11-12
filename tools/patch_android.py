#!/usr/bin/env python3
"""flutter create ile üretilen android/ klasörüne PlayVue'nun native kodunu ve izinlerini ekler.
Tekrar çalıştırılabilir (idempotent)."""
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parent.parent
kt_root = root / "android/app/src/main/kotlin"
mains = list(kt_root.rglob("MainActivity.kt"))
if not mains:
    sys.exit("HATA: android/app/src/main/kotlin altında MainActivity.kt bulunamadı")
main = mains[0]
pkg = re.search(r"^package\s+([\w.]+)", main.read_text(encoding="utf-8"), re.M).group(1)

for f in (root / "native/android").glob("*.kt"):
    code = f.read_text(encoding="utf-8").replace("package com.playvue.playvue", f"package {pkg}")
    (main.parent / f.name).write_text(code, encoding="utf-8")
print(f"Kotlin dosyaları kopyalandı -> {main.parent} (paket: {pkg})")

mf = root / "android/app/src/main/AndroidManifest.xml"
s = mf.read_text(encoding="utf-8")
if "RecordingService" in s:
    print("AndroidManifest zaten yamalı")
    sys.exit(0)

perms = "\n".join(
    f'    <uses-permission android:name="android.permission.{p}"/>'
    for p in [
        "INTERNET",
        "ACCESS_NETWORK_STATE",
        "WAKE_LOCK",
        "FOREGROUND_SERVICE",
        "FOREGROUND_SERVICE_DATA_SYNC",
        "POST_NOTIFICATIONS",
        "SCHEDULE_EXACT_ALARM",
        "RECEIVE_BOOT_COMPLETED",
        "REQUEST_IGNORE_BATTERY_OPTIMIZATIONS",
    ]
)
s = s.replace("<application", perms + '\n    <application\n        android:usesCleartextTraffic="true"', 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="PlayVue"', s, count=1)

components = """
        <service
            android:name=".RecordingService"
            android:exported="false"
            android:foregroundServiceType="dataSync"/>
        <receiver android:name=".AlarmReceiver" android:exported="false"/>
        <receiver android:name=".BootReceiver" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
            </intent-filter>
        </receiver>
    """
s = s.replace("</application>", components + "</application>", 1)
mf.write_text(s, encoding="utf-8")
print("AndroidManifest yamalandı")
