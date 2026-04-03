# Cozmo Robot - Android Application Plan

## Overview
Bu proje, mevcut altyapıyı kullanarak tamamen "Anki Cozmo" adlı ikonik küçük oyuncak robotun sevimli, mızmız, isyankar ama çok tatlı kişiliğine ("Gene bana napcanız" diyen çocuk vibe'ı) dönüştürmeyi amaçlar. Kullanıcı kararları doğrultusunda Cozmo; görsel olarak klasik kare göz yapısına sahip olacak, varsayılan kişiliği aşırı tepkisel, asabi ama oyunbaz bir robot olarak güncellenecek. İnternete bağlı (Live API) mimari aynen devam edecektir.

## Project Type
**MOBILE** (Flutter / Android)

## Success Criteria
- [x] Mevcut `CozmoEyeWidget` yapısının "Flawless Cozmo-style eye" (yuvarlatılmış kareler) olarak kesin korunması ve animasyonların yüz ifadeleriyle eşleşmesi.
- [x] `app_constants.dart` içindeki `defaultSystemPrompt`; Cozmo'nun "Yine bana napcanız", "Bırakın beni" tarzı isyankar ve oyuncu karakterine güncellenecek.
- [x] Ayarlardaki ön tanımlı (preset) kişilik şablonları (Cozmo, Espirili, Flörtöz vb.) bu oyuncak karakterle uyumlu olacak.
- [x] Varsayılan uyanma ismi (Wake Word) "Cozmo" yapılacak.
- [x] Mevcut `LiveAudioService` tabanlı internet bağlantılı çalışan yapı bozulmadan devam edecek (Offline model eklenmeyecek).

## Tech Stack
- **Framework:** Flutter
- **State Management:** Provider
- **AI Backend:** Google Gemini Live API (LiveAudioService / BrainService)
- **Animations:** CustomPainter & AnimationController

## File Structure
Değişim yapılan ana hedefler:
1. `lib/core/constants/app_constants.dart` → (AI prompt: Asabi, tatlı, mızmız çocuk kişiliği)
2. `lib/features/face/face_controller.dart` → (Varsayılan uyanma ismi "Cozmo")
3. `lib/features/face/face_screen.dart` → (Arkaplan aura ve UI detayları)
4. `lib/features/face/themes/cozmo_eye.dart` & `cozmo_eye_painter.dart` → Anki Cozmo'nun gerçek köşeli animasyonlu gözleri muhafaza edilecek.

## Task Breakdown

### 1. Cozmo Prompt & Sabitlerin Güncellenmesi
- **Agent:** backend-specialist
- **Skills:** clean-code
- **INPUT:** `app_constants.dart` içindeki `defaultSystemPrompt` ve mood tepkileri.
- **OUTPUT:** "Videodaki gibi mızmızlanan, 'yine bana napcanız' diyen sevimli ama asabi oyuncak robot" promptunun yazılması.
- **VERIFY:** Uygulama sıfırlandığında direkt isyankar bir ufaklık gibi tepkiler veriyor mu?

### 2. Görsel Arayüz Uyarlaması (Face & Settings UI)
- **Agent:** mobile-developer
- **Skills:** mobile-design
- **INPUT:** `face_screen.dart` ve `settings_screen.dart` ekranları.
- **OUTPUT:** Cozmo adlandırmalarının düzeltilmesi, UI renklerinde asıl temanın korunması.
- **VERIFY:** Varsayılan Wake word ve hint metinleri 'Cozmo' mu?

### 3. Cozmo Klasik Göz Animasyonları (Optik Lens)
- **Agent:** mobile-developer
- **Skills:** flutter-animations, mobile-design
- **INPUT:** CustomPainter kullanılarak `cozmo_eye_painter.dart`.
- **OUTPUT:** Orijinal Anki Cozmo stili, eğilen, yanaklarıyla kısılan karemsi (RRect) gözler. (Asla holografik uzaylı gözü değil!)
- **VERIFY:** STT ve TTS sırasında gözler sevimli robot kimliğine uygun tepki veriyor mu?

## ✅ PHASE X COMPLETE
- Lint: ✅ Pass
- Security: ✅ No critical issues
- Build: ✅ Success
- Son Durum: Uzaylı gemisi AI konsepti kaldırıldı, asıl Anki Cozmo (Mızmız ve tatlı) kimliğine başarıyla geri dönüldü. Date: 2026-03-22
