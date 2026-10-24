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

## Oyuncunun görevi ve strateji katmanı
- **Hedefler paneli:** Her senaryonun zorunlu hedefi (kaybedilirse yenilgi) ve yıldız hedefleri canlı izlenir: sağlanıyor (✔), tehlikede (!), ilerleme (ör. "640 / 2.500"). Hedefe tıklayınca kamera oraya gider.
- **Haritada hedefler:** Altın direkli bayrak tepeyi kimin tuttuğunu gösterir; düşman komşu hücredeyse kırmızı halka yanıp söner.
- **Emirler:** Taarruz (hedef hücre seçilir, kırmızı harekât oku çizilir), Savun, Yedekte bekle, Serbest ateş (topçu ve tabyalar). "Emri bütün alaya ver" ile alay birlikte yönetilir. Tur bitince elle oynatılmamış birlikler emirlerini uygular.
- **Kurmay raporu:** Her tur başında tarihe dayalı öneri, gelen takviyeler, yeni görülen düşman, tehlikedeki hedefler, emir bekleyen ve cephanesi azalan birlikler.
- **İstihbarat:** Mavi oklar düşmanın görülen son hareketlerini gösterir.
- **Nasıl oynanır:** İlk oyunda beş adımlık rehber; üst çubuktan yeniden açılabilir.

