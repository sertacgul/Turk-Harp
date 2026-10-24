# Oyun Tasarım Belgesi

## Vizyon
Türk tarihinin gerçek savaşlarını, **gerçek haritalar** üzerinde, **gerçek birlikler, komutanlar ve harp teçhizatıyla** canlandıran sıra tabanlı bir harekât oyunu. Oyuncu bir kurmay masasının başındadır: tabur, batarya, tabya ve gemilere emir verir; tarihî olaylar zamanında yaşanır ve sonunda "Tarihte ne oldu?" ile karşılaştırılır.

## Çekirdek döngü
1. **Giriş:** Savaşın Türk tarihindeki yerini anlatan kartlar.
2. **Brifing:** Tarihî durum, hedefler ve kontroller. (Bazı senaryolarda hazırlık aşaması: ör. Nusret'in mayınları.)
3. **Tur:** Her tur gerçek bir zaman dilimidir (30 dk - 1 saat). Önce oyuncu bütün birliklerini yönetir, sonra düşman oynar. Tur başında tarihî olaylar ve takviyeler gelir.
4. **Sonuç:** Zafer/yenilgi, 1-3 yıldız, kayıplar ve tarihî karşılaştırma.

## Harita
- `tools/fetch_heightmap.py` gerçek SRTM yükseklik verisini indirir (`assets/maps/<ad>_height.png`, `data/maps/<ad>.json`).
- Her senaryo bir enlem/boylam kutusu ve altıgen boyutu seçer (ör. Arıburnu 400 m, 18 Mart 800 m).
- `ReliefMap`: kabartma masa; 1915 kurmay haritası üslubunda yükseklik renkleri, eş yükselti eğrileri, kıyı çizgisi, denizde kıyıya paralel çizgiler.
- Hücre özellikleri gerçek araziden hesaplanır: ortalama/en yüksek yükseklik, engebe, kara/deniz oranı.

## Kurallar
- **Hareket:** Hareket puanı; tırmanış ve engebe maliyeti artırır. Düşmana komşu hücreye giren durur (kontrol bölgesi). Gemiler yalnızca denizde.
- **Görüş:** Her birlik, gerçek arazi üzerinden hesaplanan görüş hattıyla görür; görülmeyen düşman haritada gösterilmez. Sırtların arka yamaçları gizler.
- **Yakın muharebe:** Tüfek ve makineli tüfek ateş gücü × moral × cephane; savunanı siper, yükseklik farkı ve engebe korur. Ağır kayıp ya da moral çöküşü geri çekilmeye, kuşatılmışsa esarete yol açar.
- **Süngü hücumu:** Saldırı +%35, düşman morali ağır sarsılır, kendi kaybın artar; cephanesi bitmiş birlik de yapabilir.
- **Topçu ve gemiler:** Dolaylı atışlı toplar (obüs, sahra ve dağ topları) gözcünün gördüğü her hedefi döver; gemi ve kıyı topları kendi görüş hattına ihtiyaç duyar. Gemi topları düz atışlı olduğundan siperlere az etkilidir. Ağır ateş alan tabya bir tur susar.
- **Mayınlar:** Mayınlı hücreye giren gemi büyük olasılıkla vurulur. İtilaf yalnızca bilinen hatları görür ve tarayıcılarla temizlemeye çalışır; tarayıcı ateş altındaysa geri döner.
- **Siper:** Kımıldamayan birlik her tur siperini derinleştirir (en çok 2).
- **Karargâh:** Komutanın karargâhı yakındaki birliklerin moralini yükseltir; vurulursa bütün birlikler sarsılır.
- **Zorluk:** Oyuncu ve düşman ateş gücü çarpanları.

## Senaryolar (Çanakkale 1915)
| Senaryo | Ölçek | Oyuncu | Öne çıkan |
|---|---|---|---|
| 18 Mart: Boğaz Savunması | 800 m, 30 dk, 16 tur | Tabyalar, seyyar obüsler | Nusret'in mayın aşaması, Seyit Onbaşı, Erenköy Koyu |
| Arıburnu: 25 Nisan | 400 m, 1 saat, 14 tur | 19. Tümen (57. ve 27. Alay...) | "Taarruzu değil, ölmeyi emrediyorum", gelen ANZAC dalgaları |
| Conkbayırı: 10 Ağustos | 260 m, 30 dk, 13 tur | 8. Tümen, Anafartalar Grubu | Kamçı işareti, süngü hücumu, cep saati |

## Veri biçimi
Senaryolar `data/scenarios/*.json`: bölge, altıgen boyutu, başlangıç zamanı, yerler (enlem/boylam, hedef puanı), birlikler (teçhizat, asker sayısı, moral, varış turu, yapay zekâ rolü ve hedefi, gemi rotaları), olaylar (tur), tetikleyiciler (koşul), zafer koşulları ve tarihî özet. Teçhizat veritabanı `scripts/strategy/equipment.gd`.

## Teknik mimari
- `scripts/strategy`: `GeoMap` (yükseklik ve coğrafi dönüşüm), `HexGrid`, `ReliefMap` + `shaders/relief_map.gdshader`, `MapCamera`, `Unit`, `Equipment`, `Combat`, `Battle` (tur akışı), `BattleAI`, `BattleUI`, `UnitCounter` (NATO sembollü pullar).
- `scripts/core`: `GameState` (kayıt, ayarlar), `Sfx` (sentez sesler), `Voice` (kayıt ya da Türkçe TTS).

## Tarihî doğruluk kuralları
- Birlik, komutan ve olaylar güvenilir kaynaklara dayanır; emin olunmayan ayrıntı (ör. komutan adı) yazılmaz, yaklaşık değerler belirtilir.
- Sonuç ekranı gerçekte ne olduğunu söyler.
- Bütün taraflardaki kayıplara saygılı dil.
