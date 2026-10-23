extends InfantryMission
## 10 Ağustos 1915, Conkbayırı: Albay Mustafa Kemal'in kamçı işaretiyle başlayan şafak süngü hücumu.
## Conkbayırı tepesini, Şahin Sırtı'nı ve Çiftlik'i İngiliz birliklerinden geri al.


func configure() -> void:
	var c := PeninsulaWorld.CONKBAYIRI
	mission_key = "conkbayiri"
	defense_end = 40.0
	time_limit = 600.0
	hold_key = "kocacimen"
	attack_keys = ["conk", "sahin", "ciftlik"]
	objective_defs = {
		"kocacimen": ["Kocaçimen (karargâh)", c + Vector3(150, 0, -165), OTTOMAN],
		"conk": ["Conkbayırı", c, ANZAC],
		"sahin": ["Şahin Sırtı", c + Vector3(-125, 0, 75), ANZAC],
		"ciftlik": ["Çiftlik", c + Vector3(-70, 0, -150), ANZAC],
	}
	waves = [
		[70.0, 10, c + Vector3(-200, 0, 20), "conk"],
		[120.0, 10, c + Vector3(-220, 0, -120), "nearest"],
		[180.0, 12, c + Vector3(-230, 0, 100), "nearest"],
		[250.0, 12, c + Vector3(-220, 0, -40), "nearest"],
		[330.0, 12, c + Vector3(-220, 0, 60), "nearest"],
	]
	player_spawn = c + Vector3(125, 0, -125)
	kemal_spawn = c + Vector3(105, 0, -115)
	kemal_title = "Albay Mustafa Kemal"
	autoplay_post = c + Vector3(30, 0, -40)
	keep_squads = 0
	enemy_kind = "british"
	enemy_name = "İngiliz"
	hold_text = "Hücum işaretini bekle"
	attack_text = "Conkbayırı, Şahin Sırtı ve Çiftlik'i al"


func intro_cards() -> Array:
	return [
		["Ağustos 1915", "İtilaf Devletleri Anafartalar'a yeni bir çıkarma yaptı. 8 Ağustos'ta Yeni Zelandalı birlikler Conkbayırı'nın tepesine ulaştı. Yarımadanın kaderi bir kez daha bu sırtlarda belirlenecek."],
		["Anafartalar Grubu", "Durumun ciddiyeti karşısında Anafartalar Grubu'nun komutası Albay Mustafa Kemal'e verildi. Dağınık birlikleri bir gecede toplayıp hücum düzenine soktu."],
		["10 Ağustos, Şafak", "Mustafa Kemal askerlerinin önüne geçer. Kamçısıyla vereceği işaret, Çanakkale'nin en büyük süngü hücumlarından birini başlatacaktır."],
		["Tarihteki Yeri", "Conkbayırı ve Anafartalar zaferleriyle İtilaf Devletleri'nin Boğaz'ı karadan geçme umudu söndü. Aralık 1915 ile Ocak 1916 arasında yarımadadan çekildiler. Çanakkale, Türk milletinin bağımsızlık iradesinin sembolü oldu."],
	]


func show_mission_briefing() -> void:
	show_briefing("Conkbayırı", "10 Ağustos 1915 · Conkbayırı, Anafartalar",
		"İngiliz birlikleri Conkbayırı tepesini, Şahin Sırtı'nı ve Çiftlik mevkiini tutuyor. Sen hücum birliklerinden bir subaysın. Albay Mustafa Kemal'in kamçı işaretini bekle; işaretle birlikte bütün bölükler süngü hücumuna kalkacak. Hedef: üç mevziyi geri almak.",
		controls_notes() + [
		"Kocaçimen'deki karargâh düşerse görev başarısız olur. Canın: %d." % lives,
		"Taraflar: Osmanlı Devleti (İttifak Devletleri) ve İngiliz birlikleri (İtilaf Devletleri)."])


func on_mission_started() -> void:
	banner("10 AĞUSTOS 1915, 04.30", "Conkbayırı'nda şafak", 3.5)


