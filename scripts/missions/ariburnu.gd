extends InfantryMission
## 25 Nisan 1915, Arıburnu: 57. Alay'ın bir subayı olarak Conkbayırı'nı savun, bölüklere emir ver
## ve Mustafa Kemal'in taarruz emriyle Cesaret Tepe ile Kırmızı Sırt'ı geri al.


func configure() -> void:
	mission_key = "ariburnu"
	defense_end = 180.0
	time_limit = 600.0
	hold_key = "conk"
	attack_keys = ["cesaret", "kirmizi"]
	objective_defs = {
		"conk": ["Conkbayırı", PeninsulaWorld.CONKBAYIRI, OTTOMAN],
		"cesaret": ["Cesaret Tepe", PeninsulaWorld.CESARET_TEPE, ANZAC],
		"kirmizi": ["Kırmızı Sırt", PeninsulaWorld.KIRMIZI_SIRT, ANZAC],
	}
	waves = [
		[22.0, 10, Vector3(160, 0, -70), "conk"],
		[50.0, 12, Vector3(120, 0, -200), "conk"],
		[85.0, 12, Vector3(150, 0, 30), "conk"],
		[120.0, 14, Vector3(90, 0, -130), "conk"],
		[155.0, 14, Vector3(130, 0, -10), "conk"],
		[215.0, 8, Vector3(-60, 0, 110), "kirmizi"],
		[255.0, 8, Vector3(-60, 0, -40), "cesaret"],
		[330.0, 10, Vector3(-80, 0, 20), "nearest"],
		[420.0, 10, Vector3(-80, 0, 80), "nearest"],
	]
	player_spawn = PeninsulaWorld.CONKBAYIRI + Vector3(70, 0, -10)
	kemal_spawn = PeninsulaWorld.CONKBAYIRI + Vector3(45, 0, -25)
	autoplay_post = PeninsulaWorld.CONKBAYIRI + Vector3(-30, 0, -15)
	keep_squads = 2
	hold_text = "Conkbayırı'nı tut"
	attack_text = "Cesaret Tepe ve Kırmızı Sırt'ı al"


func intro_cards() -> Array:
	return [
		["25 Nisan 1915", "Şafak sökerken Arıburnu kıyılarına sandallar yanaşıyor. 18 Mart'ta denizden geçemeyen İtilaf Devletleri, şimdi Gelibolu'yu karadan almak istiyor."],
		["Sırtların Önemi", "Conkbayırı ve Kocaçimen düşerse Boğaz'ın kalbine giden yol açılır. Çanakkale düşerse İstanbul'a giden yol da açılır."],
		["Mustafa Kemal ve 57. Alay", "19. Tümen Komutanı Yarbay Mustafa Kemal, emir beklemeden 57. Alay'ı cepheye sürer. Bu karar, Çanakkale Savaşı'nın ve Türk tarihinin seyrini değiştirecektir."],
		["Bir Milletin Uyanışı", "Bu sırtlarda verilen mücadele, yıllar sonra Kurtuluş Savaşı'nı yönetecek olan komutanı ve ona inanan bir milleti doğurdu."],
	]


func show_mission_briefing() -> void:
	show_briefing("Arıburnu: 57. Alay", "25 Nisan 1915 · Arıburnu, Conkbayırı",
		"Şafakta İtilaf Devletleri'nin ANZAC birlikleri Arıburnu'na çıktı ve sırtlara tırmanıyor. 19. Tümen Komutanı Yarbay Mustafa Kemal, 57. Alay'ı Conkbayırı'na yetiştiriyor. Sen alayın bir subayısın: önce Conkbayırı'nı tut, sonra taarruz emriyle Cesaret Tepe ve Kırmızı Sırt'ı geri al.",
		controls_notes() + [
		"Conkbayırı düşerse görev başarısız olur. Canın: %d." % lives,
		"Taraflar: Osmanlı Devleti (İttifak Devletleri) ve ANZAC birlikleri (İtilaf Devletleri)."])


func on_mission_started() -> void:
	banner("25 NİSAN 1915", "Conkbayırı'na yetiş", 3.5)


