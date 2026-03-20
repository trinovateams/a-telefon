# 📦 AI Face Assistant — Kurulum Rehberi

> Bu doküman, projeyi sıfırdan kurup çalıştırabilmeniz için gereken tüm adımları içerir.

---

## 📋 İçindekiler

1. [Gereksinimler](#-gereksinimler)
2. [Flutter Kurulumu](#-flutter-kurulumu)
3. [Proje Kurulumu](#-proje-kurulumu)
4. [API Key Yapılandırması](#-api-key-yapılandırması)
5. [Android Emülatör / Cihaz Hazırlığı](#-android-emülatör--cihaz-hazırlığı)
6. [Uygulamayı Çalıştırma](#-uygulamayı-çalıştırma)
7. [APK Oluşturma](#-apk-oluşturma)
8. [Sık Karşılaşılan Sorunlar](#-sık-karşılaşılan-sorunlar)
9. [İzinler (Permissions)](#-i̇zinler-permissions)

---

## 🔧 Gereksinimler

Projeyi çalıştırabilmek için aşağıdaki araçların kurulu olması gerekmektedir:

| Araç | Minimum Versiyon | Kontrol Komutu |
|---|---|---|
| **Flutter SDK** | 3.10.8+ | `flutter --version` |
| **Dart SDK** | 3.10.8+ | `dart --version` |
| **Android SDK** | API 21+ (Android 5.0) | `flutter doctor` |
| **Java / JDK** | 17+ | `java -version` |
| **Git** | Herhangi | `git --version` |

### Opsiyonel

| Araç | Kullanım Amacı |
|---|---|
| Android Studio | Emülatör yönetimi, SDK güncelleme |
| VS Code | Flutter geliştirme (Dart + Flutter extension) |
| Fiziksel Android cihaz | Mikrofon testi için **önerilir** |

---

## 📱 Flutter Kurulumu

Eğer Flutter henüz kurulu değilse:

### Linux

```bash
# 1. Flutter SDK indir
git clone https://github.com/flutter/flutter.git -b stable ~/flutter

# 2. PATH'e ekle (~/.bashrc veya ~/.zshrc)
export PATH="$HOME/flutter/bin:$PATH"

# 3. Değişikliği uygula
source ~/.bashrc

# 4. Flutter bağımlılıklarını kontrol et
flutter doctor
```

### Tüm Platformlar

Detaylı kurulum: [https://docs.flutter.dev/get-started/install](https://docs.flutter.dev/get-started/install)

### flutter doctor Çıktısı

Aşağıdaki maddelerin ✅ olması gerekir:

```
[✓] Flutter (Channel stable, 3.x.x)
[✓] Android toolchain - develop for Android devices
[✓] Android Studio (veya VS Code)
[✓] Connected device (en az 1 cihaz/emülatör)
```

---

## 🚀 Proje Kurulumu

### Adım 1: Projeyi İndir

```bash
# Repo'yu klonla
git clone <repo-url>
cd aiyardimci

# VEYA eğer proje zaten indirildiyse
cd /path/to/aiyardimci
```

### Adım 2: Bağımlılıkları Kur

```bash
flutter pub get
```

Başarılı çıktı:
```
Resolving dependencies...
Got dependencies!
```

### Adım 3: Projeyi Doğrula

```bash
flutter analyze
```

Beklenen çıktı:
```
Analyzing aiyardimci...
No issues found!
```

> ⚠️ Eğer hata görürseniz, `flutter pub get` komutunu tekrar çalıştırın.

---

## 🔑 API Key Yapılandırması

Uygulama, **Google Gemini AI** kullanır. API key aşağıdaki dosyada tanımlıdır:

### Dosya Konumu

```
lib/core/constants/app_constants.dart
```

### API Key Ayarlama

1. [Google AI Studio](https://aistudio.google.com/) adresine git
2. Yeni bir API key oluştur
3. Proje kök dizininde `.env` dosyası oluştur (`.env.example`'ı kopyala):
   ```
   GEMINI_API_KEY=senin_api_keyin
   ```
4. Uygulamayı çalıştırırken key'i inject et:
   ```bash
   flutter run --dart-define=GEMINI_API_KEY=senin_api_keyin
   ```

> **Not:** `.env` dosyası `.gitignore`'a eklenmiştir, git'e gitmez.

---

## 📲 Android Emülatör / Cihaz Hazırlığı

### Seçenek A: Fiziksel Cihaz (Önerilen)

Mikrofon ve ses özellikleri en iyi fiziksel cihazda çalışır.

1. Telefonda **Geliştirici Seçenekleri**'ni aç
   - Ayarlar → Telefon Hakkında → **Yapı Numarası**'na 7 kez dokun
2. **USB Hata Ayıklama**'yı etkinleştir
   - Ayarlar → Geliştirici Seçenekleri → USB Hata Ayıklama → Aç
3. USB kabloyla bilgisayara bağla
4. Telefondaki "USB hata ayıklamaya izin ver?" iletisini onayla

Bağlantıyı kontrol et:
```bash
flutter devices
```

### Seçenek B: Android Emülatör

```bash
# Android Studio üzerinden emülatör oluştur
# VEYA komut satırından:
flutter emulators
flutter emulators --launch <emulator_id>
```

> ⚠️ **Not:** Emülatörde mikrofon genellikle çalışmaz. Ses özelliklerini test etmek için fiziksel cihaz kullanın.

---

## ▶️ Uygulamayı Çalıştırma

### Debug Modu (Geliştirme)

```bash
# Bağlı cihazda çalıştır
flutter run

# Belirli bir cihaz seçmek için
flutter run -d <device_id>

# Cihaz listesini görmek için
flutter devices
```

### Hot Reload & Hot Restart

Uygulama çalışırken terminalde:
- **r** → Hot Reload (kodu günceller, state'i korur)
- **R** → Hot Restart (kodu günceller, state'i sıfırlar)
- **q** → Uygulamayı kapat

### Release Modu (Performans Testi)

```bash
flutter run --release
```

---

## 📦 APK Oluşturma

### Standart APK

```bash
flutter build apk --release
```

Çıktı: `build/app/outputs/flutter-apk/app-release.apk`

### Mimari Başına Ayrı APK (Daha Küçük)

```bash
flutter build apk --split-per-abi --release
```

Çıktılar:
```
build/app/outputs/flutter-apk/
├── app-armeabi-v7a-release.apk   (ARM 32-bit)
├── app-arm64-v8a-release.apk     (ARM 64-bit) ← Çoğu modern telefon
└── app-x86_64-release.apk        (x86 emülatör)
```

### App Bundle (Google Play Store İçin)

```bash
flutter build appbundle --release
```

Çıktı: `build/app/outputs/bundle/release/app-release.aab`

### APK'yı Cihaza Yükleme

```bash
# USB ile bağlı cihaza doğrudan yükle
flutter install

# VEYA adb ile
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## ❓ Sık Karşılaşılan Sorunlar

### 1. `flutter pub get` başarısız oluyor

```bash
# Cache temizle ve tekrar dene
flutter pub cache clean
flutter pub get
```

### 2. Gradle build hataları

```bash
# Gradle cache temizle
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

### 3. Java versiyon uyumsuzluğu

```bash
# Java versiyonunu kontrol et
java -version

# JDK 17 gerekli — Eğer farklı bir versiyon varsa:
# JAVA_HOME ortam değişkenini JDK 17'ye yönlendir
export JAVA_HOME=/path/to/jdk-17
```

### 4. "No connected devices" hatası

```bash
# Cihaz bağlantısını kontrol et
flutter doctor
flutter devices

# Emülatör başlat (cihaz yoksa)
flutter emulators --launch <emulator_id>
```

### 5. Mikrofon çalışmıyor (Emülatörde)

- Bu **beklenen bir durum**dur. Emülatörlerde mikrofon genellikle desteklenmez.
- **Çözüm:** Fiziksel Android cihaz kullanın.
- **Alternatif:** Uygulamadaki klavye butonuna (⌨️) basarak yazılı mesaj gönderin.

### 6. "Permission denied" hatası (Mikrofon)

Uygulama ilk açılışta mikrofon izni isteyecektir. İzni reddettiyseniz:

- Ayarlar → Uygulamalar → AI Face Assistant → İzinler → Mikrofon → İzin Ver

### 7. Gemini API hatası

```
Error: API key not valid
```

- API key'in doğru olduğundan emin olun
- [Google AI Studio](https://aistudio.google.com/) üzerinden key'in aktif olduğunu kontrol edin
- Ücretsiz plan limitlerine ulaşmış olabilirsiniz

---

## 🔐 İzinler (Permissions)

Uygulamanın Android'de ihtiyaç duyduğu izinler:

| İzin | Neden Gerekli | Dosya |
|---|---|---|
| `RECORD_AUDIO` | Sesli komut (mikrofon) | AndroidManifest.xml |
| `INTERNET` | Gemini API iletişimi | AndroidManifest.xml |
| `BLUETOOTH` | Bluetooth kulaklık desteği | AndroidManifest.xml |
| `BLUETOOTH_CONNECT` | Bluetooth cihaz bağlantısı | AndroidManifest.xml |

Bu izinler `android/app/src/main/AndroidManifest.xml` dosyasında zaten tanımlıdır.

Runtime'da (uygulama çalışırken) sadece **Mikrofon izni** kullanıcıdan istenir. Diğer izinler otomatik verilir.

---

## ✅ Kurulum Tamamlandı!

Eğer tüm adımları başarıyla tamamladıysanız:

```bash
flutter run
```

komutu ile uygulamayı başlatabilirsiniz. 🚀

**İlk Kullanım:**
1. Uygulama açıldığında siyah ekranda animasyonlu gözler göreceksiniz
2. Alt kısımdaki 🎤 butonuna basarak sesli soru sorun
3. Kısa bir bekleme sonrası AI yanıt verecek ve gözler tepki gösterecek
4. ⚙️ (Settings) butonundan tema ve kişilik ayarlarını değiştirin