## Kayıplar
Zayiat şehit/ölü, yaralı ve esir olarak ayrılır (Birinci Dünya Savaşı'nda yaklaşık bir ölüye iki-üç yaralı). Osmanlı için "şehit", İtilaf için "ölü" denir.

## Görsel ve ses
- Birlikler minyatürdür: altıgen kaide üzerinde millete göre giyinmiş askerler (Osmanlı kabalağı, Avustralya keçe şapkası, Yeni Zelanda sivri şapkası, İngiliz kasketi); figür sayısı birliğin gücünü gösterir. Toplar, makineli tüfekler, tabyalar, karargâh çadırı ve dönem zırhlıları.
- Her minyatürde dalgalanan ülke bayrağı: Osmanlı, Britanya, Avustralya, Yeni Zelanda, Fransa (kodla çizilir).
- Yazı tipleri: Noto Sans/Serif ve Oswald (OFL). Harita yazıları ekranda sabit boyuttadır.
- Efektler: namlu ışıkları, mermi uçuşu, patlama ve duman parçacıkları, su sütunları, uçan şehit/yaralı yazıları.
- Sesler (kodla sentezlenir): tüfek yaylım ateşi, makineli tüfek, top, mermi ıslığı, patlama, subay düdüğü, borazan, "Allah Allah" haykırışı, asker adımları, gemi düdüğü, tur çanı, emir mührü, uzak muharebe ve deniz ambiyansı.

## Kurallar (şans yok)
Oyunda zar yoktur: aynı durumda aynı karar her zaman aynı sonucu verir. Belirsizlik yalnızca görülmeyen düşmandan gelir (gizli birlikler, uzaktaki düşmanın tahmini gücü).

- **Muharebe:** Her iki tarafın ateş gücü (tüfek, makineli tüfek, top) etkenlerle çarpılır: moral, yorgunluk, talim, cephane, komuta, ikmal, topçu bastırması, süngü, kuşatma (her ek komşu birlik +%12), zorluk; savunanda ayrıca arazi, yükseklik farkı, siper ve duruş. Güç oranı zayiatı belirler; oran 2'yi aşarsa ya da savunanın morali çökerse savunan çekilir, çekilecek yer yoksa esir düşer. Arayüz bütün etkenleri ve kesin sonucu saldırmadan önce gösterir.
- **Topçu ve gemiler:** Zayiat ve bastırma (bastırılan birliğin gücü kendi turu bitene kadar düşer). Dolaylı atışlı toplar gözcünün gördüğünü döver; gemi ve kıyı topları kendi görüş hattına muhtaçtır ve düz atışlıdır.
- **Emir puanı (komuta-kontrol):** Her tur sınırlı. Elle yönetilen her birlik, verilen her emir ve duruş değişikliği 1 puan; karargâh menzili dışındaki birlik için 2 puan. Emirler (Taarruz, Savun, Yedek, Serbest ateş) tur sonunda puansız uygulanır; taarruz emrindeki birlik düşmandan uzaksa kendiliğinden yürüyüş koluna geçer.
- **Karargâhlar:** Her birlik bir karargâha bağlıdır. Menzil dışındaki birliğin gücü %15 düşer ve ona emir vermek iki kat puan ister. Karargâh vurulursa bütün birliklerin morali sarsılır.
- **İkmal:** Cephane depolardan arazi üzerinden ulaşır; düşmanın tuttuğu hücreler hattı keser, düşmana komşu hücreler zorlaştırır. İkmal dışındaki birliğe cephane gelmez, yorgunluğu yavaş geçer ve iki turdan sonra morali düşer. Tabyaların mermisi sınırlıdır ve yenilenmez.
- **Cephane:** Piyadede fişek (tüfek başına 150), topçuda mermi sayısı gösterilir. Hücum %25, süngü %8, savunma %8; tabya ateşi silah başına 4, sahra topu 12 mermi.
- **Duruşlar:** Muharebe düzeni; İntikal (hareket x1,5, yolda çok hızlı, saldıramaz, savunma x0,6); Savunma (hareket etmez, savunma x1,25, siper iki kat hızlı, en çok 3); Dinlenme (yorgunluk -35/tur, savunma x0,8).
- **Yorgunluk ve talim:** Yürüyüş ve çarpışma yorar (en çok %40 güç kaybı). Talim seviyeleri: acemi x0,85, talimli x1, tecrübeli x1,12, seçkin x1,25.
- **Arazi:** Gerçek yükseklik verisinden sırt, dere yatağı, sarp yamaç ve kumsal çıkarılır; maki örtüsü, köyler ve patikalar eklenir. Her türün hareket ve savunma değeri vardır; maki, dere ve köy birlikleri gizler.
- **Mayınlar:** Mayınlı hücreye giren gemi mayına çarpar; patlamadan sonra o hat düşmanca bilinir. Tarayıcılar ateş altında değilse tur başına 2 mayın temizler.
- **Muharebe düzeni ekranı:** Karargâhlara göre bütün birliklerin asker, moral, dinçlik, cephane, duruş, ikmal, komuta ve emir durumu.

## Senaryolar (Çanakkale 1915)
| Senaryo | Ölçek | Oyuncu | Öne çıkan |
|---|---|---|---|
| 18 Mart: Boğaz Savunması | 800 m, 30 dk, 16 tur | Tabyalar, seyyar obüsler | Nusret'in mayın aşaması, Seyit Onbaşı, Erenköy Koyu |
| Arıburnu: 25 Nisan | 400 m, 1 saat, 14 tur | 19. Tümen (57. ve 27. Alay...) | "Taarruzu değil, ölmeyi emrediyorum", gelen ANZAC dalgaları |
| Conkbayırı: 10 Ağustos | 260 m, 30 dk, 13 tur | 8. Tümen, Anafartalar Grubu | Kamçı işareti, süngü hücumu, cep saati |

## Veri biçimi
Senaryolar `data/scenarios/*.json`: bölge, altıgen boyutu, başlangıç zamanı, yerler (enlem/boylam, hedef puanı), birlikler (teçhizat, asker sayısı, moral, varış turu, yapay zekâ rolü ve hedefi, gemi rotaları), olaylar (tur), tetikleyiciler (koşul), zafer koşulları ve tarihî özet. Teçhizat veritabanı `scripts/strategy/equipment.gd`.

## Teknik mimari
- `scripts/strategy`: `GeoMap` (yükseklik ve coğrafi dönüşüm), `HexGrid`, `ReliefMap` + `shaders/relief_map.gdshader`, `MapCamera`, `Unit`, `Equipment`, `Combat`, `Battle` (tur akışı), `BattleAI`, `BattleUI`, `UnitMini` (minyatürler), `Flags` (bayraklar), `ShipBuilder` (gemi minyatürleri).
- `scripts/core`: `GameState` (kayıt, ayarlar), `Sfx` (sentez sesler), `Voice` (kayıt ya da Türkçe TTS).

## Tarihî doğruluk kuralları
- Birlik, komutan ve olaylar güvenilir kaynaklara dayanır; emin olunmayan ayrıntı (ör. komutan adı) yazılmaz, yaklaşık değerler belirtilir.
- Sonuç ekranı gerçekte ne olduğunu söyler.
- Bütün taraflardaki kayıplara saygılı dil.