func build_ottoman_squads() -> void:
	# Hücum bölükleri sırtın doğu yamacındaki ölü bölgede toplanır.
	var c := PeninsulaWorld.CONKBAYIRI
	for i in 6:
		var at := c + Vector3(150, 0, -170 + i * 45)
		var q := _make_squad("%d. Bölük" % (i + 1), OTTOMAN, 12, at, "ottoman")
		q.order = "move"
		q.target = PeninsulaWorld.ground(c + Vector3(85, 0, -150 + i * 40))


func spawn_enemy_garrisons() -> void:
	var counts := {"conk": 16, "sahin": 12, "ciftlik": 10}
	for key in attack_keys:
		var q := _make_squad(enemy_name, ANZAC, counts[key], objectives[key]["pos"] + Vector3(-8, 0, 0), enemy_kind)
		q.order = "hold"
		q.objective = key
		q.entrenched = true


func build_events() -> void:
	var k := "Mustafa Kemal"
	var gold := UiTheme.GOLD
	_events = [
		[5.0, func() -> void: say(k, "Askerler! Karşımızdaki düşmanı mağlup edeceğimize asla şüphe yoktur.", gold)],
		[11.0, func() -> void: say(k, "Siz acele etmeyin. Önce ben ileri gideyim.", gold)],
		[16.0, func() -> void: say(k, "Siz benim kamçımla işaret verdiğimi görünce hep birlikte atılırsınız.", gold)],
		[22.0, func() -> void:
			kemal_goal = PeninsulaWorld.CONKBAYIRI + Vector3(70, 0, -95)
			message("Mustafa Kemal askerlerin önüne geçiyor...", UiTheme.MUTED)],
		[defense_end, _start_counterattack],
		[defense_end + 40.0, _watch],
		[defense_end + 110.0, _reserves],
	]


func on_counterattack() -> void:
	banner("KAMÇI İŞARETİ!", "Bütün bölükler süngü hücumuna!", 3.5)
	Voice.shout("kamci")
	kemal_goal = PeninsulaWorld.CONKBAYIRI + Vector3(25, 0, -60)
	order_charge()


## Kocaçimen'deki yedekler hücuma katılır.
func _reserves() -> void:
	for i in 2:
		var q := _make_squad("Yedek %d. Bölük" % (i + 1), OTTOMAN, 10, objectives["kocacimen"]["pos"] + Vector3(10, 0, i * 30), "ottoman")
		var key := _nearest_enemy_objective(q.center())
		_order_to(q, objectives[key]["pos"], true)
	message("Kocaçimen'deki yedek bölükler hücuma katıldı!", UiTheme.GOLD)


func _nearest_enemy_objective(from: Vector3) -> String:
	var best := attack_keys[0]
	var bd := INF
	for key in attack_keys:
		if objectives[key]["owner"] != OTTOMAN and from.distance_to(objectives[key]["pos"]) < bd:
			bd = from.distance_to(objectives[key]["pos"])
			best = key
	return best


## Tarihî olay: göğsüne isabet eden şarapnel parçasını cebindeki saat durdurdu.
func _watch() -> void:
	banner("ŞARAPNEL İSABETİ", "Bir şarapnel parçası Mustafa Kemal'in göğsüne çarptı; cebindeki saat onu ölümden kurtardı.", 6.0)
	Fx.explosion(self, kemal.pos() + Vector3(-6, 1.5, -4), 0.6)
	Sfx.play_at("boom", kemal.pos(), 0.0)


func hold_lost_lines() -> Array:
	return ["Kocaçimen'deki karargâh düştü."]


func success_lines(_taken: int) -> Array:
	return [
		"Tarihte 10 Ağustos 1915 sabahı yapılan süngü hücumuyla Conkbayırı ve Şahin Sırtı geri alındı; İngiliz birlikleri ağır kayıp verdi.",
		"Hücum sırasında Mustafa Kemal'in göğsüne isabet eden şarapnel parçasını cebindeki saat durdurdu. Bu saati daha sonra Liman von Sanders'e hediye etti.",
		"Anafartalar ve Conkbayırı zaferleri, İtilaf Devletleri'nin Gelibolu'dan çekilmesinin yolunu açtı."]
