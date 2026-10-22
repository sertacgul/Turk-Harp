# Oyun Tasarım Belgesi

## Vizyon
Türk tarihinin gerçek savaşlarını, oyuncunun hem **bireysel** (top başında, dümende, siperde) hem de **komutan** (bataryalar, birlikler, filolar) olarak yaşadığı 3D, ilerlemeli bir kampanya.

## Çekirdek döngü
1. **Brifing:** Tarihî bağlam, komutanlar, hedefler.
2. **Görev:** Bireysel kontrol + komuta katmanı (taktik harita).
3. **Sonuç:** 1-3 yıldız, Şeref puanı, tarihte gerçekte ne olduğu.
4. **İlerleme:** Şeref ile yükseltmeler; bir görevin sonucu sonrakini etkiler (ör. Nusret'in mayınları 18 Mart'ta aynı yerde).

## Çanakkale seferi (ilk sefer)
| Görev | Durum | Bireysel | Komuta |
|---|---|---|---|
| Nusret'in Gecesi (7-8 Mart 1915) | Oynanabilir | Nusret'i dümenle, ışıldaklardan kaç, mayın bırak | Rota ve zamanlama |
| 18 Mart: Boğaz Savunması | Oynanabilir | Rumeli Mecidiye topu, Seyit Onbaşı | Taktik haritadan diğer bataryalara hedef |
| Arıburnu: 57. Alay (25 Nisan) | Oynanabilir | Üçüncü şahıs piyade subayı, tüfek ve süngü | 6 bölüğe emir, mevzi ele geçirme, süngü hücumu |
| Conkbayırı (Ağustos) | Planlı | Piyade | Anafartalar Grubu taarruzu |

## Teknik mimari
- **Motor:** Godot 4.7, GDScript. Masaüstü Forward+, mobil Mobile render.
- `scripts/core`: `GameState` (kayıt, ilerleme, yükseltmeler), `Sfx` (çalışma anında sentezlenen sesler, ses hızına göre gecikme).
- `scripts/world`: `StraitWorld` (prosedürel boğaz: arazi, su, gökyüzü, köyler, kaleler), `ShipBuilder` (dönem gemileri, bayraklar).
- `scripts/fx`: `Fx` (patlama, su sütunu, namlu alevi, duman, yangın, iz).
- `scripts/missions`: `MissionBase` (HUD, brifing, duraklatma, sonuç, kamera sarsıntısı) ve görevler.
- Tüm görseller kodla üretilir; sanatçı modelleri geldikçe `ShipBuilder` ve `StraitWorld` içindeki ilgili parçalar .glb modellerle değiştirilecek.

## Tarihî doğruluk kuralları
- Her görev, lider ve gemi kaydı en az iki güvenilir kaynağa dayanır.
- Oyun içi sonuç ekranı gerçekte ne olduğunu söyler.
- Gerçek kişilere ve tüm taraflardaki kayıplara saygılı dil.
