class_name Equipment
extends RefCounted
## Harp teçhizatı veritabanı. Değerler oyun dengesi için göreli ölçektedir (tüfek = 1):
## soft: personele etkisi, hard: tahkimat ve gemilere etkisi, range_m: menzil (0: yalnızca yakın muharebe).
## indirect: dolaylı atış (tepe arkasına atabilir; gözcü görmesi yeterli). Doğrudan atışlı silahlar
## (gemi topları, kıyı topları) hedefi kendi görüş hattından görmelidir.

const DB := {
	# --- Osmanlı Devleti ---
	"mauser_1903": {"name": "Mauser M1903", "kind": "tüfek", "caliber": "7,65 mm", "soft": 1.0, "hard": 0.0, "range_m": 0, "indirect": false,
		"note": "Osmanlı piyadesinin temel tüfeği; beş fişekli şarjörle doldurulur."},
	"mauser_1890": {"name": "Mauser M1890", "kind": "tüfek", "caliber": "7,65 mm", "soft": 0.9, "hard": 0.0, "range_m": 0, "indirect": false,
		"note": "Yedek ve jandarma birliklerinde kullanılan eski model Mauser."},
	"maxim_1909": {"name": "Maxim M1909", "kind": "makineli tüfek", "caliber": "7,65 mm", "soft": 14.0, "hard": 0.0, "range_m": 0, "indirect": false,
		"note": "Alay makineli tüfek bölüklerinde; Çanakkale'de sayısı azdı."},
	"krupp_75_dag": {"name": "Krupp 7,5 cm M1904 dağ topu", "kind": "dağ topu", "caliber": "75 mm", "soft": 16.0, "hard": 1.5, "range_m": 5000, "indirect": true,
		"note": "Parçalara ayrılıp katırla taşınabilen top; engebeli Gelibolu sırtlarında değerliydi."},
	"krupp_75_sahra": {"name": "Krupp 7,5 cm M1903 sahra topu", "kind": "sahra topu", "caliber": "75 mm", "soft": 19.0, "hard": 2.0, "range_m": 6000, "indirect": true,
		"note": "Şarapnel atan seri sahra topu."},
	"krupp_120_obus": {"name": "Krupp 12 cm obüs", "kind": "obüs", "caliber": "120 mm", "soft": 24.0, "hard": 7.0, "range_m": 6000, "indirect": true,
		"note": "Seyyar obüs bataryaları gemilerin üst yapılarını ve mayın tarayıcılarını dövdü."},
	"krupp_150_obus": {"name": "Krupp 15 cm M1905 obüs", "kind": "obüs", "caliber": "150 mm", "soft": 32.0, "hard": 11.0, "range_m": 7400, "indirect": true,
		"note": "Sürekli yer değiştiren obüsler İtilaf gemilerince bir türlü susturulamadı."},
	"krupp_240_l35": {"name": "Krupp 24 cm L/35 kıyı topu", "kind": "kıyı topu", "caliber": "240 mm", "soft": 18.0, "hard": 32.0, "range_m": 15000, "indirect": false,
		"note": "Rumeli Mecidiye'deki bu toplardan birinin 215 kg'lık mermisini Seyit Onbaşı sırtında taşıdı."},
	"krupp_355_l35": {"name": "Krupp 35,5 cm L/35 kıyı topu", "kind": "kıyı topu", "caliber": "355 mm", "soft": 24.0, "hard": 55.0, "range_m": 14000, "indirect": false,
		"note": "Anadolu Hamidiye Tabyası'nın en ağır topları."},
	"krupp_210_l22": {"name": "Krupp 21 cm L/22 kıyı topu", "kind": "kıyı topu", "caliber": "210 mm", "soft": 12.0, "hard": 18.0, "range_m": 9000, "indirect": false,
		"note": "Boğaz tabyalarındaki eski model ağır toplar."},
	"krupp_150_l40": {"name": "15 cm L/40 deniz topu", "kind": "kıyı topu", "caliber": "150 mm", "soft": 9.0, "hard": 9.0, "range_m": 10000, "indirect": false,
		"note": "Mesudiye zırhlısından sökülüp Dardanos'a yerleştirilen toplar."},
	"karbonit_mayin": {"name": "Karbonit deniz mayını", "kind": "mayın", "caliber": "80 kg patlayıcı", "soft": 0.0, "hard": 0.0, "range_m": 0, "indirect": false,
		"note": "Nusret'in Erenköy Koyu'na döktüğü 26 mayın 18 Mart'ın kaderini belirledi."},
	# --- İtilaf Devletleri ---
	"smle_mk3": {"name": "Lee-Enfield SMLE Mk III", "kind": "tüfek", "caliber": ".303 inç", "soft": 1.1, "hard": 0.0, "range_m": 0, "indirect": false,
		"note": "On fişekli şarjörüyle hızlı atış yapabilen İngiliz ve ANZAC tüfeği."},
	"lebel_1886": {"name": "Lebel M1886", "kind": "tüfek", "caliber": "8 mm", "soft": 0.95, "hard": 0.0, "range_m": 0, "indirect": false,
		"note": "Fransız piyadesinin tüfeği."},
	"maxim_303": {"name": "Maxim .303", "kind": "makineli tüfek", "caliber": ".303 inç", "soft": 14.0, "hard": 0.0, "range_m": 0, "indirect": false,
		"note": "Her taburda iki makineli tüfek bulunuyordu."},
	"qf_18pdr": {"name": "QF 18 librelik sahra topu", "kind": "sahra topu", "caliber": "84 mm", "soft": 19.0, "hard": 2.0, "range_m": 6000, "indirect": true,
		"note": "25 Nisan'da Arıburnu'na ancak birkaç top çıkarılabildi."},
	"bl_15in": {"name": "BL 15 inç Mk I", "kind": "gemi topu", "caliber": "381 mm", "soft": 30.0, "hard": 75.0, "range_m": 18000, "indirect": false,
		"note": "HMS Queen Elizabeth'in dev topları; tabyaları uzaktan dövdü."},
	"bl_12in": {"name": "BL 12 inç (Mk IX/X)", "kind": "gemi topu", "caliber": "305 mm", "soft": 22.0, "hard": 46.0, "range_m": 13000, "indirect": false,
		"note": "İngiliz zırhlılarının ana topları. Düz atışlı oldukları için sırt arkasındaki siperlere etkileri azdı."},
	"bl_10in": {"name": "BL 10 inç Mk VI", "kind": "gemi topu", "caliber": "254 mm", "soft": 18.0, "hard": 36.0, "range_m": 13000, "indirect": false,
		"note": "Swiftsure ve Triumph'un ana topları."},
	"bl_10pdr_dag": {"name": "BL 10 librelik dağ topu", "kind": "dağ topu", "caliber": "69,8 mm", "soft": 12.0, "hard": 1.0, "range_m": 5000, "indirect": true,
		"note": "Hint dağ bataryaları 25 Nisan'da Arıburnu'na çıkan ilk İtilaf toplarıydı."},
	"bl_92in": {"name": "BL 9,2 inç", "kind": "gemi topu", "caliber": "234 mm", "soft": 16.0, "hard": 26.0, "range_m": 14000, "indirect": false,
		"note": "Agamemnon ve Lord Nelson'ın ara çaplı topları."},
	"bl_6in": {"name": "BL 6 inç", "kind": "gemi topu", "caliber": "152 mm", "soft": 10.0, "hard": 9.0, "range_m": 11000, "indirect": false,
		"note": "Zırhlı ve kruvazörlerin yardımcı topları."},
	"fr_305": {"name": "305 mm Mle 1893/96", "kind": "gemi topu", "caliber": "305 mm", "soft": 21.0, "hard": 42.0, "range_m": 12000, "indirect": false,
		"note": "Fransız zırhlılarının ana topları."},
	"fr_274": {"name": "274 mm Mle 1893", "kind": "gemi topu", "caliber": "274 mm", "soft": 17.0, "hard": 34.0, "range_m": 11000, "indirect": false,
		"note": "Bouvet ve Gaulois'nın yan taretlerindeki toplar."},
	"tarama_teli": {"name": "Mayın tarama teli", "kind": "tarama", "caliber": "", "soft": 0.0, "hard": 0.0, "range_m": 0, "indirect": false,
		"note": "Sivil balıkçı gemilerinden dönüştürülmüş tarayıcılar akıntıya karşı ağır ilerliyordu."},
}


static func info(id: String) -> Dictionary:
	return DB.get(id, {"name": id, "kind": "?", "caliber": "", "soft": 0.0, "hard": 0.0, "range_m": 0, "indirect": false, "note": ""})


static func is_ranged(id: String) -> bool:
	return int(info(id)["range_m"]) > 0
