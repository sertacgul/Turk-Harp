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

## Gerçek harita verisi

Haritalar SRTM tabanlı açık yükseklik verisinden üretilir:

```
python3 tools/fetch_heightmap.py gelibolu 39.95 26.12 40.36 26.48
```

Yeni bir savaş bölgesi için bölgeye bir ad ve enlem/boylam kutusu verin; ardından `data/scenarios/` altında bu haritayı kullanan bir senaryo yazın.

## Render
- Her yerde Compatibility (OpenGL/WebGL): Mac'te en sorunsuz mod.
- Düşük donanım için Ayarlar > Grafik: Düşük (harita çözünürlüğü ve kenar yumuşatma azalır).

## Testler
`tools/shot.tscn` bir sahneyi yükler, zamanlanmış komutları çalıştırır ve isteğe bağlı ekran görüntüsü alır. Bir senaryoyu yapay zekâya karşı yapay zekâyla baştan sona oynatmak (denge testi):

```
godot --headless --path . res://tools/shot.tscn -- \
  scene=res://scenes/battle.tscn scenario=res://data/scenarios/ariburnu_1915.json \
  cmds=1:debug_skip_intro,2:debug_autoplay
```

Her tur sonunda `STATUS` satırı (kayıplar, hedeflerin sahipleri, batan gemiler) yazılır; grafik yokken animasyonlar atlanır ve bir senaryo birkaç saniyede biter.
Ekran görüntüsü için `--headless` yerine bir ekran (ör. `xvfb-run`) ile çalıştırıp `shot` komutunu kullanın; `instant=1` animasyonları atlar.
