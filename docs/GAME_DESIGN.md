# Oyun Tasarım Belgesi (Taslak)

## Çekirdek Döngü
1. Senaryo seç (savaş, taraf, dönem).
2. Strateji haritasında ordu yönet: birlik üretimi, yürüyüş, lojistik, moral, hava/arazi.
3. Savaş anına gir: tek kahraman/komutan olarak bireysel dövüş, birlik komutası, formasyon emirleri.
4. Sonuç, tarihî gerçekle karşılaştırılır; "tarihî mod" ve "alternatif tarih" seçenekleri.

## Modlar
- **Kampanya:** Dönemlere göre bağlı savaşlar (ör. Atatürk: Sakarya -> Büyük Taarruz).
- **Tekil Savaş:** Tek senaryo.
- **Çok Oyunculu:** 1v1, takım savaşı, işbirlikçi (co-op) tarihî görevler, sıralamalı maçlar.
- **Eğitim/Ansiklopedi:** Her savaş için komutanlar, silahlar, haritalar ve kaynakça.

## Teknik Öneri
- Motor: Godot 4 (MIT, açık kaynak, GDScript/C#).
- Çok oyunculu: Godot high-level multiplayer (ENet/WebSocket), sunucu otoriteli.
- Veri: JSON/YAML ile savaş, lider, birlik tanımları (`data/`).
- Çeviri: gettext; ilk diller Türkçe ve İngilizce.

## Tarihî Doğruluk Kuralları
- Her savaş/lider kaydı en az 2 güvenilir kaynak içerir.
- Kaynaksız veri birleştirilmez.
- Gerçek kişilere saygılı, propaganda içermeyen dil.
