extends Node
## Audio: the soundtrack (res://music, one song per track + the menu song, all
## on the same melody) with smooth crossfades between maps, and the sound
## effects pack (res://sfx). Both are rendered by tools/music/*.py.

const MUSIC_DIR := "res://music/"
const SFX_DIR := "res://sfx/"
## song per zone index (see main.gd ZONES) and each song's tempo
const ZONE_SONGS := ["sky", "festival", "skate", "rain", "market", "harbor", "sakura", "carnival", "highway"]
const BPM := {"menu": 88.0, "sky": 118.0, "festival": 124.0, "skate": 168.0, "rain": 174.0,
	"market": 112.0, "harbor": 104.0, "sakura": 84.0, "carnival": 140.0, "highway": 128.0}
const MUSIC_DB := -7.0
const FADE := 2.2

var players: Array[AudioStreamPlayer] = []
var idx := 0
var sounds := {}
var music_a: AudioStreamPlayer
var music_b: AudioStreamPlayer
var music: AudioStreamPlayer   # the one currently fading in / playing
var song := ""
var music_on := true
var _fade_t := 1.0
var _t := 0.0
var _lowpass: AudioEffectLowPassFilter
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music_a = AudioStreamPlayer.new()
	music_b = AudioStreamPlayer.new()
	for m in [music_a, music_b]:
		m.volume_db = -60.0
		add_child(m)
	music = music_a
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 1400.0
	AudioServer.add_bus_effect(0, _lowpass)
	AudioServer.set_bus_effect_enabled(0, AudioServer.get_bus_effect_count(0) - 1, false)
	var d := DirAccess.open(SFX_DIR)
	if d:
		for f in d.get_files():
			var fname := f.trim_suffix(".import")
			if fname.ends_with(".ogg") and not sounds.has(fname.get_basename()):
				var s = load(SFX_DIR + fname)
				if s:
					sounds[fname.get_basename()] = s


## Crossfades to a song ("menu" or a name from ZONE_SONGS).
func play_song(name: String) -> void:
	if name == song:
		return
	song = name
	var stream: AudioStream = _cache.get(name)
	if stream == null and ResourceLoader.exists(MUSIC_DIR + name + ".ogg"):
		stream = load(MUSIC_DIR + name + ".ogg")
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		_cache[name] = stream
	if stream == null:
		return
	var old := music
	music = music_b if music == music_a else music_a
	music.stream = stream
	music.volume_db = -60.0
	if music_on:
		music.play()
	_fade_t = 0.0
	music.set_meta("old", old)


func play_zone(zone: int) -> void:
	play_song(ZONE_SONGS[zone % ZONE_SONGS.size()])


func _process(delta: float) -> void:
	_t += delta
	if _fade_t < 1.0:
		_fade_t = minf(1.0, _fade_t + delta / FADE)
		# equal-power crossfade
		var a := sin(_fade_t * PI * 0.5)
		var b := cos(_fade_t * PI * 0.5)
		music.volume_db = linear_to_db(maxf(a, 0.0001)) + MUSIC_DB
		var old: AudioStreamPlayer = music.get_meta("old") if music.has_meta("old") else null
		if old and old != music:
			old.volume_db = linear_to_db(maxf(b, 0.0001)) + MUSIC_DB
			if _fade_t >= 1.0:
				old.stop()


func play(name: String, pitch := 1.0, vol_db := 0.0) -> void:
	if not sounds.has(name):
		return
	var p := players[idx]
	idx = (idx + 1) % players.size()
	p.stream = sounds[name]
	p.pitch_scale = pitch
	p.volume_db = -3.0 + vol_db
	p.play()


func beat_phase() -> float:
	var bpm: float = BPM.get(song, 120.0)
	if music.playing:
		return music.get_playback_position() * bpm / 60.0
	return _t * bpm / 60.0


func toggle_music() -> void:
	music_on = not music_on
	for m in [music_a, music_b]:
		if music_on:
			if m == music:
				m.play()
		else:
			m.stop()


func set_warp(on: bool) -> void:
	music.pitch_scale = 0.8 if on else 1.0
	AudioServer.set_bus_effect_enabled(0, AudioServer.get_bus_effect_count(0) - 1, on)


func set_muffled(on: bool) -> void:
	AudioServer.set_bus_effect_enabled(0, AudioServer.get_bus_effect_count(0) - 1, on)
