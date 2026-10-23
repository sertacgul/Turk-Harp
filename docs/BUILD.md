# Çalıştırma, Derleme ve Test

Gereksinim: [Godot 4.7](https://godotengine.org/download/) (standart sürüm, .NET değil).

## Bilgisayarda çalıştırma (Mac / Windows / Linux)
1. Godot'u aç, **Import** ile `project.godot` dosyasını seç.
2. ▶ (Cmd+B / F5) ile çalıştır.

Hazır derlemeler: GitHub'da **Actions > godot** iş akışının son başarılı çalışmasında `TurkHarp-macOS`, `TurkHarp-Windows`, `TurkHarp-Linux` dosyaları indirilebilir.
macOS derlemesi imzasızdır: ilk açılışta uygulamaya sağ tıklayıp **Aç** deyin.

## Web (iPhone Safari, Android Chrome, bilgisayar tarayıcısı)
1. Editor > Manage Export Templates ile şablonları indir.
2. Project > Export > Web > Export Project ile `build/web/index.html` olarak dışa aktar (ön ayar hazır, iş parçacıksız sürüm: Safari uyumlu).
3. `build/web` klasörünün içeriğini ZIP yapıp itch.io'ya HTML oyunu olarak yükle ("This file will be played in the browser", "Mobile friendly", yatay yön).

## Android
1. Android SDK ve JDK 17 kur; Godot Editor Settings > Export > Android yollarını ayarla.
2. Editor > Manage Export Templates ile şablonları indir.
3. Project > Export > Android > Export Project (hata ayıklama anahtarı Godot tarafından oluşturulur).

## iOS
1. macOS + Xcode + Apple Developer hesabı gerekir.
2. `export_presets.cfg` içindeki iOS ön ayarına Team ID gir.
3. Project > Export > iOS ile Xcode projesi oluştur, Xcode'dan cihaza yükle.

## Render
- Bilgisayar: Forward+ (Mac'te Metal). SSAO, SSIL, ekran uzayı yansımaları, hacimsel sis ve yumuşak gölgeler açıktır.
- Telefon ve web: Compatibility (OpenGL/WebGL). Görsel efektlerin bir kısmı kapalıdır.
- Forward+ sorun çıkarırsa: Project Settings > Rendering > Renderer > Rendering Method = gl_compatibility.
- Düşük donanım için Ayarlar > Grafik: Düşük (gölge, parçacık sayısı ve arazi çözünürlüğü azalır).

## Testler
`tools/shot.tscn` bir sahneyi yükler, zamanlanmış komutları çalıştırır ve isteğe bağlı ekran görüntüsü alır:

```
godot --headless --path . res://tools/shot.tscn -- \
  scene=res://scenes/missions/strait_defense.tscn \
  cmds=0.5:start_mission,0.6:debug_autoplay,45:debug_status,46:quit speed=8
```

`debug_autoplay` görevi otomatik oynatır; CI her push'ta iki görevi de bu şekilde baştan sona oynatır ve betik hatası arar.
Ekran görüntüsü için `--headless` yerine bir ekran (ör. `xvfb-run`) ile çalıştırıp `shot` komutunu kullanın.