func build_ottoman_squads() -> void:
	# 57. Alay doğudan, Bigalı yönünden gelir ve Conkbayırı sırtına yayılır.
	var c := PeninsulaWorld.CONKBAYIRI
	var slots := [Vector3(-35, 0, -70), Vector3(-45, 0, -25), Vector3(-45, 0, 20), Vector3(-35, 0, 65)]
	for i in 4:
		var q := _make_squad("%d. Bölük" % (i + 1), OTTOMAN, 10, c + Vector3(110, 0, -60 + i * 40), "ottoman")
		q.order = "move"
		q.target = PeninsulaWorld.ground(c + slots[i])


func build_events() -> void:
	var k := "Mustafa Kemal"
	var gold := UiTheme.GOLD
	_events = [
		[4.0, func() -> void: say(k, "57. Alay, Conkbayırı'na!", gold)],
		[6.0, _spawn_retreaters],
		[10.0, func() -> void: say(k, "Niçin kaçıyorsunuz?", gold)],
		[11.5, func() -> void: say("Asker", "Efendim, düşman!")],
		[13.0, func() -> void: say(k, "Nerede?", gold)],
		[14.5, func() -> void: say("Asker", "İşte!")],
		[16.0, func() -> void: say(k, "Düşmandan kaçılmaz!", gold)],
		[17.5, func() -> void: say("Asker", "Cephanemiz kalmadı!")],
		[19.0, func() -> void: say(k, "Cephaneniz yoksa süngünüz var!", gold)],
		[20.5, _fix_bayonets],
		[defense_end, _start_counterattack],
		[defense_end + 12.0, _reinforce_27],
	]


func _spawn_retreaters() -> void:
	var q := squads[0]
	for i in 6:
		var s := _new_soldier("ottoman", OTTOMAN, PeninsulaWorld.CESARET_TEPE + Vector3(70, 0, -20 + i * 4))
		s.no_ammo = true
		s.speed = 5.0
		s.goal = PeninsulaWorld.ground(kemal.pos() + Vector3(-8, 0, -6 + i * 2.5))
		s.squad = q
		q.soldiers.append(s)


func _fix_bayonets() -> void:
	banner("SÜNGÜ TAK! YERE YAT!", "Askerler süngü takıp yere yattı; düşman da yere yattı. Kazanılan zaman, 57. Alay'ın yetişmesini sağladı.", 4.5)
	Voice.shout("sungu_tak")
	Sfx.play("bugle", -6.0)


func on_counterattack() -> void:
	banner("\"Ben size taarruzu emretmiyorum, ölmeyi emrediyorum!\"",
		"\"Biz ölünceye kadar geçecek zaman zarfında yerimize başka kuvvetler ve kumandanlar gelebilir.\" (Mustafa Kemal)", 7.0)
	Voice.speak("Ben size taarruzu emretmiyorum, ölmeyi emrediyorum.", "kemal")
	message("Yeni hedef: Cesaret Tepe ve Kırmızı Sırt'ı geri al. Conkbayırı'nı elde tut (1. ve 2. Bölük sırtta kalır).", UiTheme.GOLD)


func _reinforce_27() -> void:
	for i in 2:
		var q := _make_squad("27. Alay %d. Bölük" % (i + 1), OTTOMAN, 10, PeninsulaWorld.CONKBAYIRI + Vector3(160, 0, 120 + i * 40), "ottoman")
		q.order = "move"
		q.target = PeninsulaWorld.ground(PeninsulaWorld.CONKBAYIRI + Vector3(-60, 0, 90 + i * 30))
	message("27. Alay yetişti! (Yarbay Mehmet Şefik)", UiTheme.GOLD)


func hold_lost_lines() -> Array:
	return ["Conkbayırı düştü.", "Tarihte 57. Alay sırtları tuttu ve ANZAC ilerleyişi durduruldu. Bölükleri sırtta tut ve gemi ateşinden dağınık dur."]


func success_lines(_taken: int) -> Array:
	return [
		"Tarihte 57. Alay'ın 25 Nisan karşı taarruzu ANZAC'ın Conkbayırı ve Kocaçimen'e ulaşmasını engelledi; alay o gün ağır kayıp verdi.",
		"57. Alay'ın anısına bu alay numarası Türk ordusunda bir daha kullanılmadı."]
