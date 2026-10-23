# Fotogerçekçi Varlıklar (CC0)

Oyun, `assets/` altında indirilmiş varlıklar varsa onları kullanır; yoksa prosedürel
(kodla üretilen) grafiklere geri döner. Bu yüzden varlıklar isteğe bağlıdır ve oyun her durumda açılır.

| Klasör | Dosyalar | Kullanıldığı yer |
| --- | --- | --- |
| `assets/hdri/` | `day.hdr`, `dawn.hdr`, `night.hdr` | Gökyüzü ve ortam ışığı (`Atmosphere.build`) |
| `assets/textures/` | `grass/dirt/rock/sand_albedo.jpg`, `_normal.jpg` | Arazi (`shaders/terrain.gdshader`, `textured = true`) |
| `assets/models/` | `rock_0..2.gltf`, `bush_0..1.gltf` (+ `.bin` ve dokular) | Yamaç/kıyı kayaları ve çalılar (`AssetLib.scatter_models`) |

## İndirme

Poly Haven (polyhaven.com) varlıkları CC0'dır; atıf gerekmez, kaynaklar yine de `assets/CREDITS.md`'ye yazılır.

```bash
python3 tools/fetch_assets.py --list   # seçilecek varlıkları göster
python3 tools/fetch_assets.py          # indir (varsayılan 2k çözünürlük)
python3 tools/fetch_assets.py --res 1k # daha küçük dosyalar (telefon/web için)
```

Komutu **proje klasörünün içinde** çalıştırın (ör. `cd ~/Downloads/Turk-Harp`), sonra projeyi
Godot 4.7'de bir kez açın; dosyalar otomatik içe aktarılır. Varlıklar depoya eklenmiştir; bu komut yalnızca
seçimleri değiştirdiğinizde gerekir. `assets/sources.json` hangi dosyanın hangi varlıktan indirildiğini
tutar: seçim değişince yalnızca değişen dosyalar yeniden indirilir.

Taranmış modeller 50-150 bin üçgenlidir. Oyun, Godot'nun içe aktarırken ürettiği LOD'lardan
1.600 (kaya) / 3.000 (çalı) üçgeni aşmayan sürümü kullanır ve kopyaları 120 m'lik hücrelere böler.

Bulut (Claude Code) ortamında indirme için ortam ayarlarındaki ağ erişimine şu alan adları eklenmelidir:
`polyhaven.com`, `api.polyhaven.com`, `dl.polyhaven.org`.

## Kendi varlığınızı eklemek

Aynı adlarla kendi dosyalarınızı koyabilirsiniz. Lisansın CC0 ya da açık kaynakla uyumlu olduğundan
emin olun ve `assets/CREDITS.md`'ye kaynağı ekleyin.
