# Ses Kayıtları

## Google Cloud Text-to-Speech ile seslendirme (erkek sesi)

`tools/generate_voices.py` oyundaki bütün replikleri (naralar, Mustafa Kemal'in sözleri, asker konuşmaları,
intro anlatımları) Google'ın Türkçe **erkek** sesleriyle `.mp3` olarak üretir. En doğal sesler (Chirp3-HD,
yoksa WaveNet) otomatik seçilir; Mustafa Kemal, anlatıcı ve askerler farklı seslerle okunur.

1. Google Cloud Console'da bir proje açın ve **Cloud Text-to-Speech API**'yi etkinleştirin.
2. *APIs & Services > Credentials > Create credentials > API key* ile anahtar oluşturun.
   Anahtarı yalnızca Text-to-Speech API ile sınırlayın.
3. Anahtarı **asla depoya yazmayın**; yalnızca ortam değişkeni olarak verin:

```
export GOOGLE_TTS_API_KEY=...
python3 tools/generate_voices.py            # eksik dosyaları üretir
python3 tools/generate_voices.py --dry-run  # replikleri listeler
```

4. Godot projeyi açınca dosyaları içe aktarır; oyun kayıtları otomatik kullanır.

Toplam metin yaklaşık 3.000 karakterdir. Yeni bir görev ya da replik eklendiğinde komutu yeniden çalıştırmak
yeterlidir; mevcut dosyalar atlanır.

## Elle kayıt

Oyun, aşağıdaki replikleri önce `assets/voices/` klasöründe arar (`.ogg`, `.wav` ya da `.mp3`).
Kayıt yoksa işletim sisteminin Türkçe metin okuma sesini kullanır (macOS'ta "Yelda").
Gerçek seslendirme eklemek için kaydı aşağıdaki dosya adıyla klasöre koymak yeterlidir; kod değişmez.

| Dosya adı | Söylenecek metin | Not |
|---|---|---|
| `allah_allah` | "Allah Allah! Allah Allah!" | Süngü hücumu; mümkünse birden çok kişi |
| `sungu_tak` | "Süngü tak! Yere yat!" | Arıburnu, 25 Nisan |
| `hucum` | "Hücum!" | Subay komutu |
| `ates` | "Ateş!" | |
| `bomba` | "Bomba!" | El bombası atılırken |
| `sehit` | "Şehit düştü!" | |
| `yaralandim` | "Vuruldum!" | |
| `seyit` | "Ya Allah! Bismillah!" | Seyit Onbaşı mermiyi kaldırırken |
| `canakkale_gecilmez` | "Çanakkale geçilmez!" | 18 Mart açılışı |
| `kamci` | "Haydi! Hep birlikte!" | Conkbayırı, kamçı işareti |

Öneriler: 44.1 kHz, mono, -3 dB tepe, başta ve sonda sessizlik olmadan. Kayıtlar CC BY-SA 4.0 ile paylaşılmalıdır.
