# Derleme ve Dışa Aktarma

Gereksinim: [Godot 4.3+](https://godotengine.org/download) (standart sürüm, GDScript).

## Masaüstü (Windows / macOS / Linux)
1. Godot'ta `project.godot` dosyasını aç.
2. F5 ile çalıştır (ana sahne: menü).
3. Project > Export ile platform seç.

## Android
1. Android SDK ve JDK 17 kur, Godot Editor Settings > Export > Android yollarını ayarla.
2. Export şablonlarını indir (Editor > Manage Export Templates).
3. Project > Export > Android; keystore oluştur; APK/AAB dışa aktar.

## iOS
1. macOS ve Xcode gerekir; Apple Developer hesabı ile imzala.
2. Project > Export > iOS; Xcode projesini oluştur; cihazda veya TestFlight ile çalıştır.

Oyun fare ve dokunma girdisini aynı kodla işler (tek dokunuş = sol tık); sabit 1280x720 yatay yerleşim kullanılır.

## CI
`.github/workflows/godot-check.yml` projeyi headless içe aktarır ve savaş sahnesini kısa süre çalıştırarak betik hatalarını yakalar.
