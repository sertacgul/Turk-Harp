extends Node
## Konuşma ve haykırışlar. Önce assets/voices/<anahtar>.ogg (ya da .wav) gerçek kaydını çalar;
## kayıt yoksa işletim sisteminin Türkçe metin okuma sesini kullanır (macOS'ta "Yelda").
## Kayıt listesi ve metinleri: docs/VOICES.md

const LINES := {
	"allah_allah": "Allah Allah! Allah Allah!",
	"sungu_tak": "Süngü tak! Yere yat!",
	"hucum": "Hücum!",
	"ates": "Ateş!",
	"bomba": "Bomba!",
	"sehit": "Şehit düştü!",
	"yaralandim": "Vuruldum!",
	"seyit": "Ya Allah! Bismillah!",
	"canakkale_gecilmez": "Çanakkale geçilmez!",
	"kamci": "Haydi! Hep birlikte!",
}

var _tr_voice := ""
var _players: Array[AudioStreamPlayer] = []
var _last := {}


func _ready() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		var voices := DisplayServer.tts_get_voices_for_language("tr")
		if voices.size() > 0:
			_tr_voice = voices[0]
	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func has_tts() -> bool:
	return _tr_voice != ""


func _volume() -> float:
	return clampf(GameState.settings.get("sfx", 0.8), 0.0, 1.0)


func _recording(key: String) -> AudioStream:
	for ext in ["ogg", "wav", "mp3"]:
		var path := "res://assets/voices/%s.%s" % [key, ext]
		if ResourceLoader.exists(path):
			return load(path)
	return null


## Kayıtlı repliği ya da metin okumayı çalar. Aynı replik kısa sürede tekrarlanmaz.
func shout(key: String, min_gap := 2.5) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(key, -100.0)) < min_gap:
		return
	_last[key] = now
	if key == "allah_allah":
		Sfx.play("crowd", -4.0)
	var rec := _recording(key)
	if rec:
		for p in _players:
			if not p.playing:
				p.stream = rec
				p.volume_db = linear_to_db(maxf(_volume(), 0.001))
				p.pitch_scale = randf_range(0.97, 1.03)
				p.play()
				return
		return
	speak(LINES.get(key, key))


## Serbest metni okur. who: "kemal" daha ağır ve yavaş, "asker" daha hızlı.
func speak(text: String, who := "asker") -> void:
	if not has_tts() or _volume() <= 0.01:
		return
	var pitch := 0.85 if who == "kemal" else 1.0
	var rate := 0.95 if who == "kemal" else 1.1
	DisplayServer.tts_speak(text, _tr_voice, int(_volume() * 100.0), pitch, rate, 0, false)


func stop() -> void:
	if has_tts():
		DisplayServer.tts_stop()
	for p in _players:
		p.stop()
