# PlayVue

Flutter ile yazılmış, Android ve iOS uyumlu M3U / IPTV oynatıcı.
**Uygulama içerik (kanal/playlist) sağlamaz**; kullanıcı kendi kaynaklarını ekler.

## Özellikler
- Çoklu playlist: M3U URL, dosya, Xtream Codes; liste başına otomatik güncelleme aralığı
- M3U ayrıştırma: `tvg-id`, `tvg-logo`, `group-title`, `#EXTGRP`, `#EXTVLCOPT` (User-Agent/Referer), büyük listeler için Isolate
- EPG (XMLTV, `.gz` dahil): "Şimdi / Sıradaki" bilgisi
- TvMate tarzı koyu arayüz: kategori çipleri, arama, favoriler; tablet/TV'de 3 panelli yerleşim + önizleme
- Oynatıcı (libmpv / media_kit): kanal değiştirme (yukarı/aşağı kaydır), en-boy modu
- Multiview: 2 / 3 / 4 kanal, tek kanalda ses, uzun basınca kanal değiştir/kaldır
- Kayıt: şimdi veya istenen saat + süre ile, arka planda
  - **Android:** AlarmManager (tam zamanlı) + Foreground Service. Uygulama kapalıyken de çalışır, yeniden başlatmadan sonra alarmlar yeniden kurulur.
  - **iOS:** Uygulama açıkken Dart tabanlı kayıt (iOS arka plan kısıtı nedeniyle zamanlı kayıt için uygulama açık kalmalı).
- Kayıt dosyaları `.ts` olarak kaydedilir ve uygulama içinden oynatılabilir.

## GitHub'da otomatik derleme
1. Bu klasörü yeni bir GitHub deposuna yükle (`main` dalı).
2. **Actions** sekmesinde iki iş akışı çalışır:
   - `Android APK` → `PlayVue-android` artifact'ı (arm64-v8a, armeabi-v7a, x86_64 APK)
   - `iOS IPA (imzasız)` → `PlayVue-ios-unsigned` artifact'ı
3. `v1.0.0` gibi bir tag atarsan dosyalar otomatik **Release**'e eklenir.

`android/` ve `ios/` klasörleri depoda yoktur; iş akışı `tools/bootstrap.sh` ile `flutter create` çalıştırıp
izinleri, Kotlin kodunu ve Info.plist ayarlarını otomatik uygular.

### Android imzalama (isteğe bağlı)
Secret tanımlamazsan APK debug anahtarıyla imzalanır (kurulabilir ama mağazaya yüklenemez).
Kendi anahtarınla imzalamak için **Settings → Secrets and variables → Actions** altına ekle:

| Secret | Açıklama |
|---|---|
| `KEYSTORE_BASE64` | `base64 -w0 release.jks` çıktısı |
| `KEYSTORE_PASSWORD` | Keystore şifresi |
| `KEY_ALIAS` | Anahtar takma adı |
| `KEY_PASSWORD` | Anahtar şifresi |

Keystore üretmek için:
```
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias playvue
```
**Keystore'u kaybetme ve depoya yükleme.**

### iOS
İş akışı **imzasız** IPA üretir. Kurmak için AltStore / Sideloadly gibi araçlarla kendi Apple ID'nle imzala.
App Store / TestFlight için Apple Developer hesabı ve imzalama adımları (sertifika + provisioning profile
secret'ları) eklenmelidir.

## Uygulama simgesi
`assets/icon/icon.png` (1024x1024, PNG) dosyasını kendi simgenle değiştir. Derleme sırasında
`flutter_launcher_icons` tüm boyutları üretir. Şu an yer tutucu bir simge var.

## Yerelde çalıştırma
```
tools/bootstrap.sh        # android/ ve ios/ klasörlerini üretir
flutter pub get
dart run flutter_launcher_icons
flutter run
```

## Bilinen sınırlar
- Kayıt: şifreli HLS (AES-128/DRM) ve fMP4 HLS kaydedilemez; ham TS ve düz HLS desteklenir.
- Birçok IPTV hesabı eşzamanlı bağlantıyı sınırlar. Multiview ve kayıt ek bağlantı kullanır.
- Android 12+ için "Tam zamanlı alarm" ve pil optimizasyonu muafiyeti Ayarlar'dan verilmelidir.
- Kayıtlar Android'de `Android/data/<paket>/files/Movies/PlayVue` altına yazılır (uygulama silinince silinir).
- Arayüz dili şu an Türkçe.
- Proje yazılırken derleme ortamı olmadığından ilk Actions çalıştırmasında küçük derleme hataları çıkabilir; log'u paylaşırsan düzeltirim.
