# Alexia "Living Entity" Engine — Tasarim Spec

**Tarih:** 2026-03-21
**Amac:** Alexia'yi pasif asistandan Cozmo benzeri canli bir maskota donusturmek.

---

## 1. Bug Fix'ler ve Kod Temizligi

### 1.1 Olu kod silme
- `speech_service.dart` silinecek — Live API mic streaming yapiyor
- `tts_service.dart` silinecek — Live API sesli yanit veriyor
- `ai_service.dart` silinecek — Live API chat yapiyor
- Ilgili import'lar temizlenecek

### 1.2 Buffer drain fix
Mevcut sabit 2 saniyelik bekleme kaldirilacak. Yerine:
- `_onMessage` icerisinde gelen audio chunk'larin toplam byte miktari takip edilecek
- `turnComplete` geldiginde: `totalBytes / (24000 * 2)` = gercek sure (saniye)
- Hesaplanan sure + 200ms margin kadar bekle, sonra mic ac
- Her yeni turn basinda `totalBytes` sifirlanir

### 1.3 Baglanti hatasi geri bildirimi
- `FaceController`'a `connectionState` enum eklenir: `connecting`, `connected`, `error`, `reconnecting`
- `LiveAudioService`'e yeni callback: `onConnectionStateChange(ConnectionState)`
- UI'da status indicator'da gosterilir

### 1.4 Wake word prompt iyilestirmesi
- Mevcut prompt yeterli, ek degisiklik gerekmiyor

---

## 2. Brain Service — Canlilik Motoru

**Dosya:** `lib/core/services/brain_service.dart`

### 2.1 Ic durum degiskenleri
```dart
double energy;      // 0.0-1.0, zamanla duser
double boredom;     // 0.0-1.0, sessizlikte artar
double affection;   // 0.0-1.0, konusma ile artar
DateTime lastInteraction;
DateTime sessionStart;
```

### 2.2 Zamanlayici dongusu (her 30 saniye)
```
energy -= 0.02
boredom += 0.05
Konusma olursa: boredom = 0, energy += 0.1, affection += 0.03
Saate gore energy ayarla (gece dusuk, sabah yuksek)
```

### 2.3 Proaktif konusma tetikleyicileri
| Kosul | Prompt ornegi |
|-------|---------------|
| boredom > 0.7 | "Sikildim, kendi kendine bir sey soyle" |
| energy < 0.2 | "Cok uyklusun, esneyerek bir sey soyle" |
| 5 dk sessizlik + affection > 0.5 | "Kullaniciyi ozledin, bir sey soyle" |
| Sabah ilk acilis | "Gunaydin de, nasil uyudun diye sor" |
| Gece gec saat (23:00+) | "Gec saat oldugunu belirt" |
| Uzun oturum (>30dk) | "Seninle konusmayi sevdigini soyle" |

Her tetikleyici icin min 30dk cooldown suresi.

### 2.4 Idle davranis state
Brain service su enum degerlerini FaceController'a bildirir:
```dart
enum IdleBehavior { normal, curious, sleepy, sleeping }
```
- `energy < 0.3` → sleepy
- `energy < 0.15 || saat 00:00-06:00` → sleeping
- `boredom > 0.5` → curious
- diger → normal

### 2.5 LiveAudioService entegrasyonu
- Brain, `LiveAudioService.sendText()` ile Gemini'ye bağlamsal prompt gonderir
- Gemini sesli yanit uretir, normal akisla calinir
- `onSpeaking/onListening` callback'leri Brain'e de iletilir (boredom/energy guncelleme icin)

---

## 3. Hafiza Sistemi

**Dosya:** `lib/core/services/memory_service.dart`

### 3.1 Konusma yakalama
- `LiveAudioService`'den gelen text ciktilari yakalanir (mood tag parse'in yapildigi yer)
- `sendText()` ile gonderilen kullanici mesajlari da kaydedilir
- Her 5 turn'de veya oturum sonunda ozet cikarilir

### 3.2 Ozetleme
- Biriken konusma metni Gemini'ye gonderilir: "Bu konusmayi 1 cumleyle ozetle"
- Sonuc kaydedilir

### 3.3 Depolama
- `SharedPreferences`'a JSON list olarak kaydedilir
- Max 50 ani (FIFO)
- Format: `{ "summary": "...", "date": "2026-03-21", "mood": "happy" }`

### 3.4 Kullanim
- System prompt'a son 5-10 ani eklenir:
  ```
  Hatirladiklarin:
  - 2 gun once: Kullanici futbol macindan bahsetti
  - Dun: Kullanici sinavdan stresli oldugunu soyledi
  ```
- Brain service proaktif konusma tetiklediginde anilari kullanir

---

## 4. Cevresel Farkindalik

Brain service'in icerisine entegre.

