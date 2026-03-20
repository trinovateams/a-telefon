# Ultra-Realistik Göz Tasarımı

## Amaç

Mevcut 5 çocuksu göz temasını kaldırıp, tek bir ultra-realistik iki göz tasarımıyla değiştirmek. CustomPaint ile anatomik doğrulukta, fotogerçekçi göz çizimi.

## Yaklaşım

CustomPaint Ultra-Detay — sıfır dış bağımlılık, her piksel programatik kontrol altında, mood/state entegrasyonu doğal.

---

## 1. Göz Anatomisi ve Katmanlar

Aşağıdan yukarıya çizim sırası:

1. **Göz çukuru gölgesi** — Gözün oturduğu derin, oval gölge. Üst kaş kemiğinden aşağı doğru yumuşak gradient.

2. **Cilt tabanı** — Göz çevresi ten rengi, hafif doku. Göz altı gölgesi (mood'a göre koyulaşır — üzgünken daha koyu).

3. **Sklera (göz beyazı)** — Badem şeklinde, saf beyaz değil. Sıcak krem tonları, kenar gölgesi (üst kapaktan düşen), hafif pembelik. 8-12 adet ince kırmızı kan damarı prosedürel çizilecek.

4. **İris** — Çok katmanlı:
   - Limbal halka (koyu dış çerçeve)
   - 200+ radyal fiber dokusu (rastgele kalınlık/uzunluk)
   - Collarette halkası (pupil çevresi)
   - 15-25 kripta deseni (koyu noktalar)
   - Mood renk overlay (iris rengini etkiler)

5. **Pupil** — Siyah daire, kenarları hafif bulanık (iris'e geçiş). State'e göre boyut değişir. Baz pupil çapı = iris çapının %35'i (idle state).

6. **Cornea yansıması** — Ana yansıma: üst-sol, iris çapının %25'i boyutunda yuvarlak köşeli dikdörtgen, %70 opaklık beyaz. İkincil yansıma: sağ-alt, iris çapının %10'u boyutunda daire, %40 opaklık. Tüm göz üzerinde ıslak parlama radyal gradyenti (%15 beyaz → şeffaf).

7. **Üst göz kapağı** — Gerçekçi eğri, cilt dokusu, kıvrım çizgisi (crease), göz kapağı gölgesi iris üstüne düşer. Kırpışma animasyonu ile aşağı iner.

8. **Alt göz kapağı** — Waterline (ıslak iç kenar), hafif gölge, alt kirpikler.

9. **Kirpikler** — Üstte 15-20 adet, altta 8-12 adet. Her biri ayrı bezier eğri, farklı uzunluk/açı. Kırpışmada kapakla birlikte hareket eder.

---

## 2. İki Göz Yerleşimi ve Senkronizasyon

### Ekran düzeni (sadece landscape — uygulama zaten landscape-only)

- İki göz ekranın ortasında, yatay hizalı
- Gözler arası mesafe: ekran genişliğinin ~%15'i (burun köprüsü mesafesi)
- Her göz: ekran genişliğinin ~%30'u kadar geniş
- Dikey olarak ekranın orta-üst bölgesinde (%40 noktası)

### Senkronize hareketler

- Bakış yönü: iki göz aynı noktaya bakar (pupil'ler paralel hareket)
- Kırpışma: iki göz aynı anda kırpar
- State geçişleri: ikisi aynı anda tepki verir

### Mikro-asimetri (gerçekçilik)

- Sol göz pupil'i ~%2 daha büyük (doğal anisocoria)
- Kirpik dizilimi simetrik değil — sol/sağ ayrı seed ile prosedürel
- Kırpışma hızı: bir göz diğerinden 10-20ms önce kapanabilir
- Farklı kan damarı desenleri

### Burun köprüsü

- İki göz arasında hafif cilt gölgesi — burun köprüsünün varlığını hissettirir
- Çizim yok, sadece ince gölge/karanlık alan

---

## 3. Animasyonlar ve State Tepkileri

### Kırpışma

- Doğal aralık: 3-6 saniye rastgele
- Kapanış: 80ms, açılış: 120ms (kapanış daha hızlı — gerçek göz böyle)
- Kapaklar inerken kirpikler birbirine yaklaşır
- %10 ihtimalle çift kırpışma (200ms arayla iki kez)

### Pupil dinamikleri

| State | Davranış |
|-------|----------|
| idle | Normal boyut, yavaş nefes efekti (±%3) |
| listening | %20 genişleme (1.2s ease-out) — ilgilenme |
| thinking | %15 daralma + hızlı mikro-titreşimler |
| speaking | Ritmik %5-10 genişleme/daralma |

### Bakış (saccade)

| State | Bakış yönü |
|-------|-----------|
| idle | Yavaş sürüklenme, 4-6s rastgele yön |
| listening | Hafifçe yukarı (kulak keser gibi) |
| thinking | Sola-aşağı (düşünme jesti) |
| speaking | Ortaya kilitleme (göz teması) |

- Mikro-saccade'ler: 0.5-2 saniyede bir ±%1 titreşim (canlılık hissi)

### Iris tepkileri

| Mood | Etki |
|------|------|
| angry | Iris kısılır, kan damarları belirginleşir, pupil küçülür |
| sad | Iris soluklaşır, göz kapağı %10 düşer (yarı kapalı) |
| excited | Pupil genişler, iris parlar, ışık yansımaları güçlenir |
| happy | Iris sıcak tona kayar, hafif kısılma (gülümseme) |
| curious | Pupil genişler, üst kapak %5 açılır |
| calm | Normal, sakin parlama |

- Mood değişiminde iris rengi 800ms geçiş
- Mood pupil etkileri state pupil değerinin üzerine çarpımsal uygulanır (örn: listening 1.2x + angry 0.85x = 1.02x)

### Islak parlama

- Sürekli hafif animasyon — ışık kaynağı çok yavaş hareket eder
- Kırpışma sonrası parlama kısa süre artar (göz yeniden nemlenmiş)

---

## 4. Arkaplan ve Atmosfer

- Siyah arkaplan, çok hafif koyu gri noise dokusu
- Gözlerin etrafında yumuşak, oval mood-renkli glow
- Glow yoğunluğu: idle %2, listening %5, thinking %4, speaking %8
- Parçacık efekti yok — temiz, minimalist

---

## 5. UI Elementleri

- State indicator: daha minimal — küçük ikon + text, daha şeffaf arka plan
- Response bubble: glassmorphism — hafif blur + yarı saydam beyaz kenarlık
- Kontroller: mevcut yapı korunuyor

---

## 6. Yapısal Değişiklikler

### Kaldırılacak dosyalar

- `lib/features/face/themes/default_eye.dart`
- `lib/features/face/themes/female_eye.dart`
- `lib/features/face/themes/anime_eye.dart`
- `lib/features/face/themes/robot_eye.dart`
- `lib/features/face/themes/cool_eye.dart`
- `lib/features/face/themes/eye_theme_manager.dart`
- `lib/core/enums/eye_theme_type.dart`

### Eklenecek dosyalar

- `lib/features/face/themes/realistic_eye.dart` — Ana widget (AnimationController'lar, state yönetimi, iki göz layout)
- `lib/features/face/themes/realistic_eye_painter.dart` — CustomPainter (tüm çizim katmanları)

### Güncellenecek dosyalar

- `lib/features/face/face_screen.dart` — EyeThemeManager yerine doğrudan RealisticEyeWidget
- `lib/features/face/face_controller.dart` — Tema seçimi kaldırılacak (currentTheme, setTheme, _updateThemePrompt, EyeThemeType import)
- `lib/features/settings/settings_screen.dart` — Tema seçim UI'ı kaldırılacak
- `lib/core/services/storage_service.dart` — `getEyeTheme()`, `setEyeTheme()` metotları ve `eye_theme_type.dart` import'u kaldırılacak
- `lib/core/services/ai_service.dart` — `updateThemePrompt()` ve `_themePromptAddition` kaldırılacak
- `lib/core/constants/app_constants.dart` — Tema prompt'ları kaldırılacak, `MoodAnimationSpeed` korunacak (pupil/saccade hız çarpanı olarak kullanılıyor)

---

## 7. Renk Paleti

### Iris mood renkleri (mevcut korunuyor)

- happy: #4FC3F7
- sad: #9C27B0
- angry: #FF5252
- calm: #81D4FA
- excited: #FFD740
- curious: #69F0AE

---

## 8. Performans ve Teknik Detaylar

### AnimationController'lar

Widget `TickerProviderStateMixin` kullanacak. Controller listesi:
1. `_blinkController` (80-120ms) — göz kapağı kırpışma
2. `_pupilController` (1.2s) — pupil boyut geçişleri
3. `_saccadeController` (4-6s) — bakış yönü sürüklenmesi
4. `_irisColorController` (800ms) — mood renk geçişi
5. `_shimmerController` (3s loop) — ıslak parlama hareketi
6. `_breathController` (4s loop) — pupil nefes efekti

### Performans

- Hedef: 60fps orta segment cihazlarda
- Prosedürel elemanlar (kan damarları, iris fiberleri, kirpik açıları, kripta desenleri) widget oluşturulurken sabit seed ile bir kez üretilir ve `List` olarak saklanır — her frame'de yeniden hesaplanmaz
- `shouldRepaint()` dirty flag sistemi: sadece değişen animasyon değerleri repaint tetikler
- `RepaintBoundary` ile sol ve sağ göz bağımsız repaint edilebilir

### Prosedürel seed yönetimi

- Her göz (sol/sağ) farklı sabit seed ile oluşturulur
- Seed'ler widget initState'te `Random(42)` (sol) ve `Random(137)` (sağ) ile üretilir
- Kan damarları, iris fiberleri, kirpik açıları bu seed'lerden türer
- Seed'ler widget yaşam döngüsü boyunca sabit kalır — görsel "popping" olmaz

---

### Anatomik renkler

- Sklera merkez: #F8F4EF (sıcak beyaz)
- Sklera kenar: #E0D0C0 (krem)
- Kan damarı: #CC4444 (koyu kırmızı)
- Cilt bazı: #2A2018 (koyu ten — karanlık ortam)
- Göz kapağı crease: #1A1410
- Pupil: #050505 (saf siyah değil, çok koyu kahve)