### 4.1 Zaman farkindaligi
| Saat araligi | Davranis |
|---|---|
| 06:00-10:00 | Gunaydin, energy 0.9 |
| 12:00-14:00 | Ogle yemegi hatirlatma |
| 18:00-21:00 | Aksam sohbeti |
| 21:00-00:00 | Energy dusmeye baslar |
| 00:00-06:00 | Uyku modu |

### 4.2 Gun farkindaligi
- Hafta sonu farki
- Ilk kullanim karsilama
- Uzun sure kapalı sonra acilis

### 4.3 Cooldown
- Her tetikleyici icin min 30dk cooldown
- Map ile takip: `Map<String, DateTime> _cooldowns`

---

## 5. Idle Animasyonlar — Cozmo Tarzi

### 5.1 Squash sistemi
- `RealisticEyePainter`'a `squash` parametresi (0.0-1.0)
- Canvas `scale(1.0, 1.0 - squash)` transform ile dikey ezilir
- Mevcut iris/pupil render bozulmaz

### 5.2 Blink
- Her 3-7 saniyede rastgele tetiklenir
- squash: 0 → 1 → 0 (250ms)
- %20 ihtimalle cift blink (400ms)
- Konusurken siklik azalir
- Uyku modunda blink yok

### 5.3 Esneme
- energy < 0.3 oldugunda tetiklenir
- squash: 0 → 0.6 → 0 (800ms) + pupil 1.4x
- Brain "uykuluyum" konusmasiyla senkronize

### 5.4 Uyuklama modu
- energy < 0.15 veya gece 00:00+
- squash sabit 0.5-0.7
- Saccade durur, sadece yavas micro jitter
- Ambient glow dusuk, mood rengi koyu mavi

### 5.5 Uyanma
- Kullanici konusunca squash 0.7 → 0 (300ms)
- Pupil bounce efekti

### 5.6 Merak
- boredom > 0.5
- Saccade hizlanir, aralik genisler
- Pupil hafif buyuk

### 5.7 Mutlu titreme
- affection > 0.7 + kullanici konustugunda
- 2-3 kare scale bounce

### 5.8 Goz pozisyon animasyonlari
- Merak: gozler hafif yukari kayar
- Uzgun: gozler hafif asagi
- Dusuk enerji: yavas hareket, saccade araligi uzar

---

## 6. Ayarlar ve UI Guncellemeleri

### 6.1 Settings ekranina yeni bolum: Beyin Ayarlari
- Proaktif konusma: Acik/Kapali toggle
- Konusma sikligi: Slider (nadir/normal/cok konuskan)
- Uyku modu: Acik/Kapali
- Hafiza: Acik/Kapali + "Hafizayi sil" butonu

### 6.2 Baglanti durumu gostergesi (FaceScreen)
- Status indicator'a entegre
- Baglaniyor: turuncu dot + "BAGLANIYOR..."
- Hata: kirmizi dot + "BAGLANTI HATASI" + dokunarak retry
- Bagli: mevcut davranis

### 6.3 Enerji gostergesi (FaceScreen)
- Status indicator yaninda kucuk enerji bari
- Brain'in energy degerini gosterir
- Dokunulunca "kahve" efekti: energy +0.3, Alexia tepki verir

### 6.4 Durum mesajlari
| Durum | Mesaj |
|---|---|
| idle, energy yuksek | "Hey Alexia de..." |
| idle, energy dusuk | "uykulum..." |
| idle, boredom yuksek | "canim sikiliyor..." |
| sleeping | "zzZ..." |

---

## 7. Mimari ve Veri Akisi

### 7.1 Dosya yapisi (son hal)
```
lib/core/services/
  live_audio_service.dart   (mevcut, bug fix)
  brain_service.dart        (YENI)
  memory_service.dart       (YENI)
  storage_service.dart      (mevcut, yeni key'ler)
```

### 7.2 Dependency injection (main.dart)
```dart
final memoryService = MemoryService();
final brainService = BrainService(
  liveService: liveService,
  memoryService: memoryService,
  storageService: storageService,
);
FaceController(
  liveService: liveService,
  brainService: brainService,
  storageService: storageService,
);
```

### 7.3 Veri akisi
```
BrainService (30s dongu)
  -> energy/boredom/affection hesapla
  -> tetikleyici kontrol et
  -> EVET: LiveAudioService.sendText(prompt)
  -> idleBehavior guncelle -> FaceController -> RealisticEyeWidget (squash, blink)
  -> MemoryService'e konusma bildir
```

---

## 8. Implementasyon Sirasi

1. Olu kodu sil + bug fix'ler
2. Blink + squash animasyonu
3. BrainService (energy/boredom dongusu)
4. Proaktif konusma
5. Idle davranislari (uyku, esneme, merak)
6. MemoryService (hafiza)
7. Cevresel farkindalik (saat, gun)
8. Ayarlar ekrani guncellemesi
9. Baglanti durumu UI
